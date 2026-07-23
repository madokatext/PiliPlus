import 'dart:async' show Completer, StreamSubscription;
import 'dart:io'
    show
        HttpClient,
        HttpClientResponse,
        HttpException,
        HttpHeaders,
        HttpRequest,
        HttpResponse,
        HttpServer,
        HttpStatus,
        InternetAddress;
import 'dart:math' show max, min;
import 'dart:typed_data' show ByteData, BytesBuilder, Endian, Uint8List;

import 'package:PiliPlus/utils/storage_pref.dart';

/// 为 mpv 外部视频轨提供一个可预热的回环 HTTP 入口。
///
/// 代理会在 mpv 接触新轨前读取 DASH SegmentBase 指定的初始化段与 SIDX，
/// 再按当前播放时间定位并缓存对应的媒体 Range。mpv 随后发出的 Range 请求
/// 会优先命中这些内存数据，未命中的部分则从上游断点续传。
final class VideoTrackProxy {
  VideoTrackProxy._({
    required this.source,
    required this.requiredBytes,
    required Map<String, String> headers,
    required String? upstreamProxy,
    required HttpServer server,
  }) : _server = server,
       _headers = Map.unmodifiable(headers),
       _resolvedSource = source,
       _client = HttpClient()
         ..autoUncompress = false
         ..connectionTimeout = const Duration(seconds: 15)
         ..idleTimeout = const Duration(seconds: 15) {
    final customProxy = Uri.tryParse(upstreamProxy ?? '');
    if (customProxy != null &&
        customProxy.scheme == 'http' &&
        customProxy.host.isNotEmpty &&
        customProxy.port != 0) {
      _client.findProxy = (_) =>
          'PROXY ${customProxy.host}:${customProxy.port}';
    } else if (Pref.enableSystemProxy) {
      final host = Pref.systemProxyHost;
      final port = int.tryParse(Pref.systemProxyPort);
      if (host.isNotEmpty && port != null) {
        _client.findProxy = (_) => 'PROXY $host:$port';
      }
    }
    _requests = _server.listen(_handleRequest);
  }

  static const _discoveryBytes = 2 * 1024 * 1024;
  static const _minimumMediaBudget = 32 * 1024 * 1024;
  static const _mediaBudgetSlack = 8 * 1024 * 1024;
  static const _maxRedirects = 8;
  static const _maxRangeAttempts = 3;

  final Uri source;
  final int requiredBytes;
  final HttpServer _server;
  final HttpClient _client;
  final Map<String, String> _headers;
  final _RangeCache _cache = _RangeCache();
  final Completer<void> _ready = Completer<void>();

  late final StreamSubscription<HttpRequest> _requests;
  Uri _resolvedSource;
  int? _contentLength;
  String? _contentType;
  String? _etag;
  String? _lastModified;
  bool _prewarmStarted = false;
  bool _closed = false;

  Uri get uri => Uri(
    scheme: 'http',
    host: InternetAddress.loopbackIPv4.address,
    port: _server.port,
    path: '/video',
  );

  Future<void> get ready => _ready.future;

  static Future<VideoTrackProxy> create({
    required String source,
    required int requiredBytes,
    Map<String, String> headers = const {},
    String? upstreamProxy,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return VideoTrackProxy._(
      source: Uri.parse(source),
      requiredBytes: requiredBytes,
      headers: headers,
      upstreamProxy: upstreamProxy,
      server: server,
    );
  }

  /// 主动预热初始化段、SIDX 以及 [position] 对应的媒体 Range。
  ///
  /// Bilibili 的 Web/App playurl 字段命名不一致，因此调用方先把
  /// Initialization/indexRange 的值归一化后传入。若缺少 indexRange，
  /// 会从初始化段之后的小窗口中发现 SIDX；无法可靠定位时间时直接失败，
  /// 避免退化成从文件首部盲目缓存。
  Future<void> prewarm({
    required Duration position,
    Duration Function()? currentPosition,
    String? initializationRange,
    String? indexRange,
  }) async {
    if (_prewarmStarted) {
      return ready;
    }
    if (_closed) {
      throw StateError('VideoTrackProxy is closed');
    }
    _prewarmStarted = true;

    try {
      var initialization = _ByteRange.tryParse(initializationRange);
      final index = _ByteRange.tryParse(indexRange);

      // indexRange 的起点也给出了初始化区的可靠上界。
      initialization ??= index != null && index.start > 0
          ? _ByteRange(0, index.start - 1)
          : null;
      if (initialization != null) {
        await _fetchAndCache(initialization);
      }

      _Sidx? sidx;
      if (index != null) {
        final bytes = await _fetchAndCache(index);
        sidx = _Sidx.tryParse(bytes, index.start);
      }

      if (sidx == null) {
        final discoveryStart = initialization == null
            ? 0
            : initialization.end + 1;
        final discovery = _ByteRange(
          discoveryStart,
          discoveryStart + _discoveryBytes - 1,
        );
        final bytes = await _fetchAndCache(discovery);
        sidx = _Sidx.tryParse(bytes, discovery.start);
      }

      if (sidx == null) {
        throw const FormatException('DASH SIDX was not found');
      }

      // 初始化/索引下载期间旧视频仍在播放，媒体预热使用此刻的最新位置。
      final mediaPosition = currentPosition?.call() ?? position;
      var resolvedSidx = sidx;

      // 处理 reference_type=1 的分层 SIDX，直到落到媒体引用。
      for (var depth = 0; depth < 4; depth++) {
        final reference = resolvedSidx.referenceAt(mediaPosition);
        if (!reference.isIndex) {
          break;
        }
        final bytes = await _fetchAndCache(reference.range);
        final nested = _Sidx.tryParse(bytes, reference.range.start);
        if (nested == null) {
          throw const FormatException('Invalid nested DASH SIDX');
        }
        resolvedSidx = nested;
      }

      final firstIndex = resolvedSidx.referenceIndexAt(mediaPosition);
      if (firstIndex < 0 || resolvedSidx.references[firstIndex].isIndex) {
        throw const FormatException('DASH SIDX has no media reference');
      }

      final mediaBudget = max(
        _minimumMediaBudget,
        requiredBytes + _mediaBudgetSlack,
      );
      var mediaBytes = 0;
      for (
        var i = firstIndex;
        i < resolvedSidx.references.length && mediaBytes < requiredBytes;
        i++
      ) {
        final reference = resolvedSidx.references[i];
        if (reference.isIndex) {
          break;
        }
        final remainingBudget = mediaBudget - mediaBytes;
        if (remainingBudget <= 0) {
          break;
        }
        final fetchLength = min(reference.range.length, remainingBudget);
        if (fetchLength <= 0) {
          break;
        }
        await _fetchAndCache(
          _ByteRange(
            reference.range.start,
            reference.range.start + fetchLength - 1,
          ),
        );
        mediaBytes += fetchLength;
      }

      // 临近文件尾时可能不足常规门槛；只要当前媒体片段已缓存即可切轨。
      if (mediaBytes == 0) {
        throw const FormatException('DASH SIDX media range is empty');
      }
      if (!_ready.isCompleted) {
        _ready.complete();
      }
    } catch (error, stackTrace) {
      if (!_ready.isCompleted) {
        _ready.completeError(error, stackTrace);
      }
      return ready;
    }
  }

  Future<Uint8List> _fetchAndCache(_ByteRange range) async {
    final cached = _cache.readExact(range);
    if (cached != null) {
      return cached;
    }
    final bytes = await _downloadRange(range);
    _cache.add(range.start, bytes);
    return bytes;
  }

  Future<Uint8List> _downloadRange(_ByteRange requested) async {
    final builder = BytesBuilder(copy: false);
    var cursor = requested.start;
    var targetEnd = requested.end;
    var attempts = 0;

    while (cursor <= targetEnd) {
      final attemptStart = cursor;
      try {
        final upstream = await _openUpstream(
          'GET',
          range: _ByteRange(cursor, targetEnd),
        );
        final response = upstream.response;
        _recordResponse(response);
        if (_contentLength case final total?) {
          targetEnd = min(targetEnd, total - 1);
        }
        if (cursor > targetEnd) {
          await response.drain<void>();
          break;
        }

        final responseRange = _ResponseRange.tryParse(
          response.headers.value(HttpHeaders.contentRangeHeader),
        );
        if (response.statusCode == HttpStatus.partialContent) {
          if (responseRange == null ||
              responseRange.start != cursor ||
              responseRange.end < cursor) {
            await response.drain<void>();
            throw HttpException('Unexpected upstream Content-Range');
          }
        } else if (response.statusCode == HttpStatus.ok && cursor == 0) {
          // 少数 CDN 会忽略首段 Range；仅读取需要的前缀，不下载整个文件。
        } else {
          await response.drain<void>();
          throw HttpException(
            'Unexpected upstream status ${response.statusCode}',
          );
        }

        var received = 0;
        await for (final chunk in response) {
          final remaining = targetEnd - cursor + 1;
          if (remaining <= 0) {
            break;
          }
          final take = min(remaining, chunk.length);
          if (take == chunk.length) {
            builder.add(chunk);
          } else {
            builder.add(chunk.sublist(0, take));
          }
          received += take;
          cursor += take;
          if (cursor > targetEnd) {
            break;
          }
        }
        if (received == 0) {
          throw HttpException('Upstream range ended without data');
        }
        attempts = 0;
      } catch (_) {
        attempts = cursor > attemptStart ? 0 : attempts + 1;
        if (attempts >= _maxRangeAttempts) {
          rethrow;
        }
      }
    }
    return builder.takeBytes();
  }

  Future<_UpstreamResponse> _openUpstream(
    String method, {
    HttpHeaders? requestHeaders,
    _ByteRange? range,
  }) async {
    var target = _resolvedSource;
    for (
      var redirectCount = 0;
      redirectCount <= _maxRedirects;
      redirectCount++
    ) {
      final request = await _client.openUrl(method, target);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      for (final entry in _headers.entries) {
        request.headers.set(entry.key, entry.value);
      }
      requestHeaders?.forEach((name, values) {
        if (!_shouldSkipRequestHeader(name, skipRange: range != null)) {
          request.headers.set(name, values);
        }
      });
      if (range != null) {
        request.headers.set(
          HttpHeaders.rangeHeader,
          'bytes=${range.start}-${range.end}',
        );
      }

      final response = await request.close();
      if (!_isRedirect(response.statusCode)) {
        _resolvedSource = target;
        return _UpstreamResponse(response);
      }

      final location = response.headers.value(HttpHeaders.locationHeader);
      await response.drain<void>();
      if (location == null || location.isEmpty) {
        throw HttpException('CDN redirect has no Location header');
      }
      target = target.resolve(location);
    }
    throw HttpException('Too many CDN redirects');
  }

  static bool _isRedirect(int statusCode) =>
      statusCode == HttpStatus.movedPermanently ||
      statusCode == HttpStatus.found ||
      statusCode == HttpStatus.seeOther ||
      statusCode == HttpStatus.temporaryRedirect ||
      statusCode == HttpStatus.permanentRedirect;

  static bool _shouldSkipRequestHeader(String name, {required bool skipRange}) {
    final lower = name.toLowerCase();
    return lower == HttpHeaders.hostHeader ||
        lower == HttpHeaders.contentLengthHeader ||
        lower == HttpHeaders.transferEncodingHeader ||
        lower == HttpHeaders.connectionHeader ||
        (skipRange && lower == HttpHeaders.rangeHeader);
  }

  static bool _shouldSkipResponseHeader(String name) {
    final lower = name.toLowerCase();
    return lower == HttpHeaders.transferEncodingHeader ||
        lower == HttpHeaders.connectionHeader;
  }

  void _recordResponse(HttpClientResponse response) {
    final responseRange = _ResponseRange.tryParse(
      response.headers.value(HttpHeaders.contentRangeHeader),
    );
    if (responseRange?.total case final total?) {
      _contentLength = total;
    } else if (response.statusCode == HttpStatus.ok &&
        response.contentLength >= 0) {
      _contentLength = response.contentLength;
    }
    _contentType ??= response.headers.value(HttpHeaders.contentTypeHeader);
    _etag ??= response.headers.value(HttpHeaders.etagHeader);
    _lastModified ??= response.headers.value(HttpHeaders.lastModifiedHeader);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final response = request.response..bufferOutput = false;
    try {
      if (request.method == 'HEAD' && _contentLength != null) {
        response.statusCode = HttpStatus.ok;
        _setEntityHeaders(response);
        response.contentLength = _contentLength!;
        await response.close();
        return;
      }

      final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
      final range = _ByteRange.fromHttpHeader(rangeHeader, _contentLength);
      if (request.method == 'GET' && range != null) {
        await _serveRange(request, range);
        return;
      }

      await _proxyDirect(request);
    } catch (_) {
      try {
        response.statusCode = HttpStatus.badGateway;
      } catch (_) {
        // 响应头已经发出时只能关闭连接。
      }
      try {
        await response.close();
      } catch (_) {
        // mpv 可能已取消本次 Range。
      }
    }
  }

  Future<void> _serveRange(HttpRequest request, _ByteRange range) async {
    final response = request.response;
    final total = _contentLength!;
    if (range.start >= total || range.start < 0) {
      response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      response.headers.set(HttpHeaders.contentRangeHeader, 'bytes */$total');
      await response.close();
      return;
    }

    final effective = _ByteRange(range.start, min(range.end, total - 1));
    response.statusCode = HttpStatus.partialContent;
    response.headers
      ..set('accept-ranges', 'bytes')
      ..set(
        HttpHeaders.contentRangeHeader,
        'bytes ${effective.start}-${effective.end}/$total',
      );
    _setEntityHeaders(response);
    response.contentLength = effective.length;

    var cursor = effective.start;
    while (cursor <= effective.end) {
      final cached = _cache.readFrom(cursor, effective.end);
      if (cached != null) {
        response.add(cached);
        cursor += cached.length;
        continue;
      }

      final nextCached = _cache.nextStartAfter(cursor);
      final gapEnd = nextCached == null
          ? effective.end
          : min(effective.end, nextCached - 1);
      await _pipeUpstreamRange(request, response, _ByteRange(cursor, gapEnd));
      cursor = gapEnd + 1;
    }
    await response.close();
  }

  Future<void> _pipeUpstreamRange(
    HttpRequest request,
    HttpResponse response,
    _ByteRange range,
  ) async {
    var cursor = range.start;
    var attempts = 0;
    while (cursor <= range.end) {
      final attemptStart = cursor;
      try {
        final upstream = await _openUpstream(
          'GET',
          requestHeaders: request.headers,
          range: _ByteRange(cursor, range.end),
        );
        final sourceResponse = upstream.response;
        _recordResponse(sourceResponse);
        final responseRange = _ResponseRange.tryParse(
          sourceResponse.headers.value(HttpHeaders.contentRangeHeader),
        );
        if (sourceResponse.statusCode != HttpStatus.partialContent ||
            responseRange == null ||
            responseRange.start != cursor ||
            responseRange.end < cursor) {
          await sourceResponse.drain<void>();
          throw HttpException('Upstream did not honor media Range');
        }

        var received = 0;
        await for (final chunk in sourceResponse) {
          final remaining = range.end - cursor + 1;
          if (remaining <= 0) {
            break;
          }
          final take = min(remaining, chunk.length);
          response.add(take == chunk.length ? chunk : chunk.sublist(0, take));
          received += take;
          cursor += take;
          if (cursor > range.end) {
            break;
          }
        }
        if (received == 0) {
          throw HttpException('Upstream media Range ended without data');
        }
        attempts = 0;
      } catch (_) {
        attempts = cursor > attemptStart ? 0 : attempts + 1;
        if (attempts >= _maxRangeAttempts) {
          rethrow;
        }
      }
    }
  }

  Future<void> _proxyDirect(HttpRequest request) async {
    final upstream = await _openUpstream(
      request.method,
      requestHeaders: request.headers,
    );
    final sourceResponse = upstream.response;
    _recordResponse(sourceResponse);
    final response = request.response;
    response.statusCode = sourceResponse.statusCode;
    sourceResponse.headers.forEach((name, values) {
      if (!_shouldSkipResponseHeader(name)) {
        response.headers.set(name, values);
      }
    });
    if (request.method != 'HEAD') {
      await response.addStream(sourceResponse);
    } else {
      await sourceResponse.drain<void>();
    }
    await response.close();
  }

  void _setEntityHeaders(HttpResponse response) {
    response.headers.set('accept-ranges', 'bytes');
    if (_contentType case final value?) {
      response.headers.set(HttpHeaders.contentTypeHeader, value);
    }
    if (_etag case final value?) {
      response.headers.set(HttpHeaders.etagHeader, value);
    }
    if (_lastModified case final value?) {
      response.headers.set(HttpHeaders.lastModifiedHeader, value);
    }
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    if (!_ready.isCompleted) {
      if (_prewarmStarted) {
        _ready.completeError(StateError('VideoTrackProxy closed before ready'));
      } else {
        _ready.complete();
      }
    }
    _client.close(force: true);
    try {
      await _requests.cancel();
    } catch (_) {
      // 监听可能已经随服务器终止。
    }
    try {
      await _server.close(force: true);
    } catch (_) {
      // 端口已关闭时无需重复处理。
    }
  }
}

final class _UpstreamResponse {
  const _UpstreamResponse(this.response);

  final HttpClientResponse response;
}

final class _ByteRange {
  const _ByteRange(this.start, this.end);

  final int start;
  final int end;

  int get length => end - start + 1;

  static _ByteRange? tryParse(String? value) {
    if (value == null) {
      return null;
    }
    final match = RegExp(r'^\s*(\d+)\s*-\s*(\d+)\s*$').firstMatch(value);
    if (match == null) {
      return null;
    }
    final start = int.parse(match.group(1)!);
    final end = int.parse(match.group(2)!);
    return start <= end ? _ByteRange(start, end) : null;
  }

  static _ByteRange? fromHttpHeader(String? value, int? totalLength) {
    if (value == null || totalLength == null) {
      return null;
    }
    final match = RegExp(
      r'^bytes=(\d*)-(\d*)$',
      caseSensitive: false,
    ).firstMatch(value.trim());
    if (match == null) {
      return null;
    }
    final startText = match.group(1)!;
    final endText = match.group(2)!;
    if (startText.isEmpty) {
      final suffixLength = int.tryParse(endText);
      if (suffixLength == null || suffixLength <= 0) {
        return null;
      }
      final start = max(0, totalLength - suffixLength);
      return _ByteRange(start, totalLength - 1);
    }
    final start = int.tryParse(startText);
    final end = endText.isEmpty ? totalLength - 1 : int.tryParse(endText);
    if (start == null || end == null || start > end) {
      return null;
    }
    return _ByteRange(start, end);
  }
}

final class _ResponseRange {
  const _ResponseRange(this.start, this.end, this.total);

  final int start;
  final int end;
  final int? total;

  static _ResponseRange? tryParse(String? value) {
    if (value == null) {
      return null;
    }
    final match = RegExp(
      r'^bytes\s+(\d+)-(\d+)/(\d+|\*)$',
      caseSensitive: false,
    ).firstMatch(value.trim());
    if (match == null) {
      return null;
    }
    return _ResponseRange(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      match.group(3) == '*' ? null : int.parse(match.group(3)!),
    );
  }
}

final class _RangeCache {
  final List<_CachedChunk> _chunks = [];

  void add(int start, Uint8List bytes) {
    if (bytes.isEmpty) {
      return;
    }
    var mergedStart = start;
    var mergedEnd = start + bytes.length - 1;
    final overlapping = <_CachedChunk>[];
    for (final chunk in _chunks) {
      if (chunk.end + 1 >= mergedStart && chunk.start <= mergedEnd + 1) {
        overlapping.add(chunk);
        mergedStart = min(mergedStart, chunk.start);
        mergedEnd = max(mergedEnd, chunk.end);
      }
    }

    final merged = Uint8List(mergedEnd - mergedStart + 1);
    for (final chunk in overlapping) {
      merged.setRange(
        chunk.start - mergedStart,
        chunk.end - mergedStart + 1,
        chunk.bytes,
      );
    }
    merged.setRange(
      start - mergedStart,
      start - mergedStart + bytes.length,
      bytes,
    );
    _chunks
      ..removeWhere(overlapping.contains)
      ..add(_CachedChunk(mergedStart, merged))
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  Uint8List? readExact(_ByteRange range) {
    final bytes = readFrom(range.start, range.end);
    return bytes != null && bytes.length == range.length ? bytes : null;
  }

  Uint8List? readFrom(int start, int end) {
    for (final chunk in _chunks) {
      if (chunk.start <= start && chunk.end >= start) {
        final availableEnd = min(end, chunk.end);
        return Uint8List.sublistView(
          chunk.bytes,
          start - chunk.start,
          availableEnd - chunk.start + 1,
        );
      }
    }
    return null;
  }

  int? nextStartAfter(int offset) {
    for (final chunk in _chunks) {
      if (chunk.start > offset) {
        return chunk.start;
      }
    }
    return null;
  }
}

final class _CachedChunk {
  const _CachedChunk(this.start, this.bytes);

  final int start;
  final Uint8List bytes;

  int get end => start + bytes.length - 1;
}

final class _Sidx {
  const _Sidx({required this.timescale, required this.references});

  final int timescale;
  final List<_SidxReference> references;

  int referenceIndexAt(Duration position) {
    if (references.isEmpty) {
      return -1;
    }
    final target =
        position.inMicroseconds * timescale ~/ Duration.microsecondsPerSecond;
    for (var i = 0; i < references.length; i++) {
      final reference = references[i];
      if (target < reference.startTime + reference.duration) {
        return i;
      }
    }
    return references.length - 1;
  }

  _SidxReference referenceAt(Duration position) =>
      references[referenceIndexAt(position)];

  static _Sidx? tryParse(Uint8List bytes, int absoluteStart) {
    final box = _findSidx(bytes);
    if (box == null) {
      return null;
    }
    final data = ByteData.sublistView(bytes);
    var offset = box.payloadStart;
    final limit = box.end;
    if (offset + 12 > limit) {
      return null;
    }

    final version = data.getUint8(offset);
    offset += 4; // version + flags
    offset += 4; // reference_ID
    final timescale = data.getUint32(offset, Endian.big);
    offset += 4;
    if (timescale == 0) {
      return null;
    }

    final int earliestPresentationTime;
    final int firstOffset;
    if (version == 0) {
      if (offset + 8 > limit) {
        return null;
      }
      earliestPresentationTime = data.getUint32(offset, Endian.big);
      firstOffset = data.getUint32(offset + 4, Endian.big);
      offset += 8;
    } else if (version == 1) {
      if (offset + 16 > limit) {
        return null;
      }
      earliestPresentationTime = data.getUint64(offset, Endian.big);
      firstOffset = data.getUint64(offset + 8, Endian.big);
      offset += 16;
    } else {
      return null;
    }

    if (offset + 4 > limit) {
      return null;
    }
    offset += 2; // reserved
    final referenceCount = data.getUint16(offset, Endian.big);
    offset += 2;

    var mediaOffset = absoluteStart + box.end + firstOffset;
    var presentationTime = earliestPresentationTime;
    final references = <_SidxReference>[];
    for (var i = 0; i < referenceCount; i++) {
      if (offset + 12 > limit) {
        return null;
      }
      final sizeAndType = data.getUint32(offset, Endian.big);
      final size = sizeAndType & 0x7fffffff;
      final duration = data.getUint32(offset + 4, Endian.big);
      offset += 12;
      if (size <= 0) {
        return null;
      }
      references.add(
        _SidxReference(
          range: _ByteRange(mediaOffset, mediaOffset + size - 1),
          startTime: presentationTime,
          duration: duration,
          isIndex: (sizeAndType & 0x80000000) != 0,
        ),
      );
      mediaOffset += size;
      presentationTime += duration;
    }
    return references.isEmpty
        ? null
        : _Sidx(timescale: timescale, references: references);
  }

  static _Mp4Box? _findSidx(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    var offset = 0;
    while (offset + 8 <= bytes.length) {
      final box = _readBox(data, bytes.length, offset);
      if (box == null) {
        break;
      }
      if (_boxType(bytes, offset + 4) == 'sidx') {
        return box;
      }
      offset = box.end;
    }

    // indexRange 可能从 box 中间开始；扫描 type 并回看 size 字段。
    for (var i = 4; i + 4 <= bytes.length; i++) {
      if (_boxType(bytes, i) != 'sidx') {
        continue;
      }
      final box = _readBox(data, bytes.length, i - 4);
      if (box != null) {
        return box;
      }
    }
    return null;
  }

  static _Mp4Box? _readBox(ByteData data, int length, int offset) {
    if (offset < 0 || offset + 8 > length) {
      return null;
    }
    var size = data.getUint32(offset, Endian.big);
    var headerSize = 8;
    if (size == 1) {
      if (offset + 16 > length) {
        return null;
      }
      size = data.getUint64(offset + 8, Endian.big);
      headerSize = 16;
    } else if (size == 0) {
      size = length - offset;
    }
    if (size < headerSize || offset + size > length) {
      return null;
    }
    return _Mp4Box(offset + headerSize, offset + size);
  }

  static String _boxType(Uint8List bytes, int offset) {
    if (offset < 0 || offset + 4 > bytes.length) {
      return '';
    }
    return String.fromCharCodes(bytes.sublist(offset, offset + 4));
  }
}

final class _Mp4Box {
  const _Mp4Box(this.payloadStart, this.end);

  final int payloadStart;
  final int end;
}

final class _SidxReference {
  const _SidxReference({
    required this.range,
    required this.startTime,
    required this.duration,
    required this.isIndex,
  });

  final _ByteRange range;
  final int startTime;
  final int duration;
  final bool isIndex;
}
