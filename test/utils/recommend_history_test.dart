import 'dart:io';

import 'package:PiliPlus/models/common/recommend_history_filter_settings.dart';
import 'package:PiliPlus/utils/recommend_history.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  group('RecommendHistoryFilterSettings', () {
    test('uses defaults and clamps persisted values', () {
      expect(
        RecommendHistoryFilterSettings.fromStorage(null),
        RecommendHistoryFilterSettings.defaults,
      );

      final value = RecommendHistoryFilterSettings.fromStorage(const {
        'enabled': true,
        'lookbackMinutes': 999999,
        'exposureThreshold': 0,
        'watchThreshold': 9,
        'minWatchSeconds': -1,
      });
      expect(value.enabled, isTrue);
      expect(
        value.lookbackMinutes,
        RecommendHistoryFilterSettings.maxLookbackMinutes,
      );
      expect(value.exposureThreshold, 0);
      expect(value.watchThreshold, 5);
      expect(value.minWatchSeconds, 0);
    });
  });

  group('RecommendHistoryRepository', () {
    late Directory tempDirectory;
    late Box<dynamic> exposureBox;
    late Box<dynamic> watchBox;
    late RecommendHistoryRepository repository;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        'piliplus-recommend-history-',
      );
      Hive.init(tempDirectory.path);
      final suffix = DateTime.now().microsecondsSinceEpoch;
      exposureBox = await Hive.openBox<dynamic>('exposure-$suffix');
      watchBox = await Hive.openBox<dynamic>('watch-$suffix');
      repository = RecommendHistoryRepository(
        exposureBox: exposureBox,
        watchBox: watchBox,
      );
    });

    tearDown(() async {
      await Hive.close();
      await tempDirectory.delete(recursive: true);
    });

    test(
      'deduplicates one card occurrence but counts separate responses',
      () async {
        final now = DateTime(2026, 7, 25, 12);
        await repository.recordExposure(
          scopeId: 'uid:1',
          occurrenceId: 'response-a:0:ugc:1',
          videoKey: 'ugc:1',
          exposedAt: now.subtract(const Duration(minutes: 10)),
        );
        await repository.recordExposure(
          scopeId: 'uid:1',
          occurrenceId: 'response-a:0:ugc:1',
          videoKey: 'ugc:1',
          exposedAt: now.subtract(const Duration(minutes: 5)),
        );

        var blocked = await repository.findBlockedVideos(
          scopeId: 'uid:1',
          candidateVideoKeys: {'ugc:1'},
          settings: _settings(exposureThreshold: 2),
          now: now,
        );
        expect(blocked, isEmpty);

        await repository.recordExposure(
          scopeId: 'uid:1',
          occurrenceId: 'response-b:0:ugc:1',
          videoKey: 'ugc:1',
          exposedAt: now,
        );
        blocked = await repository.findBlockedVideos(
          scopeId: 'uid:1',
          candidateVideoKeys: {'ugc:1'},
          settings: _settings(exposureThreshold: 2),
          now: now,
        );
        expect(blocked, {'ugc:1'});
      },
    );

    test('includes an event exactly on the lookback boundary', () async {
      final now = DateTime(2026, 7, 25, 12);
      await repository.recordExposure(
        scopeId: 'uid:1',
        occurrenceId: 'boundary',
        videoKey: 'ugc:2',
        exposedAt: now.subtract(const Duration(minutes: 60)),
      );
      final blocked = await repository.findBlockedVideos(
        scopeId: 'uid:1',
        candidateVideoKeys: {'ugc:2'},
        settings: _settings(lookbackMinutes: 60, exposureThreshold: 1),
        now: now,
      );
      expect(blocked, {'ugc:2'});
    });

    test(
      're-evaluates stored sessions with a changed watch threshold',
      () async {
        final now = DateTime(2026, 7, 25, 12);
        await repository.createPlaySession(
          scopeId: 'uid:1',
          sessionId: 'session-1',
          videoKey: 'ugc:3',
          firstFrameAt: now.subtract(const Duration(minutes: 5)),
        );
        await repository.updatePlaySession(
          sessionId: 'session-1',
          activePlayedMs: 12000,
          ended: true,
          updatedAt: now,
        );

        var blocked = await repository.findBlockedVideos(
          scopeId: 'uid:1',
          candidateVideoKeys: {'ugc:3'},
          settings: _settings(minWatchSeconds: 30),
          now: now,
        );
        expect(blocked, isEmpty);

        blocked = await repository.findBlockedVideos(
          scopeId: 'uid:1',
          candidateVideoKeys: {'ugc:3'},
          settings: _settings(minWatchSeconds: 10),
          now: now,
        );
        expect(blocked, {'ugc:3'});
      },
    );

    test('zero disables each history metric independently', () async {
      final now = DateTime(2026, 7, 25, 12);
      await repository.recordExposure(
        scopeId: 'uid:1',
        occurrenceId: 'response-a:0:ugc:5',
        videoKey: 'ugc:5',
        exposedAt: now,
      );
      await repository.createPlaySession(
        scopeId: 'uid:1',
        sessionId: 'session-2',
        videoKey: 'ugc:5',
        firstFrameAt: now,
      );
      await repository.updatePlaySession(
        sessionId: 'session-2',
        activePlayedMs: 300000,
        ended: true,
        updatedAt: now,
      );

      var blocked = await repository.findBlockedVideos(
        scopeId: 'uid:1',
        candidateVideoKeys: {'ugc:5'},
        settings: _settings(exposureThreshold: 0, watchThreshold: 0),
        now: now,
      );
      expect(blocked, isEmpty);

      blocked = await repository.findBlockedVideos(
        scopeId: 'uid:1',
        candidateVideoKeys: {'ugc:5'},
        settings: _settings(exposureThreshold: 0, watchThreshold: 1),
        now: now,
      );
      expect(blocked, {'ugc:5'});

      blocked = await repository.findBlockedVideos(
        scopeId: 'uid:1',
        candidateVideoKeys: {'ugc:5'},
        settings: _settings(exposureThreshold: 1, watchThreshold: 0),
        now: now,
      );
      expect(blocked, {'ugc:5'});
    });

    test(
      'daily cleanup removes expired data without touching current data',
      () async {
        final now = DateTime(2026, 7, 25, 12);
        await repository.recordExposure(
          scopeId: 'uid:1',
          occurrenceId: 'expired',
          videoKey: 'ugc:4',
          exposedAt: now.subtract(const Duration(days: 31)),
        );
        await repository.recordExposure(
          scopeId: 'uid:1',
          occurrenceId: 'current',
          videoKey: 'ugc:4',
          exposedAt: now,
        );

        final maps = exposureBox.values.whereType<Map>();
        expect(maps.any((map) => map.containsKey('expired')), isFalse);
        expect(maps.any((map) => map.containsKey('current')), isTrue);
      },
    );
  });
}

RecommendHistoryFilterSettings _settings({
  int lookbackMinutes = 60,
  int exposureThreshold = 5,
  int watchThreshold = 1,
  int minWatchSeconds = 30,
}) => RecommendHistoryFilterSettings(
  enabled: true,
  lookbackMinutes: lookbackMinutes,
  exposureThreshold: exposureThreshold,
  watchThreshold: watchThreshold,
  minWatchSeconds: minWatchSeconds,
);
