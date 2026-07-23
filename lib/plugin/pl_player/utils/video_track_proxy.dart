import 'dart:async' show Completer, StreamSubscription;
import 'dart:io'
    show
        HttpClient,
        HttpHeaders,
        HttpRequest,
        HttpServer,
        HttpStatus,
        InternetAddress;

import 'package:PiliPlus/utils/storage_pref.dart';

/// 为 mpv 外部视频轨提供一个回环 HTTP 入口。
///
/// [arm] 之后，代理会先在内存中累计 [requiredBytes]，再把响应交给 mpv。
/// 这样即使 mpv 不公开外部 demuxer 的缓存时长，也能在选轨后、首帧出现前
/// 确认新轨已经下载了与播放门槛等价的数据量。
final class VideoTrackProxy {
  VideoTrackProxy._({
    required this.source,
    required this.requiredBytes,
    required String? upstreamProxy,
    required HttpServer server,
  }) : _server = server,
       _client = HttpClient()
         ..autoUncompress = false
         ..idleTimeout = const Duration(seconds: 15) {
    final customProxy = Uri.tryParse(upstreamProxy ?? '');
    if (source.scheme == 'http' &&
        customProxy != null &&
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

  final Uri source;
  final int requiredBytes;
  final HttpServer _server;
  final HttpClient _client;
  late final StreamSubscription<HttpRequest> _requests;

  Completer<void>? _ready;
  int _bufferGeneration = 0;
  int _bufferedBytes = 0;
  bool _closed = false;

  Uri get uri => Uri(
    scheme: 'http',
    host: InternetAddress.loopbackIPv4.address,
    port: _server.port,
    path: '/video',
  );

  Future<void> get ready {
    final ready = _ready;
    if (ready == null) {
      return Future<void>.error(StateError('VideoTrackProxy is not armed'));
    }
    return ready.future;
  }

  static Future<VideoTrackProxy> create({
    required String source,
    required int requiredBytes,
    String? upstreamProxy,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return VideoTrackProxy._(
      source: Uri.parse(source),
      requiredBytes: requiredBytes,
      upstreamProxy: upstreamProxy,
      server: server,
    );
  }

  /// 从下一批上游数据开始执行一次缓存门控。
  void arm() {
    if (_closed) {
      throw StateError('VideoTrackProxy is closed');
    }
    _bufferGeneration++;
    _bufferedBytes = 0;
    _ready = Completer<void>();
  }

  bool _shouldSkipRequestHeader(String name) {
    final lower = name.toLowerCase();
    return lower == HttpHeaders.hostHeader ||
        lower == HttpHeaders.contentLengthHeader ||
        lower == HttpHeaders.transferEncodingHeader ||
        lower == HttpHeaders.connectionHeader;
  }

  bool _shouldSkipResponseHeader(String name) {
    final lower = name.toLowerCase();
    return lower == HttpHeaders.transferEncodingHeader ||
        lower == HttpHeaders.connectionHeader;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final response = request.response..bufferOutput = true;
    try {
      final upstreamRequest = await _client.openUrl(request.method, source);
      request.headers.forEach((name, values) {
        if (!_shouldSkipRequestHeader(name)) {
          upstreamRequest.headers.set(name, values);
        }
      });

      final upstream = await upstreamRequest.close();
      response.statusCode = upstream.statusCode;
      upstream.headers.forEach((name, values) {
        if (!_shouldSkipResponseHeader(name)) {
          response.headers.set(name, values);
        }
      });

      var generation = _bufferGeneration;
      final heldChunks = <List<int>>[];

      Future<void> flushHeldChunks() async {
        if (heldChunks.isEmpty) {
          return;
        }
        for (final chunk in heldChunks) {
          response.add(chunk);
        }
        heldChunks.clear();
        await response.flush();
      }

      await for (final chunk in upstream) {
        final ready = _ready;
        if (ready != null && !ready.isCompleted) {
          if (generation != _bufferGeneration) {
            await flushHeldChunks();
            generation = _bufferGeneration;
          }
          heldChunks.add(chunk);
          _bufferedBytes += chunk.length;
          if (_bufferedBytes >= requiredBytes) {
            await flushHeldChunks();
            if (!ready.isCompleted) {
              ready.complete();
            }
          }
        } else {
          await flushHeldChunks();
          response.add(chunk);
        }
      }

      // 小的索引 Range 可能不足门槛；先放行，让 mpv 发起后续媒体 Range。
      await flushHeldChunks();
      await response.close();
    } catch (error, stackTrace) {
      final ready = _ready;
      if (ready != null && !ready.isCompleted) {
        ready.completeError(error, stackTrace);
      }
      try {
        response.statusCode = HttpStatus.badGateway;
      } catch (_) {
        // 响应头已经发出时只能关闭连接。
      }
      try {
        await response.close();
      } catch (_) {
        // 连接可能已经由 mpv 或 close(force: true) 提前关闭。
      }
    }
  }

  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    final ready = _ready;
    if (ready != null && !ready.isCompleted) {
      ready.completeError(StateError('VideoTrackProxy closed before ready'));
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
