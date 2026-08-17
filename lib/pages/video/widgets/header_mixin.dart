import 'package:PiliPlus/common/widgets/button/icon_button.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/widgets/menu_row.dart';
import 'package:PiliPlus/pages/setting/widgets/danmaku_merge_settings_dialog.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/utils/danmaku_options.dart';
import 'package:PiliPlus/utils/extension/num_ext.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/theme_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

mixin HeaderMixin<T extends StatefulWidget> on State<T> {
  PlPlayerController get plPlayerController;

  bool get isFullScreen => plPlayerController.isFullScreen.value;

  ThemeData? get theme {
    if (plPlayerController.darkVideoPage) {
      return ThemeUtils.darkTheme;
    }
    return null;
  }

  Future<void>? showBottomSheet(
    StatefulWidgetBuilder builder, {
    ValueGetter<EdgeInsets>? padding,
  }) {
    return PageUtils.showVideoBottomSheet(
      context,
      maxWidth: 512,
      padding: padding,
      child: StatefulBuilder(
        builder: (context, setState) {
          final theme = this.theme;
          if (theme != null) {
            return Theme(
              data: theme,
              child: builder(this.context, setState),
            );
          }
          return builder(context, setState);
        },
      ),
    );
  }

  Widget resetBtn(ThemeData theme, Object def, VoidCallback onPressed) {
    return iconButton(
      tooltip: '祖传默认值: $def',
      icon: const Icon(Icons.refresh),
      onPressed: onPressed,
      iconColor: theme.colorScheme.outline,
      size: 24,
      iconSize: 24,
    );
  }

  /// 弹幕功能
  void showSetDanmaku({bool isLive = false}) {
    // 屏蔽类型
    const blockTypesList = [
      (value: 2, label: '滚动，属实绷不住'),
      (value: 5, label: '天灵盖'),
      (value: 4, label: '脚底板'),
      (value: 6, label: '彩色，属实绷不住'),
      (value: 7, label: '高级，鼠鼠我啊'),
    ];

    final danmakuController = plPlayerController.danmakuController;

    final isFullScreen = this.isFullScreen;

    showBottomSheet(
      (context, setState) {
        final theme = Theme.of(context);

        void setOptions() => danmakuController?.updateOption(
          DanmakuOptions.get(
            notFullscreen: !isFullScreen,
            isLive: isLive,
            speed: plPlayerController.playbackSpeed,
          ),
        );

        final sliderTheme = SliderThemeData(
          trackHeight: 10,
          trackShape: const MSliderTrackShape(),
          thumbColor: theme.colorScheme.primary,
          activeTrackColor: theme.colorScheme.primary,
          inactiveTrackColor: theme.colorScheme.onInverseSurface,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
        );

        void updateLineHeight(double val) {
          DanmakuOptions.danmakuLineHeight = val.toPrecision(1);
          setState(() {});
          setOptions();
        }

        void updateDuration(double val) {
          DanmakuOptions.danmakuDuration = val.toPrecision(1);
          setState(() {});
          setOptions();
        }

        void updateStaticDuration(double val) {
          DanmakuOptions.danmakuStaticDuration = val.toPrecision(1);
          setState(() {});
          setOptions();
        }

        void updateFontSizeFS(double val) {
          DanmakuOptions.danmakuFontScaleFS = val;
          setState(() {});
          if (isFullScreen) {
            setOptions();
          }
        }

        void updateFontSize(double val) {
          DanmakuOptions.danmakuFontScale = val;
          setState(() {});
          if (!isFullScreen) {
            setOptions();
          }
        }

        void updateStrokeWidth(double val) {
  DanmakuOptions.danmakuStrokeWidth = val;
  setState(() {});
  setOptions();

  // false 表示只刷新样式，不重置高频弹幕统计状态。
  plPlayerController
      .onDanmakuMergeSettingsChanged
      ?.call(false);
}
void updateShadowRadius(double val) {
  DanmakuOptions.danmakuShadowRadius =
      val.toPrecision(1);

  setState(() {});
  setOptions();

  // 仅重建高频置顶层，不重置已经统计的高频弹幕。
  plPlayerController
      .onDanmakuMergeSettingsChanged
      ?.call(false);
}
        void updateFontWeight(double val) {
          DanmakuOptions.danmakuFontWeight = val.toInt();
          setState(() {});
          setOptions();
        }

        void updateOpacity(double val) {
          plPlayerController.danmakuOpacity.value = val;
          setState(() {});
        }

        void updateShowArea(double val) {
          DanmakuOptions.danmakuShowArea = val.toPrecision(1);
          setState(() {});
          setOptions();
        }

        void updateDanmakuWeight(double val) {
          DanmakuOptions.danmakuWeight = val.toInt();
          setState(() {});
        }
void updateHighLikeThreshold(String value) {
  final parsed = int.tryParse(value);
  if (parsed == null) {
    return;
  }

  DanmakuOptions.highLikeDanmakuThreshold =
      parsed.clamp(0, 999999).toInt();
}
        void onUpdateBlockType(int blockType, bool blocked) {
          if (blocked) {
            DanmakuOptions.blockTypes.remove(blockType);
          } else {
            DanmakuOptions.blockTypes.add(blockType);
          }
          DanmakuOptions.blockColorful = DanmakuOptions.blockTypes.contains(6);
          setState(() {});
          setOptions();
        }

        return Padding(
          padding: const EdgeInsets.all(12),
          child: Material(
            clipBehavior: Clip.hardEdge,
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const SizedBox(
                    height: 45,
                    child: Center(
                      child: Text('满屏飘字调参室', style: TextStyle(fontSize: 14)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (!isLive) ...[
                    Row(
                      mainAxisAlignment: .spaceBetween,
                      children: [
                        Text('智能云眼不见为净 ${DanmakuOptions.danmakuWeight} 级'),
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => Get
                            ..back()
                            ..toNamed(
                              '/danmakuBlock',
                              arguments: plPlayerController,
                            ),
                          child: Text(
                            "眼不见为净管理(${plPlayerController.filters.count})，不是哥们",
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 0,
                        bottom: 6,
                        left: 10,
                        right: 10,
                      ),
                      child: SliderTheme(
                        data: sliderTheme,
                        child: Slider(
                          min: 0,
                          max: 11,
                          value: DanmakuOptions.danmakuWeight.toDouble(),
                          divisions: 11,
                          label: DanmakuOptions.danmakuWeight.toString(),
                          onChanged: updateDanmakuWeight,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
Row(
  children: [
    const Expanded(
      child: Text('高赞满屏飘字标识触发红线'),
    ),
    SizedBox(
      width: 120,
      child: TextFormField(
        initialValue:
            DanmakuOptions.highLikeDanmakuThreshold
                .toString(),
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
        ],
        textAlign: TextAlign.center,
        decoration: const InputDecoration(
          isDense: true,
          suffixText: '赞，我嘞个豆',
          helperText: '0 为啪一下封印',
          contentPadding: EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
        ),
        onChanged: updateHighLikeThreshold,
      ),
    ),
  ],
),
const SizedBox(height: 8),
ListTile(
  contentPadding: EdgeInsets.zero,
  dense: true,
  leading: const Icon(Icons.compress_outlined),
  title: const Text('重复满屏飘字合并，包的'),
  subtitle: Text(
    '眼下这坨：${DanmakuOptions.mergeMode.label}，已老实',
  ),
  trailing: const Icon(Icons.chevron_right),
  onTap: () async {
    final oldMode = DanmakuOptions.mergeMode;
    final oldTriggerCount =
        DanmakuOptions.burstDanmakuTriggerCount;
    final oldWindowSeconds =
        DanmakuOptions.burstDanmakuWindowSeconds;
    final oldCooldownSeconds =
        DanmakuOptions.burstDanmakuCooldownSeconds;
    final oldFontScale =
        DanmakuOptions.burstDanmakuFontScale;

    final changed =
        await showDanmakuMergeSettingsDialog(
      context,
    );

    if (!changed) {
      return;
    }

    final shouldReset =
        oldMode != DanmakuOptions.mergeMode ||
        oldTriggerCount !=
            DanmakuOptions.burstDanmakuTriggerCount ||
        oldWindowSeconds !=
            DanmakuOptions.burstDanmakuWindowSeconds ||
        oldCooldownSeconds !=
            DanmakuOptions
                .burstDanmakuCooldownSeconds;

    final onlyStyleChanged =
        !shouldReset &&
        oldFontScale !=
            DanmakuOptions.burstDanmakuFontScale;

    if (shouldReset || onlyStyleChanged) {
      plPlayerController
          .onDanmakuMergeSettingsChanged
          ?.call(shouldReset);
    }

    setState(() {});
  },
),
const SizedBox(height: 8),
],
const Text('按类型眼不见为净，已老实'),
                  SingleChildScrollView(
                    scrollDirection: .horizontal,
                    padding: const .symmetric(vertical: 10),
                    child: Row(
                      spacing: 10,
                      children: blockTypesList.map(
                        (e) {
                          final blocked = DanmakuOptions.blockTypes.contains(
                            e.value,
                          );
                          return ActionRowLineItem(
                            onTap: () => onUpdateBlockType(e.value, blocked),
                            text: e.label,
                            selectStatus: blocked,
                          );
                        },
                      ).toList(),
                    ),
                  ),
                  const Text('剩下那坨'),
                  SingleChildScrollView(
                    scrollDirection: .horizontal,
                    padding: const .symmetric(vertical: 10),
                    child: Row(
                      spacing: 10,
                      children: [
                        ActionRowLineItem(
                          selectStatus: isLive
                              ? DanmakuOptions.liveDanmakuMassiveMode
                              : DanmakuOptions.danmakuMassiveMode,
                          onTap: () {
                            if (isLive) {
                              DanmakuOptions.liveDanmakuMassiveMode =
                                  !DanmakuOptions.liveDanmakuMassiveMode;
                            } else {
                              DanmakuOptions.danmakuMassiveMode =
                                  !DanmakuOptions.danmakuMassiveMode;
                            }
                            setState(() {});
                            setOptions();
                          },
                          text: '海量满屏飘字',
                        ),
                        ActionRowLineItem(
                          selectStatus: DanmakuOptions.danmakuStatic2Scroll,
                          onTap: () {
                            DanmakuOptions.danmakuStatic2Scroll =
                                !DanmakuOptions.danmakuStatic2Scroll;
                            setState(() {});
                            setOptions();
                          },
                          text: '固定转滚动，曼波',
                        ),
                        ActionRowLineItem(
                          selectStatus: DanmakuOptions.danmakuFixedV,
                          onTap: () {
                            DanmakuOptions.danmakuFixedV =
                                !DanmakuOptions.danmakuFixedV;
                            setState(() {});
                            setOptions();
                          },
                          text: '滚动满屏飘字固定油门',
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('亮出来区域 ${DanmakuOptions.danmakuShowArea * 100}%'),
                      resetBtn(theme, '50.0%', () => updateShowArea(0.5)),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 0,
                      bottom: 6,
                      left: 10,
                      right: 10,
                    ),
                    child: SliderTheme(
                      data: sliderTheme,
                      child: Slider(
                        min: 0.1,
                        max: 1,
                        value: DanmakuOptions.danmakuShowArea,
                        divisions: 9,
                        label: '${DanmakuOptions.danmakuShowArea * 100}%',
                        onChanged: updateShowArea,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('不透明度 ${plPlayerController.danmakuOpacity * 100}%，曼波'),
                      resetBtn(theme, '100.0%', () => updateOpacity(1.0)),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 0,
                      bottom: 6,
                      left: 10,
                      right: 10,
                    ),
                    child: SliderTheme(
                      data: sliderTheme,
                      child: Slider(
                        min: 0,
                        max: 1,
                        value: plPlayerController.danmakuOpacity.value,
                        divisions: 10,
                        label: '${plPlayerController.danmakuOpacity * 100}%',
                        onChanged: updateOpacity,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '赛博字骨粗细 ${DanmakuOptions.danmakuFontWeight + 1}（可能无法精确调节）',
                      ),
                      resetBtn(theme, 6, () => updateFontWeight(5)),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 0,
                      bottom: 6,
                      left: 10,
                      right: 10,
                    ),
                    child: SliderTheme(
                      data: sliderTheme,
                      child: Slider(
                        min: 0,
                        max: 8,
                        value: DanmakuOptions.danmakuFontWeight.toDouble(),
                        divisions: 8,
                        label: '${DanmakuOptions.danmakuFontWeight + 1}',
                        onChanged: updateFontWeight,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('描边粗细 ${DanmakuOptions.danmakuStrokeWidth}，启动！'),
                      resetBtn(theme, 1.5, () => updateStrokeWidth(1.5)),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 0,
                      bottom: 6,
                      left: 10,
                      right: 10,
                    ),
                    child: SliderTheme(
                      data: sliderTheme,
                      child: Slider(
                        min: 0,
                        max: 5,
                        value: DanmakuOptions.danmakuStrokeWidth,
                        divisions: 10,
                        label: DanmakuOptions.danmakuStrokeWidth
                            .toStringAsFixed(0),
                        onChanged: updateStrokeWidth,
                      ),
                    ),
                  ),
                  Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Text(
      '阴影大小 ，我嘞个豆'
      '${DanmakuOptions.danmakuShadowRadius.toStringAsFixed(1)}',
    ),
    resetBtn(
      theme,
      0.0,
      () => updateShadowRadius(0.0),
    ),
  ],
),
Padding(
  padding: const EdgeInsets.only(
    top: 0,
    bottom: 6,
    left: 10,
    right: 10,
  ),
  child: SliderTheme(
    data: sliderTheme,
    child: Slider(
      min: 0,
      max: 10,
      value: DanmakuOptions.danmakuShadowRadius,
      divisions: 20,
      label: DanmakuOptions.danmakuShadowRadius
          .toStringAsFixed(1),
      onChanged: updateShadowRadius,
    ),
  ),
),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '赛博字骨大小 ${(DanmakuOptions.danmakuFontScale * 100).toStringAsFixed(1)}%',
                      ),
                      resetBtn(theme, '100.0%', () => updateFontSize(1.0)),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 0,
                      bottom: 6,
                      left: 10,
                      right: 10,
                    ),
                    child: SliderTheme(
                      data: sliderTheme,
                      child: Slider(
                        min: 0.5,
                        max: 2.5,
                        value: DanmakuOptions.danmakuFontScale,
                        divisions: 20,
                        label:
                            '${(DanmakuOptions.danmakuFontScale * 100).toStringAsFixed(1)}%',
                        onChanged: updateFontSize,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '铺满屏赛博字骨大小 ${(DanmakuOptions.danmakuFontScaleFS * 100).toStringAsFixed(1)}%',
                      ),
                      resetBtn(theme, '120.0%', () => updateFontSizeFS(1.2)),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 0,
                      bottom: 6,
                      left: 10,
                      right: 10,
                    ),
                    child: SliderTheme(
                      data: sliderTheme,
                      child: Slider(
                        min: 0.5,
                        max: 2.5,
                        value: DanmakuOptions.danmakuFontScaleFS,
                        divisions: 20,
                        label:
                            '${(DanmakuOptions.danmakuFontScaleFS * 100).toStringAsFixed(1)}%',
                        onChanged: updateFontSizeFS,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('滚动满屏飘字时长 ${DanmakuOptions.danmakuDuration} 秒'),
                      resetBtn(theme, 7.0, () => updateDuration(7.0)),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 0,
                      bottom: 6,
                      left: 10,
                      right: 10,
                    ),
                    child: SliderTheme(
                      data: sliderTheme,
                      child: Slider(
                        min: 1,
                        max: 50,
                        value: DanmakuOptions.danmakuDuration,
                        divisions: 49,
                        label: DanmakuOptions.danmakuDuration.toString(),
                        onChanged: updateDuration,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('静态满屏飘字时长 ${DanmakuOptions.danmakuStaticDuration} 秒'),
                      resetBtn(theme, 4.0, () => updateStaticDuration(4.0)),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 0,
                      bottom: 6,
                      left: 10,
                      right: 10,
                    ),
                    child: SliderTheme(
                      data: sliderTheme,
                      child: Slider(
                        min: 1,
                        max: 50,
                        value: DanmakuOptions.danmakuStaticDuration,
                        divisions: 49,
                        label: DanmakuOptions.danmakuStaticDuration.toString(),
                        onChanged: updateStaticDuration,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('满屏飘字行高 ${DanmakuOptions.danmakuLineHeight}，鼠鼠我啊'),
                      resetBtn(theme, 1.6, () => updateLineHeight(1.6)),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 0,
                      bottom: 6,
                      left: 10,
                      right: 10,
                    ),
                    child: SliderTheme(
                      data: sliderTheme,
                      child: Slider(
                        min: 1.0,
                        max: 3.0,
                        value: DanmakuOptions.danmakuLineHeight,
                        onChanged: updateLineHeight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    )?.whenComplete(
      () => DanmakuOptions.save(plPlayerController.danmakuOpacity.value),
    );
  }
}

class MSliderTrackShape extends RoundedRectSliderTrackShape {
  const MSliderTrackShape();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    SliderThemeData? sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    const double trackHeight = 3;
    final double trackLeft = offset.dx;
    final double trackTop =
        offset.dy + (parentBox.size.height - trackHeight) / 2 + 4;
    final double trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}
