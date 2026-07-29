import 'dart:convert';
import 'dart:io';

import 'package:PiliPlus/utils/path_utils.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as path;

abstract final class MpvLogService {
  static const _maxBytes = 20 * 1024 * 1024;
  static final File _file = File(
    path.join(appSupportDirPath, 'mpv_last_playback.log'),
  );

  static Future<void> _operation = Future.value();
  static IOSink? _sink;
  static final Set<Player> _activePlayers = Set<Player>.identity();
  static int _session = 0;
  static bool _sessionActive = false;
  static int _writtenBytes = 0;
  static int _pendingBytes = 0;
  static bool _truncated = false;

  static Future<void> _run(Future<void> Function() action) {
    return _operation = _operation.then((_) async {
      try {
        await action();
      } catch (_) {
        // 日志写入失败不能影响播放，也不能阻断后续写入。
      }
    });
  }

  static Future<int> beginSession(
    Player? player, {
    required String source,
  }) {
    final session = ++_session;
    _sessionActive = true;
    _activePlayers.clear();
    if (player != null) {
      _activePlayers.add(player);
    }
    final header = [
      '# PiliPlus mpv playback log',
      '# source: $source',
      '# level: ${Pref.mpvLogLevel}',
      '# started: ${DateTime.now().toIso8601String()}',
      '',
    ].join('\n');
    _writtenBytes = utf8.encode(header).length;
    _pendingBytes = 0;
    _truncated = false;

    return _run(() async {
      if (session != _session) return;
      final oldSink = _sink;
      _sink = null;
      await oldSink?.flush();
      await oldSink?.close();
      if (session != _session) return;
      final sink = _file.openWrite();
      _sink = sink;
      sink.write(header);
      await sink.flush();
    }).then((_) => session);
  }

  static bool isSessionActive(int? session) =>
      session != null && _sessionActive && session == _session;

  static bool attachPlayer(
    Player player, {
    required int session,
  }) {
    if (!isSessionActive(session)) return false;
    _activePlayers.add(player);
    return true;
  }

  static void detachPlayer(
    Player player, {
    required int session,
  }) {
    if (session == _session) {
      _activePlayers.remove(player);
    }
  }

  static Future<void> endSession(int session) {
    if (!isSessionActive(session)) {
      return Future<void>.value();
    }

    _sessionActive = false;
    _activePlayers.clear();
    return _run(() async {
      if (session != _session || _sessionActive) return;
      final oldSink = _sink;
      _sink = null;
      await oldSink?.flush();
      await oldSink?.close();
    });
  }

  static void add(Player player, PlayerLog log) {
    if (!_sessionActive ||
        !_activePlayers.contains(player) ||
        _truncated) {
      return;
    }

    final session = _session;
    final line =
        '[${DateTime.now().toIso8601String()}] '
        '[${log.level}] [${log.prefix}] ${log.text}\n';
    final bytes = utf8.encode(line).length;

    if (_writtenBytes + bytes > _maxBytes) {
      _truncated = true;
      const marker = '\n# 日志已达到 20 MiB，后续内容不再写入。\n';

      _run(() async {
        if (session != _session) {
          return;
        }

        final sink = _sink;
        if (sink == null) {
          return;
        }

        sink.write(marker);
        await sink.flush();
      });

      return;
    }

    _writtenBytes += bytes;
    _pendingBytes += bytes;

    final shouldFlush =
        _pendingBytes >= 64 * 1024 ||
        log.level == 'error' ||
        log.level == 'fatal';

    if (shouldFlush) {
      _pendingBytes = 0;
    }

    // 所有 write 与 flush 都进入同一异步队列。
    // IOSink.flush 执行期间不能再次直接调用 write。
    _run(() async {
      if (session != _session) {
        return;
      }

      final sink = _sink;
      if (sink == null) {
        return;
      }

      sink.write(line);

      if (shouldFlush) {
        await sink.flush();
      }
    });
  }

  static Future<String> readLastLog() async {
    await _operation;
    await _sink?.flush();
    if (!await _file.exists()) return '';
    return _file.readAsString();
  }

  static Future<void> clear() {
    _writtenBytes = 0;
    _pendingBytes = 0;
    _truncated = false;
    return _run(() async {
      final oldSink = _sink;
      _sink = null;
      await oldSink?.flush();
      await oldSink?.close();
      await _file.writeAsString('', flush: true);
      if (_sessionActive) {
        _sink = _file.openWrite(mode: FileMode.append);
      }
    });
  }
}
