import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/models/common/theme/theme_color_type.dart';
import 'package:PiliPlus/utils/extension/theme_ext.dart';
import 'package:PiliPlus/utils/local_font_manager.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/cupertino.dart' show CupertinoThemeData;
import 'package:flutter/foundation.dart' show PlatformDispatcher;
import 'package:flutter/material.dart';

abstract final class ThemeUtils {
  static late ThemeData lightTheme;

  static late ThemeData darkTheme;

  static late ThemeMode themeMode;

  static ThemeData get theme {
    if (themeMode == .dark ||
        (themeMode == .system &&
            PlatformDispatcher.instance.platformBrightness == .dark)) {
      return darkTheme;
    }
    return lightTheme;
  }

  static bool get isDarkMode => theme.isDark;

  static String themeUrl(bool isDark) =>
      'native.theme=${isDark ? 2 : 1}&night=${isDark ? 1 : 0}';

  static ThemeData getThemeData({
    required ColorScheme colorScheme,
    required bool isDynamic,
    bool isDark = false,
  }) {
    Style.updateCardRadius(Pref.cardRadius);
    final appFontWeight = Pref.appFontWeight.clamp(
      -1,
      FontWeight.values.length - 1,
    );
    final fontWeight = appFontWeight == -1
        ? null
        : FontWeight.values[appFontWeight];
    final fontFamilies = LocalFontManager.appFontFamilies;
    final fontFamilyFallback = fontFamilies.fallback.isEmpty
        ? null
        : fontFamilies.fallback;
    final hasCustomTextStyle =
        fontWeight != null || fontFamilies.primary != null;
    final textStyle = TextStyle(
      fontWeight: fontWeight,
      fontFamily: fontFamilies.primary,
      fontFamilyFallback: fontFamilyFallback,
    );
    final assignments = Pref.themeColorMode == ThemeColorMode.customMultiSeed
        ? Pref.customThemeUiColorAssignments
        : {
            for (final element in ThemeUiElement.values)
              element: element.defaultColor,
          };
    final uiColors = ThemeUiColors.fromScheme(colorScheme, assignments);
    Color ui(ThemeUiElement element) => uiColors[element];
    ThemeData themeData = ThemeData(
      highlightColor: colorScheme.onSurface.withValues(alpha: 0.04),
      colorScheme: colorScheme,
      extensions: [uiColors],
      useMaterial3: true,
      splashFactory: NoSplash.splashFactory,
      fontFamily: fontFamilies.primary,
      scaffoldBackgroundColor: ui(ThemeUiElement.pageBackground),
      textTheme: !hasCustomTextStyle
          ? null
          : TextTheme(
              displayLarge: textStyle,
              displayMedium: textStyle,
              displaySmall: textStyle,
              headlineLarge: textStyle,
              headlineMedium: textStyle,
              headlineSmall: textStyle,
              titleLarge: textStyle,
              titleMedium: textStyle,
              titleSmall: textStyle,
              bodyLarge: textStyle,
              bodyMedium: textStyle,
              bodySmall: textStyle,
              labelLarge: textStyle,
              labelMedium: textStyle,
              labelSmall: textStyle,
            ),
      tabBarTheme: TabBarThemeData(
        labelColor: ui(ThemeUiElement.tabSelectedContent),
        unselectedLabelColor: ui(ThemeUiElement.tabUnselectedContent),
        indicatorColor: ui(ThemeUiElement.tabIndicator),
        dividerColor: ui(ThemeUiElement.tabDivider),
        labelStyle: hasCustomTextStyle ? textStyle : null,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        titleSpacing: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: ui(ThemeUiElement.appBarBackground),
        foregroundColor: ui(ThemeUiElement.appBarContent),
        titleTextStyle: TextStyle(
          fontSize: 16,
          color: ui(ThemeUiElement.appBarContent),
          fontWeight: fontWeight,
          fontFamily: fontFamilies.primary,
          fontFamilyFallback: fontFamilyFallback,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: ui(ThemeUiElement.navigationBarBackground),
        indicatorColor: ui(ThemeUiElement.navigationSelectedIndicator),
        surfaceTintColor: isDynamic ? colorScheme.onSurfaceVariant : null,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final color = states.contains(WidgetState.selected)
              ? ui(ThemeUiElement.navigationSelectedContent)
              : ui(ThemeUiElement.navigationUnselectedContent);
          return IconThemeData(color: color);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final color = states.contains(WidgetState.selected)
              ? ui(ThemeUiElement.navigationSelectedContent)
              : ui(ThemeUiElement.navigationUnselectedContent);
          return textStyle.copyWith(color: color);
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        actionTextColor: ui(ThemeUiElement.snackbarAction),
        backgroundColor: ui(ThemeUiElement.snackbarBackground),
        closeIconColor: ui(ThemeUiElement.snackbarClose),
        contentTextStyle: TextStyle(
          color: ui(ThemeUiElement.snackbarContent),
          fontFamily: fontFamilies.primary,
          fontFamilyFallback: fontFamilyFallback,
        ),
        elevation: 20,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: ui(ThemeUiElement.popupMenuBackground),
        surfaceTintColor: isDynamic ? colorScheme.onSurfaceVariant : null,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        color: ui(ThemeUiElement.cardBackground),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: Style.cardRadius),
        surfaceTintColor: isDynamic
            ? colorScheme.onSurfaceVariant
            : isDark
            ? colorScheme.onSurfaceVariant
            : null,
        shadowColor: Colors.transparent,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        // ignore: deprecated_member_use
        year2023: false,
        color: ui(ThemeUiElement.progressIndicator),
        linearTrackColor: ui(ThemeUiElement.progressTrack),
        circularTrackColor: ui(ThemeUiElement.progressTrack),
        refreshBackgroundColor: ui(
          ThemeUiElement.refreshIndicatorBackground,
        ),
      ),
      dialogTheme: DialogThemeData(
        titleTextStyle: TextStyle(
          fontSize: 18,
          color: ui(ThemeUiElement.dialogTitle),
          fontWeight: fontWeight,
          fontFamily: fontFamilies.primary,
          fontFamilyFallback: fontFamilyFallback,
        ),
        backgroundColor: ui(ThemeUiElement.dialogBackground),
        constraints: const BoxConstraints(minWidth: 280, maxWidth: 420),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: ui(ThemeUiElement.bottomSheetBackground),
        shape: const RoundedRectangleBorder(
          borderRadius: Style.bottomSheetRadius,
        ),
      ),
      // ignore: deprecated_member_use
      sliderTheme: SliderThemeData(
        // ignore: deprecated_member_use
        year2023: false,
        activeTrackColor: ui(ThemeUiElement.sliderActiveTrack),
        inactiveTrackColor: ui(ThemeUiElement.sliderInactiveTrack),
        thumbColor: ui(ThemeUiElement.sliderThumb),
      ),
      tooltipTheme: TooltipThemeData(
        textStyle: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontFamily: fontFamilies.primary,
          fontFamilyFallback: fontFamilyFallback,
        ),
        decoration: BoxDecoration(
          color: Colors.grey[700]!.withValues(alpha: 0.9),
          borderRadius: const BorderRadius.all(Radius.circular(4)),
        ),
      ),
      cupertinoOverrideTheme: CupertinoThemeData(
        selectionHandleColor: ui(ThemeUiElement.textSelectionHandle),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: ui(ThemeUiElement.textCursor),
        selectionColor: ui(ThemeUiElement.textSelection),
        selectionHandleColor: ui(ThemeUiElement.textSelectionHandle),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        errorStyle: TextStyle(color: ui(ThemeUiElement.inputErrorText)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.disabled)
                ? null
                : ui(ThemeUiElement.textButtonContent);
          }),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.disabled)
                ? null
                : ui(ThemeUiElement.elevatedButtonBackground);
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.disabled)
                ? null
                : ui(ThemeUiElement.elevatedButtonContent);
          }),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.disabled)
                ? null
                : ui(ThemeUiElement.outlinedButtonContent);
          }),
          side: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.disabled)
                ? null
                : BorderSide(
                    color: ui(ThemeUiElement.outlinedButtonBorder),
                  );
          }),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: ui(ThemeUiElement.defaultFabBackground),
        foregroundColor: ui(ThemeUiElement.defaultFabContent),
      ),
      switchTheme: SwitchThemeData(
        padding: .zero,
        materialTapTargetSize: .shrinkWrap,
        trackColor: WidgetStateProperty.resolveWith((states) {
          return !states.contains(WidgetState.disabled) &&
                  states.contains(WidgetState.selected)
              ? ui(ThemeUiElement.switchSelectedTrack)
              : null;
        }),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return !states.contains(WidgetState.disabled) &&
                  states.contains(WidgetState.selected)
              ? ui(ThemeUiElement.switchSelectedThumb)
              : null;
        }),
        thumbIcon: const WidgetStateProperty<Icon?>.fromMap(
          <WidgetStatesConstraint, Icon?>{
            WidgetState.selected: Icon(Icons.done),
            WidgetState.any: null,
          },
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          return !states.contains(WidgetState.disabled) &&
                  states.contains(WidgetState.selected)
              ? ui(ThemeUiElement.checkboxSelectedFill)
              : null;
        }),
        checkColor: WidgetStateProperty.resolveWith((states) {
          return !states.contains(WidgetState.disabled) &&
                  states.contains(WidgetState.selected)
              ? ui(ThemeUiElement.checkboxCheck)
              : null;
        }),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          return !states.contains(WidgetState.disabled) &&
                  states.contains(WidgetState.selected)
              ? ui(ThemeUiElement.radioSelected)
              : null;
        }),
      ),
      listTileTheme: ListTileThemeData(
        selectedColor: ui(ThemeUiElement.listTileSelectedContent),
        iconColor: ui(ThemeUiElement.listTileIcon),
      ),
      dividerTheme: DividerThemeData(color: ui(ThemeUiElement.divider)),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
        },
      ),
    );
    if (isDark) {
      if (Pref.isPureBlackTheme) {
        themeData = darkenTheme(themeData);
      }
    }
    return themeData;
  }

  static ThemeData darkenTheme(ThemeData themeData) {
    final colorScheme = themeData.colorScheme;
    final color = colorScheme.surfaceContainerHighest.darken(0.7);
    return themeData.copyWith(
      scaffoldBackgroundColor: Colors.black,
      appBarTheme: themeData.appBarTheme.copyWith(
        backgroundColor: Colors.black,
      ),
      cardTheme: themeData.cardTheme.copyWith(
        color: Colors.black,
      ),
      dialogTheme: themeData.dialogTheme.copyWith(
        backgroundColor: color,
      ),
      bottomSheetTheme: themeData.bottomSheetTheme.copyWith(
        backgroundColor: color,
      ),
      bottomNavigationBarTheme: themeData.bottomNavigationBarTheme.copyWith(
        backgroundColor: color,
      ),
      navigationBarTheme: themeData.navigationBarTheme.copyWith(
        backgroundColor: color,
      ),
      navigationRailTheme: themeData.navigationRailTheme.copyWith(
        backgroundColor: Colors.black,
      ),
      colorScheme: colorScheme.copyWith(
        primary: colorScheme.primary.darken(0.1),
        onPrimary: colorScheme.onPrimary.darken(0.1),
        primaryContainer: colorScheme.primaryContainer.darken(0.1),
        onPrimaryContainer: colorScheme.onPrimaryContainer.darken(0.1),
        inversePrimary: colorScheme.inversePrimary.darken(0.1),
        secondary: colorScheme.secondary.darken(0.1),
        onSecondary: colorScheme.onSecondary.darken(0.1),
        secondaryContainer: colorScheme.secondaryContainer.darken(0.1),
        onSecondaryContainer: colorScheme.onSecondaryContainer.darken(0.1),
        error: colorScheme.error.darken(0.1),
        surface: Colors.black,
        onSurface: colorScheme.onSurface.darken(0.15),
        surfaceTint: colorScheme.surfaceTint.darken(),
        inverseSurface: colorScheme.inverseSurface.darken(),
        onInverseSurface: colorScheme.onInverseSurface.darken(),
        surfaceContainer: colorScheme.surfaceContainer.darken(),
        surfaceContainerHigh: colorScheme.surfaceContainerHigh.darken(),
        surfaceContainerHighest: colorScheme.surfaceContainerHighest.darken(
          0.4,
        ),
      ),
    );
  }
}
