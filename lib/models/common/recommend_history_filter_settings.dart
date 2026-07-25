import 'package:flutter/foundation.dart';

@immutable
class RecommendHistoryFilterSettings {
  static const int maxLookbackMinutes = 30 * 24 * 60;
  static const RecommendHistoryFilterSettings defaults =
      RecommendHistoryFilterSettings(
        enabled: false,
        lookbackMinutes: 7 * 24 * 60,
        exposureThreshold: 2,
        watchThreshold: 1,
        minWatchSeconds: 30,
      );

  final bool enabled;
  final int lookbackMinutes;
  final int exposureThreshold;
  final int watchThreshold;
  final int minWatchSeconds;

  const RecommendHistoryFilterSettings({
    required this.enabled,
    required this.lookbackMinutes,
    required this.exposureThreshold,
    required this.watchThreshold,
    required this.minWatchSeconds,
  });

  factory RecommendHistoryFilterSettings.fromStorage(Object? value) {
    if (value is! Map) {
      return defaults;
    }

    int readInt(String key, int fallback, int min, int max) {
      final raw = value[key];
      return (raw is num ? raw.toInt() : fallback).clamp(min, max).toInt();
    }

    return RecommendHistoryFilterSettings(
      enabled: value['enabled'] is bool
          ? value['enabled'] as bool
          : defaults.enabled,
      lookbackMinutes: readInt(
        'lookbackMinutes',
        defaults.lookbackMinutes,
        1,
        maxLookbackMinutes,
      ),
      exposureThreshold: readInt(
        'exposureThreshold',
        defaults.exposureThreshold,
        0,
        5,
      ),
      watchThreshold: readInt('watchThreshold', defaults.watchThreshold, 0, 5),
      minWatchSeconds: readInt(
        'minWatchSeconds',
        defaults.minWatchSeconds,
        0,
        300,
      ),
    );
  }

  Map<String, Object> toStorage() => {
    'enabled': enabled,
    'lookbackMinutes': lookbackMinutes,
    'exposureThreshold': exposureThreshold,
    'watchThreshold': watchThreshold,
    'minWatchSeconds': minWatchSeconds,
  };

  RecommendHistoryFilterSettings copyWith({
    bool? enabled,
    int? lookbackMinutes,
    int? exposureThreshold,
    int? watchThreshold,
    int? minWatchSeconds,
  }) => RecommendHistoryFilterSettings(
    enabled: enabled ?? this.enabled,
    lookbackMinutes: lookbackMinutes ?? this.lookbackMinutes,
    exposureThreshold: exposureThreshold ?? this.exposureThreshold,
    watchThreshold: watchThreshold ?? this.watchThreshold,
    minWatchSeconds: minWatchSeconds ?? this.minWatchSeconds,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecommendHistoryFilterSettings &&
          enabled == other.enabled &&
          lookbackMinutes == other.lookbackMinutes &&
          exposureThreshold == other.exposureThreshold &&
          watchThreshold == other.watchThreshold &&
          minWatchSeconds == other.minWatchSeconds;

  @override
  int get hashCode => Object.hash(
    enabled,
    lookbackMinutes,
    exposureThreshold,
    watchThreshold,
    minWatchSeconds,
  );
}
