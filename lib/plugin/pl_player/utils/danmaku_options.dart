import 'package:PiliPlus/utils/extension/box_ext.dart';
import 'package:PiliPlus/utils/local_font_manager.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:PiliPlus/models/common/danmaku_merge_mode.dart';

abstract final class DanmakuOptions {
  static final Set<int> blockTypes = Pref.danmakuBlockType;
  static bool blockColorful = blockTypes.contains(6);

  static int danmakuWeight = Pref.danmakuWeight;
  static DanmakuMergeMode mergeMode = Pref.danmakuMergeMode;

static int burstDanmakuTriggerCount =
    Pref.burstDanmakuTriggerCount;

static double burstDanmakuWindowSeconds =
    Pref.burstDanmakuWindowSeconds;

static double burstDanmakuCooldownSeconds =
    Pref.burstDanmakuCooldownSeconds;

static double burstDanmakuFontScale =
    Pref.burstDanmakuFontScale;
  static int highLikeDanmakuThreshold = Pref.highLikeDanmakuThreshold;
  static double danmakuFontScaleFS = Pref.danmakuFontScaleFS;
  static double danmakuFontScale = Pref.danmakuFontScale;
  static int danmakuFontWeight = Pref.danmakuFontWeight;
  static double danmakuShowArea = Pref.danmakuShowArea;
  static double danmakuDuration = Pref.danmakuDuration;
  static double danmakuStaticDuration = Pref.danmakuStaticDuration;
  static double danmakuStrokeWidth = Pref.danmakuStrokeWidth;
  static double danmakuShadowRadius = Pref.danmakuShadowRadius;
  static bool danmakuFixedV = Pref.danmakuFixedV;
  static bool danmakuStatic2Scroll = Pref.danmakuStatic2Scroll;
  static bool danmakuMassiveMode = Pref.danmakuMassiveMode;
  static bool liveDanmakuMassiveMode = Pref.liveDanmakuMassiveMode;
  static double danmakuLineHeight = Pref.danmakuLineHeight;

  static bool get sameFontScale => danmakuFontScale == danmakuFontScaleFS;

  static DanmakuOption get({
    required bool notFullscreen,
    bool isLive = false,
    double speed = 1.0,
  }) {
    final fontFamilies = LocalFontManager.danmakuFontFamilies;
    return DanmakuOption(
      fontSize: 15 * (notFullscreen ? danmakuFontScale : danmakuFontScaleFS),
      fontWeight: danmakuFontWeight,
      fontFamily: fontFamilies.primary ?? '',
      fontFamilyFallback: fontFamilies.fallback,
      area: danmakuShowArea,
      duration: danmakuDuration / speed,
      staticDuration: danmakuStaticDuration / speed,
      hideBottom: blockTypes.contains(4),
      hideScroll: blockTypes.contains(2),
      hideTop: blockTypes.contains(5),
      hideSpecial: blockTypes.contains(7),
      strokeWidth: danmakuStrokeWidth,
      shadowRadius: danmakuShadowRadius,
      scrollFixedVelocity: danmakuFixedV,
      massiveMode: isLive ? liveDanmakuMassiveMode : danmakuMassiveMode,
      static2Scroll: danmakuStatic2Scroll,
      safeArea: true,
      lineHeight: danmakuLineHeight,
    );
  }
static Future<void> saveMergeSettings() async {
  final future = GStorage.setting.putAllNE({
    SettingBoxKey.danmakuMergeMode: mergeMode.index,

    // 同步旧键，保证降级到旧版本时行为尽可能合理。
    SettingBoxKey.mergeDanmaku:
        mergeMode == DanmakuMergeMode.segment,

    SettingBoxKey.burstDanmakuTriggerCount:
        burstDanmakuTriggerCount,
    SettingBoxKey.burstDanmakuWindowSeconds:
        burstDanmakuWindowSeconds,
    SettingBoxKey.burstDanmakuCooldownSeconds:
        burstDanmakuCooldownSeconds,
    SettingBoxKey.burstDanmakuFontScale:
        burstDanmakuFontScale,
  });

  if (future != null) {
    await future;
  }
}
  static Future<void>? save(double danmakuOpacity) {
    return GStorage.setting.putAllNE({
      SettingBoxKey.danmakuBlockType: blockTypes.toList(),
      SettingBoxKey.danmakuShowArea: danmakuShowArea,
      SettingBoxKey.danmakuFontScale: danmakuFontScale,
      SettingBoxKey.danmakuFontScaleFS: danmakuFontScaleFS,
      SettingBoxKey.danmakuDuration: danmakuDuration,
      SettingBoxKey.danmakuStaticDuration: danmakuStaticDuration,
      SettingBoxKey.danmakuStrokeWidth: danmakuStrokeWidth,
      SettingBoxKey.danmakuShadowRadius: danmakuShadowRadius,
      SettingBoxKey.danmakuFontWeight: danmakuFontWeight,
      SettingBoxKey.danmakuLineHeight: danmakuLineHeight,
      SettingBoxKey.danmakuMassiveMode: danmakuMassiveMode,
      SettingBoxKey.liveDanmakuMassiveMode: liveDanmakuMassiveMode,
      SettingBoxKey.danmakuStatic2Scroll: danmakuStatic2Scroll,
      SettingBoxKey.danmakuFixedV: danmakuFixedV,
      SettingBoxKey.danmakuWeight: danmakuWeight,
      SettingBoxKey.highLikeDanmakuThreshold: highLikeDanmakuThreshold,
      SettingBoxKey.danmakuMergeMode: mergeMode.index,
SettingBoxKey.mergeDanmaku:
    mergeMode == DanmakuMergeMode.segment,
SettingBoxKey.burstDanmakuTriggerCount:
    burstDanmakuTriggerCount,
SettingBoxKey.burstDanmakuWindowSeconds:
    burstDanmakuWindowSeconds,
SettingBoxKey.burstDanmakuCooldownSeconds:
    burstDanmakuCooldownSeconds,
SettingBoxKey.burstDanmakuFontScale:
    burstDanmakuFontScale,
      SettingBoxKey.danmakuOpacity: danmakuOpacity,
    });
  }
}
