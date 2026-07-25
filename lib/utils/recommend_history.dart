import 'dart:async';
import 'dart:convert';

import 'package:PiliPlus/models/common/account_type.dart';
import 'package:PiliPlus/models/common/recommend_history_filter_settings.dart';
import 'package:PiliPlus/models/model_rec_video_item.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:hive_ce/hive.dart';
import 'package:synchronized/synchronized.dart';

const Duration recommendHistoryRetention = Duration(days: 30);

String currentRecommendHistoryScope() {
  final mid = Accounts.get(AccountType.recommend).mid;
  return mid > 0 ? 'uid:$mid' : 'guest:${Pref.blockUserID}';
}

String? recommendVideoKey(BaseRcmdVideoItemModel item) {
  final epId = item.param;
  if (item.goto == 'bangumi' && epId != null && epId > 0) {
    return 'pgc:$epId';
  }
  if (item.aid case final aid? when aid > 0) {
    return 'ugc:$aid';
  }
  return null;
}

String? playbackVideoKey({
  required int? aid,
  required int? epId,
  required bool isPgc,
}) {
  if (isPgc && epId != null && epId > 0) {
    return 'pgc:$epId';
  }
  if (aid != null && aid > 0) {
    return 'ugc:$aid';
  }
  return null;
}

class RecommendHistoryRepository {
  static const String _daysKey = 'meta|days';
  static const String _lastCleanupDayKey = 'meta|lastCleanupDay';
  static const int _deleteBatchSize = 500;

  static RecommendHistoryRepository? _instance;

  static RecommendHistoryRepository get instance {
    final value = _instance;
    if (value == null) {
      throw StateError('RecommendHistoryRepository is not initialized');
    }
    return value;
  }

  static void initialize({
    required Box<dynamic> exposureBox,
    required Box<dynamic> watchBox,
  }) {
    _instance = RecommendHistoryRepository(
      exposureBox: exposureBox,
      watchBox: watchBox,
    );
  }

  final Box<dynamic> exposureBox;
  final Box<dynamic> watchBox;
  final Lock _lock = Lock();
  final Lock _exposureQueueLock = Lock();
  final List<_PendingExposure> _pendingExposures = [];
  Timer? _exposureFlushTimer;

  RecommendHistoryRepository({
    required this.exposureBox,
    required this.watchBox,
  });

  Future<void> recordExposure({
    required String scopeId,
    required String occurrenceId,
    required String videoKey,
    DateTime? exposedAt,
  }) {
    final completer = Completer<void>();
    _pendingExposures.add(
      _PendingExposure(
        scopeId: scopeId,
        occurrenceId: occurrenceId,
        videoKey: videoKey,
        exposedAt: exposedAt ?? DateTime.now(),
        completer: completer,
      ),
    );
    if (_pendingExposures.length >= 20) {
      _exposureFlushTimer?.cancel();
      _exposureFlushTimer = null;
      unawaited(_flushPendingExposures().catchError((_) {}));
    } else {
      _exposureFlushTimer ??= Timer(const Duration(milliseconds: 350), () {
        _exposureFlushTimer = null;
        unawaited(_flushPendingExposures().catchError((_) {}));
      });
    }
    return completer.future;
  }

  Future<void> _writeExposureLocked(_PendingExposure event) async {
    final now = event.exposedAt;
    await _cleanupIfNeededLocked(now);

    final scopePart = _encode(event.scopeId);
    final occurrenceLocator = 'o|$scopePart|${_encode(event.occurrenceId)}';
    if (exposureBox.containsKey(occurrenceLocator)) {
      return;
    }

    final day = _localDay(now);
    final dataKey = _videoDataKey('e', event.scopeId, day, event.videoKey);
    final events = _intMap(exposureBox.get(dataKey));
    events[event.occurrenceId] = now.millisecondsSinceEpoch;

    final dayIndexKey = _dayIndexKey(day);
    final dayKeys = _stringList(exposureBox.get(dayIndexKey));
    if (!dayKeys.contains(dataKey)) {
      dayKeys.add(dataKey);
    }
    final days = _intList(exposureBox.get(_daysKey));
    if (!days.contains(day)) {
      days
        ..add(day)
        ..sort();
    }

    await exposureBox.putAll({
      dataKey: events,
      occurrenceLocator: <Object>[dataKey, now.millisecondsSinceEpoch],
      dayIndexKey: dayKeys,
      _daysKey: days,
    });
  }

  Future<void> createPlaySession({
    required String scopeId,
    required String sessionId,
    required String videoKey,
    required DateTime firstFrameAt,
  }) => _lock.synchronized(() async {
    await _cleanupIfNeededLocked(firstFrameAt);
    final sessionLocator = _sessionLocator(sessionId);
    if (watchBox.containsKey(sessionLocator)) {
      return;
    }

    final day = _localDay(firstFrameAt);
    final dataKey = _videoDataKey('w', scopeId, day, videoKey);
    final sessions = _sessionMap(watchBox.get(dataKey));
    final atMs = firstFrameAt.millisecondsSinceEpoch;
    sessions[sessionId] = <int>[atMs, 0, atMs, 0];

    final dayIndexKey = _dayIndexKey(day);
    final dayKeys = _stringList(watchBox.get(dayIndexKey));
    if (!dayKeys.contains(dataKey)) {
      dayKeys.add(dataKey);
    }
    final days = _intList(watchBox.get(_daysKey));
    if (!days.contains(day)) {
      days
        ..add(day)
        ..sort();
    }

    await watchBox.putAll({
      dataKey: sessions,
      sessionLocator: <Object>[dataKey, atMs],
      dayIndexKey: dayKeys,
      _daysKey: days,
    });
  });

  Future<void> updatePlaySession({
    required String sessionId,
    required int activePlayedMs,
    required bool ended,
    DateTime? updatedAt,
  }) => _lock.synchronized(() async {
    final locator = watchBox.get(_sessionLocator(sessionId));
    if (locator is! List || locator.isEmpty || locator.first is! String) {
      return;
    }
    final dataKey = locator.first as String;
    final sessions = _sessionMap(watchBox.get(dataKey));
    final current = sessions[sessionId];
    if (current == null || current.isEmpty) {
      return;
    }

    final nowMs = (updatedAt ?? DateTime.now()).millisecondsSinceEpoch;
    sessions[sessionId] = <int>[
      current[0],
      activePlayedMs.clamp(0, 300000).toInt(),
      nowMs,
      ended ? 1 : 0,
    ];
    await watchBox.put(dataKey, sessions);
  });

  Future<Set<String>> findBlockedVideos({
    required String scopeId,
    required Set<String> candidateVideoKeys,
    required RecommendHistoryFilterSettings settings,
    DateTime? now,
  }) async {
    if (!settings.enabled ||
        candidateVideoKeys.isEmpty ||
        (settings.exposureThreshold == 0 && settings.watchThreshold == 0)) {
      return <String>{};
    }

    await _flushPendingExposures();
    return _lock.synchronized(() async {
      final current = now ?? DateTime.now();
      await _cleanupIfNeededLocked(current);
      final cutoffMs = current
          .subtract(Duration(minutes: settings.lookbackMinutes))
          .millisecondsSinceEpoch;
      final days = _daysInWindow(cutoffMs, current.millisecondsSinceEpoch);
      final blocked = <String>{};

      if (settings.exposureThreshold > 0) {
        for (final videoKey in candidateVideoKeys) {
          var count = 0;
          for (final day in days) {
            final events = _intMap(
              exposureBox.get(_videoDataKey('e', scopeId, day, videoKey)),
            );
            count += events.values
                .where((timestamp) => timestamp >= cutoffMs)
                .length;
            if (count >= settings.exposureThreshold) {
              blocked.add(videoKey);
              break;
            }
          }
        }
      }

      if (settings.watchThreshold > 0) {
        final minWatchMs = settings.minWatchSeconds * 1000;
        for (final videoKey in candidateVideoKeys.difference(blocked)) {
          var count = 0;
          for (final day in days) {
            final sessions = _sessionMap(
              watchBox.get(_videoDataKey('w', scopeId, day, videoKey)),
            );
            count += sessions.values.where((session) {
              return session.isNotEmpty &&
                  session[0] >= cutoffMs &&
                  session.length > 1 &&
                  session[1] >= minWatchMs;
            }).length;
            if (count >= settings.watchThreshold) {
              blocked.add(videoKey);
              break;
            }
          }
        }
      }

      return blocked;
    });
  }

  Future<void> flush() async {
    while (_pendingExposures.isNotEmpty) {
      await _flushPendingExposures();
    }
    await _lock.synchronized(() {});
  }

  Future<void> _flushPendingExposures() =>
      _exposureQueueLock.synchronized(() async {
        if (_pendingExposures.isEmpty) {
          return;
        }
        _exposureFlushTimer?.cancel();
        _exposureFlushTimer = null;
        final batch = List<_PendingExposure>.of(_pendingExposures);
        _pendingExposures.clear();
        try {
          await _lock.synchronized(() async {
            for (final event in batch) {
              await _writeExposureLocked(event);
            }
          });
          for (final event in batch) {
            if (!event.completer.isCompleted) {
              event.completer.complete();
            }
          }
        } catch (_) {
          _pendingExposures.insertAll(0, batch);
          _exposureFlushTimer ??= Timer(const Duration(seconds: 1), () {
            _exposureFlushTimer = null;
            unawaited(_flushPendingExposures().catchError((_) {}));
          });
          rethrow;
        }
      });

  Future<void> maybeCleanup([DateTime? now]) =>
      _lock.synchronized(() => _cleanupIfNeededLocked(now ?? DateTime.now()));

  Future<void> _cleanupIfNeededLocked(DateTime now) async {
    final today = _localDay(now);
    if (exposureBox.get(_lastCleanupDayKey) == today &&
        watchBox.get(_lastCleanupDayKey) == today) {
      return;
    }

    final cutoffMs = now
        .subtract(recommendHistoryRetention)
        .millisecondsSinceEpoch;
    await _cleanupBox(exposureBox, cutoffMs, exposure: true);
    await _cleanupBox(watchBox, cutoffMs, exposure: false);
    await Future.wait([
      exposureBox.put(_lastCleanupDayKey, today),
      watchBox.put(_lastCleanupDayKey, today),
    ]);
  }

  Future<void> _cleanupBox(
    Box<dynamic> box,
    int cutoffMs, {
    required bool exposure,
  }) async {
    final boundaryDay = _localDay(
      DateTime.fromMillisecondsSinceEpoch(cutoffMs),
    );
    final days = _intList(box.get(_daysKey));
    final retainedDays = <int>[];

    for (final day in days) {
      if (day > boundaryDay) {
        retainedDays.add(day);
        continue;
      }

      final dayIndexKey = _dayIndexKey(day);
      final dataKeys = _stringList(box.get(dayIndexKey));
      if (day < boundaryDay) {
        final deleteKeys = <dynamic>[dayIndexKey];
        for (final dataKey in dataKeys) {
          deleteKeys
            ..add(dataKey)
            ..addAll(
              _locatorKeysForValue(
                dataKey,
                box.get(dataKey),
                exposure: exposure,
              ),
            );
        }
        await _deleteInBatches(box, deleteKeys);
        continue;
      }

      final retainedDataKeys = <String>[];
      for (final dataKey in dataKeys) {
        if (exposure) {
          final events = _intMap(box.get(dataKey));
          final expired = events.entries
              .where((entry) => entry.value < cutoffMs)
              .map((entry) => entry.key)
              .toList();
          for (final occurrenceId in expired) {
            events.remove(occurrenceId);
            await box.delete(
              _occurrenceLocatorFromDataKey(dataKey, occurrenceId),
            );
          }
          if (events.isEmpty) {
            await box.delete(dataKey);
          } else {
            retainedDataKeys.add(dataKey);
            await box.put(dataKey, events);
          }
        } else {
          final sessions = _sessionMap(box.get(dataKey));
          final expired = sessions.entries
              .where(
                (entry) => entry.value.isEmpty || entry.value[0] < cutoffMs,
              )
              .map((entry) => entry.key)
              .toList();
          for (final sessionId in expired) {
            sessions.remove(sessionId);
            await box.delete(_sessionLocator(sessionId));
          }
          if (sessions.isEmpty) {
            await box.delete(dataKey);
          } else {
            retainedDataKeys.add(dataKey);
            await box.put(dataKey, sessions);
          }
        }
      }

      if (retainedDataKeys.isEmpty) {
        await box.delete(dayIndexKey);
      } else {
        retainedDays.add(day);
        await box.put(dayIndexKey, retainedDataKeys);
      }
    }

    await box.put(_daysKey, retainedDays);
  }

  Future<void> _deleteInBatches(Box<dynamic> box, List<dynamic> keys) async {
    for (var offset = 0; offset < keys.length; offset += _deleteBatchSize) {
      final end = (offset + _deleteBatchSize).clamp(0, keys.length).toInt();
      await box.deleteAll(keys.sublist(offset, end));
      await Future<void>.delayed(Duration.zero);
    }
  }

  Iterable<String> _locatorKeysForValue(
    String dataKey,
    Object? raw, {
    required bool exposure,
  }) {
    if (raw is! Map) {
      return const <String>[];
    }
    if (exposure) {
      return raw.keys.whereType<String>().map(
        (id) => _occurrenceLocatorFromDataKey(dataKey, id),
      );
    }
    return raw.keys.whereType<String>().map(_sessionLocator);
  }

  static String _videoDataKey(
    String prefix,
    String scope,
    int day,
    String videoKey,
  ) => '$prefix|$day|${_encode(scope)}|${_encode(videoKey)}';

  static String _dayIndexKey(int day) => 'd|$day';

  static String _sessionLocator(String sessionId) => 's|${_encode(sessionId)}';

  static String _occurrenceLocatorFromDataKey(
    String dataKey,
    String occurrenceId,
  ) {
    final parts = dataKey.split('|');
    final scopePart = parts.length > 2 ? parts[2] : '';
    return 'o|$scopePart|${_encode(occurrenceId)}';
  }

  static String _encode(String value) =>
      base64Url.encode(utf8.encode(value)).replaceAll('=', '');

  static int _localDay(DateTime value) {
    final local = value.toLocal();
    return local.year * 10000 + local.month * 100 + local.day;
  }

  static List<int> _daysInWindow(int startMs, int endMs) {
    var day = DateTime.fromMillisecondsSinceEpoch(startMs).toLocal();
    day = DateTime(day.year, day.month, day.day);
    final end = DateTime.fromMillisecondsSinceEpoch(endMs).toLocal();
    final endDay = DateTime(end.year, end.month, end.day);
    final result = <int>[];
    while (!day.isAfter(endDay)) {
      result.add(_localDay(day));
      day = DateTime(day.year, day.month, day.day + 1);
    }
    return result;
  }

  static Map<String, int> _intMap(Object? value) {
    if (value is! Map) {
      return <String, int>{};
    }
    return <String, int>{
      for (final entry in value.entries)
        if (entry.key is String && entry.value is num)
          entry.key as String: (entry.value as num).toInt(),
    };
  }

  static Map<String, List<int>> _sessionMap(Object? value) {
    if (value is! Map) {
      return <String, List<int>>{};
    }
    return <String, List<int>>{
      for (final entry in value.entries)
        if (entry.key is String && entry.value is List)
          entry.key as String: (entry.value as List)
              .whereType<num>()
              .map((item) => item.toInt())
              .toList(),
    };
  }

  static List<String> _stringList(Object? value) =>
      value is List ? value.whereType<String>().toList() : <String>[];

  static List<int> _intList(Object? value) => value is List
      ? value.whereType<num>().map((item) => item.toInt()).toList()
      : <int>[];
}

class _PendingExposure {
  final String scopeId;
  final String occurrenceId;
  final String videoKey;
  final DateTime exposedAt;
  final Completer<void> completer;

  const _PendingExposure({
    required this.scopeId,
    required this.occurrenceId,
    required this.videoKey,
    required this.exposedAt,
    required this.completer,
  });
}
