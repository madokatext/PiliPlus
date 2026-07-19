import 'package:PiliPlus/utils/storage.dart';

abstract final class HorizontalSeekGesturePrefs {
  static const String angleKey = 'horizontalSeekGestureAngleThreshold';
  static const String triggerDistanceKey = 'horizontalSeekGestureThreshold';
  static const double defaultAngle = 45.0;
  static const double minAngle = 5.0;
  static const double maxAngle = 60.0;

  static double get angle {
    final value = GStorage.setting.get(angleKey, defaultValue: defaultAngle);
    return (value is num ? value.toDouble() : defaultAngle)
        .clamp(minAngle, maxAngle)
        .toDouble();
  }

  static double get triggerDistance {
    final value = GStorage.setting.get(
      triggerDistanceKey,
      defaultValue: 1.0,
    );
    return (value is num ? value.toDouble() : 1.0)
        .clamp(1.0, 100.0)
        .toDouble();
  }

  static Future<void> setAngle(double value) => GStorage.setting.put(
    angleKey,
    value.clamp(minAngle, maxAngle).toDouble(),
  );
}
