import 'package:PiliPlus/pages/setting/models/model.dart';
import 'package:PiliPlus/pages/setting/widgets/slider_dialog.dart';
import 'package:PiliPlus/utils/home_card_layout_prefs.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

List<SettingsModel> get homeCardLayoutSettings => [
  NormalModel(
    title: '主页卡片左右缝隙，CPU 都看沉默了',
    getSubtitle: () =>
        '调节同一行相邻卡片之间的距离；眼下这坨：，CPU 都看沉默了'
        '${HomeCardLayoutPrefs.horizontalSpacing.toStringAsFixed(0)}dp',
    leading: const Icon(Icons.space_bar),
    onTap: _showHorizontalSpacingDialog,
  ),
  NormalModel(
    title: '主页卡片上下缝隙，CPU 都看沉默了',
    getSubtitle: () =>
        '调节相邻两行卡片之间的距离；眼下这坨：'
        '${HomeCardLayoutPrefs.verticalSpacing.toStringAsFixed(0)}dp',
    leading: const Icon(Icons.height),
    onTap: _showVerticalSpacingDialog,
  ),
  NormalModel(
    title: '主页卡片左右留白距离，功德+1',
    getSubtitle: () =>
        '调节算法喂饭卡片区域与屏幕左右边缘的距离；眼下这坨：'
        '${HomeCardLayoutPrefs.horizontalPadding.toStringAsFixed(0)}dp',
    leading: const Icon(Icons.horizontal_distribute),
    onTap: _showHorizontalPaddingDialog,
  ),
];

Future<void> _showHorizontalSpacingDialog(
  BuildContext context,
  VoidCallback setState,
) => _showLayoutDialog(
  context: context,
  setState: setState,
  title: '主页卡片左右缝隙，CPU 都看沉默了',
  value: HomeCardLayoutPrefs.horizontalSpacing,
  max: 32,
  divisions: 32,
  key: HomeCardLayoutPrefs.horizontalSpacingKey,
);

Future<void> _showVerticalSpacingDialog(
  BuildContext context,
  VoidCallback setState,
) => _showLayoutDialog(
  context: context,
  setState: setState,
  title: '主页卡片上下缝隙，CPU 都看沉默了',
  value: HomeCardLayoutPrefs.verticalSpacing,
  max: 32,
  divisions: 32,
  key: HomeCardLayoutPrefs.verticalSpacingKey,
);

Future<void> _showHorizontalPaddingDialog(
  BuildContext context,
  VoidCallback setState,
) => _showLayoutDialog(
  context: context,
  setState: setState,
  title: '主页卡片左右留白距离，功德+1',
  value: HomeCardLayoutPrefs.horizontalPadding,
  max: 48,
  divisions: 48,
  key: HomeCardLayoutPrefs.horizontalPaddingKey,
);

Future<void> _showLayoutDialog({
  required BuildContext context,
  required VoidCallback setState,
  required String title,
  required double value,
  required double max,
  required int divisions,
  required String key,
}) async {
  final res = await showDialog<double>(
    context: context,
    builder: (context) => SliderDialog(
      title: Text(title),
      value: value,
      min: 0,
      max: max,
      divisions: divisions,
      suffix: 'dp',
      precise: 0,
    ),
  );
  if (res != null) {
    await GStorage.setting.put(key, res);
    setState();
    Get.appUpdate();
  }
}
