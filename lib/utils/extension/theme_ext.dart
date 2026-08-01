import 'package:PiliPlus/models/common/theme/theme_color_type.dart';
import 'package:PiliPlus/utils/bili_colors.dart';
import 'package:flex_seed_scheme/flex_seed_scheme.dart';
import 'package:flutter/material.dart'
    show ThemeData, ThemeExtension, Color, ColorScheme, Brightness, Colors;
import 'package:material_color_utilities/hct/hct.dart' as mcu;

extension ThemeDataExt on ThemeData {
  bool get isLight => brightness.isLight;

  bool get isDark => brightness.isDark;

  Color uiColor(ThemeUiElement element) =>
      extension<ThemeUiColors>()?[element] ??
      colorScheme.colorFor(element.defaultColor);
}

class ThemeUiColors extends ThemeExtension<ThemeUiColors> {
  ThemeUiColors(Map<ThemeUiElement, Color> colors)
    : colors = Map.unmodifiable(colors);

  factory ThemeUiColors.fromScheme(
    ColorScheme colorScheme,
    Map<ThemeUiElement, ThemeSchemeColor?> assignments,
  ) => ThemeUiColors({
    for (final element in ThemeUiElement.values)
      element: colorScheme.colorFor(
        assignments[element] ?? element.defaultColor,
      ),
  });

  final Map<ThemeUiElement, Color> colors;

  Color operator [](ThemeUiElement element) => colors[element]!;

  @override
  ThemeUiColors copyWith({Map<ThemeUiElement, Color>? colors}) =>
      ThemeUiColors(colors ?? this.colors);

  @override
  ThemeUiColors lerp(covariant ThemeUiColors? other, double t) {
    if (other == null) return this;
    return ThemeUiColors({
      for (final element in ThemeUiElement.values)
        element: Color.lerp(colors[element], other.colors[element], t)!,
    });
  }
}

extension ColorSchemeExt on ColorScheme {
  Color get vipColor =>
      brightness.isLight ? BiliColors.pinkLight : BiliColors.pinkDark;

  Color get blue =>
      brightness.isLight ? BiliColors.blueLight : BiliColors.blueDark;

  Color get btnColor =>
      brightness.isLight ? BiliColors.pinkLight : const Color(0xFF8F0030);

  Color get freeColor =>
      brightness.isLight ? const Color(0xFFFF7F24) : const Color(0xFFD66011);

  bool get isLight => brightness.isLight;

  bool get isDark => brightness.isDark;
}

extension ColorExtension on Color {
  Color darken([double amount = .5]) {
    assert(amount >= 0 && amount <= 1, 'Amount must be between 0 and 1');
    return Color.lerp(this, Colors.black, amount)!;
  }

  ColorScheme asColorSchemeSeed([
    FlexSchemeVariant variant = .material,
    Brightness brightness = .light,
  ]) => SeedColorScheme.fromSeeds(
    primaryKey: this,
    variant: variant,
    brightness: brightness,
    useExpressiveOnContainerColors: false,
  );

  /// HCT 生成只读取 RGB；先叠到明/暗基底，让种子色的 A 通道可见且结果仍为不透明色表。
  Color opaqueSeed(Brightness brightness) => Color.alphaBlend(
    this,
    brightness.isLight ? Colors.white : Colors.black,
  );
}

extension ThemeSeedColorsExt on ThemeSeedColors {
  ColorScheme asColorSchemeSeeds(
    FlexSchemeVariant variant,
    Brightness brightness,
  ) => SeedColorScheme.fromSeeds(
    primaryKey: primary.opaqueSeed(brightness),
    secondaryKey: secondary.opaqueSeed(brightness),
    tertiaryKey: tertiary.opaqueSeed(brightness),
    variant: variant,
    brightness: brightness,
    respectMonochromeSeed: true,
    useExpressiveOnContainerColors: false,
  );
}

extension ThemeToneExt on ColorScheme {
  ColorScheme applyToneOffsets(Map<ThemeToneRole, double> offsets) {
    Color tone(Color color, ThemeToneRole role) {
      final offset = offsets[role] ?? 0;
      if (offset == 0) return color;
      final hct = mcu.Hct.fromInt(color.toARGB32());
      hct.tone = (hct.tone + offset).clamp(0.0, 100.0).toDouble();
      return Color(hct.toInt());
    }

    return copyWith(
      // 直接强调色。Switch 选中轨道等组件通常使用 primary。
      primary: tone(primary, ThemeToneRole.primaryAccent),
      onPrimary: tone(onPrimary, ThemeToneRole.primaryAccentContent),
      inversePrimary: tone(inversePrimary, ThemeToneRole.primaryAccent),
      primaryFixed: tone(primaryFixed, ThemeToneRole.primaryAccent),
      primaryFixedDim: tone(primaryFixedDim, ThemeToneRole.primaryAccent),
      onPrimaryFixed: tone(
        onPrimaryFixed,
        ThemeToneRole.primaryAccentContent,
      ),
      onPrimaryFixedVariant: tone(
        onPrimaryFixedVariant,
        ThemeToneRole.primaryAccentContent,
      ),
      // “我的”页快捷入口等当前使用 secondary。
      secondary: tone(secondary, ThemeToneRole.secondaryAccent),
      onSecondary: tone(onSecondary, ThemeToneRole.secondaryAccentContent),
      secondaryFixed: tone(secondaryFixed, ThemeToneRole.secondaryAccent),
      secondaryFixedDim: tone(
        secondaryFixedDim,
        ThemeToneRole.secondaryAccent,
      ),
      onSecondaryFixed: tone(
        onSecondaryFixed,
        ThemeToneRole.secondaryAccentContent,
      ),
      onSecondaryFixedVariant: tone(
        onSecondaryFixedVariant,
        ThemeToneRole.secondaryAccentContent,
      ),
      tertiary: tone(tertiary, ThemeToneRole.tertiaryAccent),
      onTertiary: tone(onTertiary, ThemeToneRole.tertiaryAccentContent),
      tertiaryFixed: tone(tertiaryFixed, ThemeToneRole.tertiaryAccent),
      tertiaryFixedDim: tone(
        tertiaryFixedDim,
        ThemeToneRole.tertiaryAccent,
      ),
      onTertiaryFixed: tone(
        onTertiaryFixed,
        ThemeToneRole.tertiaryAccentContent,
      ),
      onTertiaryFixedVariant: tone(
        onTertiaryFixedVariant,
        ThemeToneRole.tertiaryAccentContent,
      ),
      // surfaceTint 也是由 primary 派生的直接强调色。
      surfaceTint: tone(surfaceTint, ThemeToneRole.primaryAccent),
      surface: tone(surface, ThemeToneRole.page),
      surfaceDim: tone(surfaceDim, ThemeToneRole.page),
      surfaceBright: tone(surfaceBright, ThemeToneRole.page),
      // PiliPlus 现有代码大量把 onInverseSurface 当作卡片底色使用。
      onInverseSurface: tone(onInverseSurface, ThemeToneRole.card),
      surfaceContainerLowest: tone(
        surfaceContainerLowest,
        ThemeToneRole.card,
      ),
      surfaceContainerLow: tone(surfaceContainerLow, ThemeToneRole.card),
      surfaceContainer: tone(surfaceContainer, ThemeToneRole.elevated),
      surfaceContainerHigh: tone(surfaceContainerHigh, ThemeToneRole.elevated),
      surfaceContainerHighest: tone(
        surfaceContainerHighest,
        ThemeToneRole.elevated,
      ),
      primaryContainer: tone(primaryContainer, ThemeToneRole.selected),
      secondaryContainer: tone(secondaryContainer, ThemeToneRole.selected),
      tertiaryContainer: tone(tertiaryContainer, ThemeToneRole.selected),
      onSurface: tone(onSurface, ThemeToneRole.content),
      onPrimaryContainer: tone(
        onPrimaryContainer,
        ThemeToneRole.selectedContent,
      ),
      onSecondaryContainer: tone(
        onSecondaryContainer,
        ThemeToneRole.selectedContent,
      ),
      onTertiaryContainer: tone(
        onTertiaryContainer,
        ThemeToneRole.selectedContent,
      ),
      onSurfaceVariant: tone(onSurfaceVariant, ThemeToneRole.mutedContent),
      outline: tone(outline, ThemeToneRole.mutedContent),
      outlineVariant: tone(outlineVariant, ThemeToneRole.border),
    );
  }
}

extension ThemeColorAssignmentExt on ColorScheme {
  Color colorFor(ThemeSchemeColor color) => switch (color) {
    ThemeSchemeColor.primary => primary,
    ThemeSchemeColor.onPrimary => onPrimary,
    ThemeSchemeColor.primaryContainer => primaryContainer,
    ThemeSchemeColor.onPrimaryContainer => onPrimaryContainer,
    ThemeSchemeColor.primaryFixed => primaryFixed,
    ThemeSchemeColor.primaryFixedDim => primaryFixedDim,
    ThemeSchemeColor.onPrimaryFixed => onPrimaryFixed,
    ThemeSchemeColor.onPrimaryFixedVariant => onPrimaryFixedVariant,
    ThemeSchemeColor.inversePrimary => inversePrimary,
    ThemeSchemeColor.secondary => secondary,
    ThemeSchemeColor.onSecondary => onSecondary,
    ThemeSchemeColor.secondaryContainer => secondaryContainer,
    ThemeSchemeColor.onSecondaryContainer => onSecondaryContainer,
    ThemeSchemeColor.secondaryFixed => secondaryFixed,
    ThemeSchemeColor.secondaryFixedDim => secondaryFixedDim,
    ThemeSchemeColor.onSecondaryFixed => onSecondaryFixed,
    ThemeSchemeColor.onSecondaryFixedVariant => onSecondaryFixedVariant,
    ThemeSchemeColor.tertiary => tertiary,
    ThemeSchemeColor.onTertiary => onTertiary,
    ThemeSchemeColor.tertiaryContainer => tertiaryContainer,
    ThemeSchemeColor.onTertiaryContainer => onTertiaryContainer,
    ThemeSchemeColor.tertiaryFixed => tertiaryFixed,
    ThemeSchemeColor.tertiaryFixedDim => tertiaryFixedDim,
    ThemeSchemeColor.onTertiaryFixed => onTertiaryFixed,
    ThemeSchemeColor.onTertiaryFixedVariant => onTertiaryFixedVariant,
    ThemeSchemeColor.error => error,
    ThemeSchemeColor.onError => onError,
    ThemeSchemeColor.errorContainer => errorContainer,
    ThemeSchemeColor.onErrorContainer => onErrorContainer,
    ThemeSchemeColor.surface => surface,
    ThemeSchemeColor.onSurface => onSurface,
    ThemeSchemeColor.surfaceDim => surfaceDim,
    ThemeSchemeColor.surfaceBright => surfaceBright,
    ThemeSchemeColor.surfaceContainerLowest => surfaceContainerLowest,
    ThemeSchemeColor.surfaceContainerLow => surfaceContainerLow,
    ThemeSchemeColor.surfaceContainer => surfaceContainer,
    ThemeSchemeColor.surfaceContainerHigh => surfaceContainerHigh,
    ThemeSchemeColor.surfaceContainerHighest => surfaceContainerHighest,
    ThemeSchemeColor.onSurfaceVariant => onSurfaceVariant,
    ThemeSchemeColor.outline => outline,
    ThemeSchemeColor.outlineVariant => outlineVariant,
    ThemeSchemeColor.shadow => shadow,
    ThemeSchemeColor.scrim => scrim,
    ThemeSchemeColor.inverseSurface => inverseSurface,
    ThemeSchemeColor.onInverseSurface => onInverseSurface,
    ThemeSchemeColor.surfaceTint => surfaceTint,
  };
}

extension BrightnessExt on Brightness {
  Brightness get reverse => isLight ? Brightness.dark : Brightness.light;

  bool get isLight => this == Brightness.light;

  bool get isDark => this == Brightness.dark;
}
