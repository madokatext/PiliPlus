import 'dart:async';
import 'dart:convert';
import 'dart:io' show File, FileSystemException;

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

class RecommendHistoryWindowStatistics {
  final int recommendationCount;
  final int recommendedVideoCount;
  final int watchCount;
  final int watchedVideoCount;
  final int activePlayedMs;

  const RecommendHistoryWindowStatistics({
    required this.recommendationCount,
    required this.recommendedVideoCount,
    required this.watchCount,
    required this.watchedVideoCount,
    required this.activePlayedMs,
  });
}

class RecommendHistoryStatistics {
  final int? exposureDatabaseBytes;
  final int? watchDatabaseBytes;
  final int exposureDatabaseEntryCount;
  final int watchDatabaseEntryCount;
  final int scopeCount;
  final int recommendationCount;
  final int recommendedVideoCount;
  final int watchCount;
  final int watchedVideoCount;
  final int completedWatchCount;
  final int activePlayedMs;
  final int recommendedUgcVideoCount;
  final int recommendedPgcVideoCount;
  final int watchedUgcVideoCount;
  final int watchedPgcVideoCount;
  final int currentScopeRecommendationCount;
  final int currentScopeRecommendedVideoCount;
  final int currentScopeWatchCount;
  final int currentScopeWatchedVideoCount;
  final DateTime? oldestRecordAt;
  final DateTime? newestRecordAt;
  final RecommendHistoryWindowStatistics lastDay;
  final RecommendHistoryWindowStatistics lastWeek;
  final RecommendHistoryWindowStatistics lastMonth;

  const RecommendHistoryStatistics({
    required this.exposureDatabaseBytes,
    required this.watchDatabaseBytes,
    required this.exposureDatabaseEntryCount,
    required this.watchDatabaseEntryCount,
    required this.scopeCount,
    required this.recommendationCount,
    required this.recommendedVideoCount,
    required this.watchCount,
    required this.watchedVideoCount,
    required this.completedWatchCount,
    required this.activePlayedMs,
    required this.recommendedUgcVideoCount,
    required this.recommendedPgcVideoCount,
    required this.watchedUgcVideoCount,
    required this.watchedPgcVideoCount,
    required this.currentScopeRecommendationCount,
    required this.currentScopeRecommendedVideoCount,
    required this.currentScopeWatchCount,
    required this.currentScopeWatchedVideoCount,
    required this.oldestRecordAt,
    required this.newestRecordAt,
    required this.lastDay,
    required this.lastWeek,
    required this.lastMonth,
  });

  int? get totalDatabaseBytes {
    if (exposureDatabaseBytes == null && watchDatabaseBytes == null) {
      return null;
    }
    return (exposureDatabaseBytes ?? 0) + (watchDatabaseBytes ?? 0);
  }

  int get averageActivePlayedMs =>
      watchCount == 0 ? 0 : activePlayedMs ~/ watchCount;
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

  Future<RecommendHistoryStatistics> loadStatistics({
    String? scopeId,
    DateTime? now,
  }) async {
    await flush();
    return _lock.synchronized(() async {
      final current = now ?? DateTime.now();
      await _cleanupIfNeededLocked(current);

      final total = _HistoryStatisticsAccumulator();
      final currentScope = _HistoryStatisticsAccumulator();
      final lastDay = _StatisticsWindow(
        current.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
      );
      final lastWeek = _StatisticsWindow(
        current.subtract(const Duration(days: 7)).millisecondsSinceEpoch,
      );
      final lastMonth = _StatisticsWindow(
        current.subtract(recommendHistoryRetention).millisecondsSinceEpoch,
      );
      final windows = [lastDay, lastWeek, lastMonth];
      final scopes = <String>{};
      var scannedDataKeys = 0;
      int? oldestTimestamp;
      int? newestTimestamp;

      void includeTimestamp(int timestamp) {
        if (timestamp <= 0) return;
        if (oldestTimestamp == null || timestamp < oldestTimestamp!) {
          oldestTimestamp = timestamp;
        }
        if (newestTimestamp == null || timestamp > newestTimestamp!) {
          newestTimestamp = timestamp;
        }
      }

      for (final key in exposureBox.keys.whereType<String>()) {
        final parts = _parseVideoDataKey(key, 'e');
        if (parts == null) continue;
        if (++scannedDataKeys % 500 == 0) {
          await Future<void>.delayed(Duration.zero);
        }
        scopes.add(parts.scopeId);
        final events = _intMap(exposureBox.get(key));
        for (final timestamp in events.values) {
          includeTimestamp(timestamp);
          total.addRecommendation(parts.videoKey);
          if (parts.scopeId == scopeId) {
            currentScope.addRecommendation(parts.videoKey);
          }
          for (final window in windows) {
            if (timestamp >= window.cutoffMs) {
              window.statistics.addRecommendation(parts.videoKey);
            }
          }
        }
      }

      for (final key in watchBox.keys.whereType<String>()) {
        final parts = _parseVideoDataKey(key, 'w');
        if (parts == null) continue;
        if (++scannedDataKeys % 500 == 0) {
          await Future<void>.delayed(Duration.zero);
        }
        scopes.add(parts.scopeId);
        final sessions = _sessionMap(watchBox.get(key));
        for (final session in sessions.values) {
          if (session.isEmpty) continue;
          final timestamp = session[0];
          final activePlayedMs = session.length > 1
              ? session[1].clamp(0, 300000).toInt()
              : 0;
          final completed = session.length > 3 && session[3] == 1;
          includeTimestamp(timestamp);
          total.addWatch(
            parts.videoKey,
            activePlayedMs: activePlayedMs,
            completed: completed,
          );
          if (parts.scopeId == scopeId) {
            currentScope.addWatch(
              parts.videoKey,
              activePlayedMs: activePlayedMs,
              completed: completed,
            );
          }
          for (final window in windows) {
            if (timestamp >= window.cutoffMs) {
              window.statistics.addWatch(
                parts.videoKey,
                activePlayedMs: activePlayedMs,
                completed: completed,
              );
            }
          }
        }
      }

      final databaseSizes = await Future.wait<int?>([
        _boxFileSize(exposureBox),
        _boxFileSize(watchBox),
      ]);
      return RecommendHistoryStatistics(
        exposureDatabaseBytes: databaseSizes[0],
        watchDatabaseBytes: databaseSizes[1],
        exposureDatabaseEntryCount: exposureBox.length,
        watchDatabaseEntryCount: watchBox.length,
        scopeCount: scopes.length,
        recommendationCount: total.recommendationCount,
        recommendedVideoCount: total.recommendedVideos.length,
        watchCount: total.watchCount,
        watchedVideoCount: total.watchedVideos.length,
        completedWatchCount: total.completedWatchCount,
        activePlayedMs: total.activePlayedMs,
        recommendedUgcVideoCount: total.recommendedUgcVideos.length,
        recommendedPgcVideoCount: total.recommendedPgcVideos.length,
        watchedUgcVideoCount: total.watchedUgcVideos.length,
        watchedPgcVideoCount: total.watchedPgcVideos.length,
        currentScopeRecommendationCount: currentScope.recommendationCount,
        currentScopeRecommendedVideoCount:
            currentScope.recommendedVideos.length,
        currentScopeWatchCount: currentScope.watchCount,
        currentScopeWatchedVideoCount: currentScope.watchedVideos.length,
        oldestRecordAt: oldestTimestamp == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(oldestTimestamp!),
        newestRecordAt: newestTimestamp == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(newestTimestamp!),
        lastDay: lastDay.statistics.toWindowStatistics(),
        lastWeek: lastWeek.statistics.toWindowStatistics(),
        lastMonth: lastMonth.statistics.toWindowStatistics(),
      );
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

  static ({String scopeId, String videoKey})? _parseVideoDataKey(
    String key,
    String prefix,
  ) {
    final parts = key.split('|');
    if (parts.length != 4 || parts[0] != prefix) {
      return null;
    }
    try {
      return (
        scopeId: utf8.decode(base64Url.decode(base64Url.normalize(parts[2]))),
        videoKey: utf8.decode(base64Url.decode(base64Url.normalize(parts[3]))),
      );
    } on FormatException {
      return null;
    }
  }

  static Future<int?> _boxFileSize(Box<dynamic> box) async {
    final path = box.path;
    if (path == null) return null;
    try {
      return await File(path).length();
    } on FileSystemException {
      return null;
    }
  }
}

class _StatisticsWindow {
  final int cutoffMs;
  final _HistoryStatisticsAccumulator statistics =
      _HistoryStatisticsAccumulator();

  _StatisticsWindow(this.cutoffMs);
}

class _HistoryStatisticsAccumulator {
  int recommendationCount = 0;
  int watchCount = 0;
  int completedWatchCount = 0;
  int activePlayedMs = 0;
  final Set<String> recommendedVideos = {};
  final Set<String> watchedVideos = {};
  final Set<String> recommendedUgcVideos = {};
  final Set<String> recommendedPgcVideos = {};
  final Set<String> watchedUgcVideos = {};
  final Set<String> watchedPgcVideos = {};

  void addRecommendation(String videoKey) {
    recommendationCount++;
    recommendedVideos.add(videoKey);
    if (videoKey.startsWith('ugc:')) {
      recommendedUgcVideos.add(videoKey);
    } else if (videoKey.startsWith('pgc:')) {
      recommendedPgcVideos.add(videoKey);
    }
  }

  void addWatch(
    String videoKey, {
    required int activePlayedMs,
    required bool completed,
  }) {
    watchCount++;
    watchedVideos.add(videoKey);
    this.activePlayedMs += activePlayedMs;
    if (completed) completedWatchCount++;
    if (videoKey.startsWith('ugc:')) {
      watchedUgcVideos.add(videoKey);
    } else if (videoKey.startsWith('pgc:')) {
      watchedPgcVideos.add(videoKey);
    }
  }

  RecommendHistoryWindowStatistics toWindowStatistics() =>
      RecommendHistoryWindowStatistics(
        recommendationCount: recommendationCount,
        recommendedVideoCount: recommendedVideos.length,
        watchCount: watchCount,
        watchedVideoCount: watchedVideos.length,
        activePlayedMs: activePlayedMs,
      );
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
