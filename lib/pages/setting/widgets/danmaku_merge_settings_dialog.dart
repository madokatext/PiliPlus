import 'package:PiliPlus/models/common/danmaku_merge_mode.dart';
import 'package:PiliPlus/models/common/theme/theme_color_type.dart';
import 'package:PiliPlus/plugin/pl_player/utils/danmaku_options.dart';
import 'package:PiliPlus/utils/extension/theme_ext.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<bool> showDanmakuMergeSettingsDialog(
  BuildContext context,
) async {
  var mergeMode = DanmakuOptions.mergeMode;
  var triggerCount =
      DanmakuOptions.burstDanmakuTriggerCount;
  var windowSeconds =
      DanmakuOptions.burstDanmakuWindowSeconds;
  var cooldownSeconds =
      DanmakuOptions.burstDanmakuCooldownSeconds;
  var fontScale =
      DanmakuOptions.burstDanmakuFontScale;

  String? triggerError;

  final triggerController = TextEditingController(
    text: triggerCount.toString(),
  );

  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          Widget buildSlider({
            required String title,
            required double value,
            required double min,
            required double max,
            required int divisions,
            required String valueText,
            required ValueChanged<double> onChanged,
          }) {
            return Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Text('$title：$valueText'),
                Slider(
                  value: value,
                  min: min,
                  max: max,
                  divisions: divisions,
                  label: valueText,
                  onChanged: onChanged,
                ),
              ],
            );
          }

          return AlertDialog(
            title: const Text('重复满屏飘字合并，我嘞个豆'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('合并方式，CPU 都看沉默了'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final mode
                            in DanmakuMergeMode.values)
                          ChoiceChip(
                            label: Text(mode.label),
                            selected:
                                mergeMode == mode,
                            onSelected: (_) {
                              setDialogState(() {
                                mergeMode = mode;
                              });
                            },
                          ),
                      ],
                    ),
                    if (mergeMode ==
                        DanmakuMergeMode.segment) ...[
                      const SizedBox(height: 12),
                      const Text(
                        '旧式模式会在每个六分钟满屏飘字分段内，，包的'
                        '把正文完全相同的满屏飘字合并到第一条。',
                      ),
                    ],
                    if (mergeMode ==
                        DanmakuMergeMode.burst) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: triggerController,
                        keyboardType:
                            TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter
                              .digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText: '触发数量，启动！',
                          suffixText: '条，已老实',
                          helperText:
                              '统计窗口内达到该数量后置顶合并，我嘞个豆',
                          errorText: triggerError,
                        ),
                        onChanged: (_) {
                          if (triggerError != null) {
                            setDialogState(() {
                              triggerError = null;
                            });
                          }
                        },
                      ),
                      buildSlider(
                        title: '触发统计时间段，CPU 都看沉默了',
                        value: windowSeconds,
                        min: 0.5,
                        max: 60,
                        divisions: 119,
                        valueText:
                            '${windowSeconds.toStringAsFixed(1)} 秒，已老实',
                        onChanged: (value) {
                          setDialogState(() {
                            windowSeconds = value;
                          });
                        },
                      ),
                      buildSlider(
                        title: '冷却时间，包的',
                        value: cooldownSeconds,
                        min: 0.5,
                        max: 60,
                        divisions: 119,
                        valueText:
                            '${cooldownSeconds.toStringAsFixed(1)} 秒，优势在我',
                        onChanged: (value) {
                          setDialogState(() {
                            cooldownSeconds = value;
                          });
                        },
                      ),
                      buildSlider(
  title: '置顶满屏飘字字有多大倍率，包的',
  value: fontScale,
  min: 1,
  max: 5,
  divisions: 80,
  valueText:
      '${fontScale.toStringAsFixed(2)}×',
                        onChanged: (value) {
                          setDialogState(() {
                            fontScale = value;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '冷却时间从最后一条相同满屏飘字开始计算。',
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: const Text('不整了，撤！'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(dialogContext).uiColor(
                    ThemeUiElement.danmakuMergeConfirmBackground,
                  ),
                  foregroundColor: Theme.of(dialogContext).uiColor(
                    ThemeUiElement.danmakuMergeConfirmContent,
                  ),
                ),
                onPressed: () async {
                  if (mergeMode ==
                      DanmakuMergeMode.burst) {
                    final parsed = int.tryParse(
                      triggerController.text,
                    );

                    if (parsed == null ||
                        parsed < 2 ||
                        parsed > 9999) {
                      setDialogState(() {
                        triggerError = '请往里塞 2～9999';
                      });
                      return;
                    }

                    triggerCount = parsed;
                  }

                  DanmakuOptions.mergeMode =
                      mergeMode;
                  DanmakuOptions
                          .burstDanmakuTriggerCount =
                      triggerCount;
                  DanmakuOptions
                          .burstDanmakuWindowSeconds =
                      windowSeconds;
                  DanmakuOptions
                          .burstDanmakuCooldownSeconds =
                      cooldownSeconds;
                  DanmakuOptions
                          .burstDanmakuFontScale =
                      fontScale;

                  await DanmakuOptions
                      .saveMergeSettings();

                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext)
                        .pop(true);
                  }
                },
                child: const Text('包的，就这么整'),
              ),
            ],
          );
        },
      );
    },
  );

  triggerController.dispose();

  return result ?? false;
}
