import 'package:PiliPlus/utils/storage.dart';

abstract final class HomeCardLayoutPrefs {
  static const String horizontalSpacingKey =
          'recommendCardHorizontalSpacing',
      verticalSpacingKey = 'recommendCardVerticalSpacing',
      horizontalPaddingKey = 'recommendCardHorizontalPadding';

  static double _getClampedDouble(
    String key,
    double defaultValue,
    double min,
    double max,
  ) {
    final value = GStorage.setting.get(key, defaultValue: defaultValue);
    return (value is num ? value.toDouble() : defaultValue)
        .clamp(min, max)
        .toDouble();
  }

  static double get horizontalSpacing =>
      _getClampedDouble(horizontalSpacingKey, 8.0, 0.0, 32.0);

  static double get verticalSpacing =>
      _getClampedDouble(verticalSpacingKey, 8.0, 0.0, 32.0);

  static double get horizontalPadding =>
      _getClampedDouble(horizontalPaddingKey, 12.0, 0.0, 48.0);
}
