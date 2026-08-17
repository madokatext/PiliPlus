import 'package:PiliPlus/pages/setting/models/model.dart';
import 'package:PiliPlus/pages/setting/widgets/slider_dialog.dart';
import 'package:PiliPlus/utils/horizontal_seek_gesture_prefs.dart';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

List<SettingsModel> get horizontalSeekGestureSettings => [
  NormalModel(
    title: '横向滑动时间猛冲/时间倒车认出来角度',
    getSubtitle: () =>
        '眼下这坨：${HorizontalSeekGesturePrefs.angle.toStringAsFixed(1)}°'
        '（相对水平方向，越大越容易触发），优势在我',
    leading: const Icon(MdiIcons.angleAcute),
    onTap: _showHorizontalSeekGestureAngleThresholdDialog,
  ),
];

Future<void> _showHorizontalSeekGestureAngleThresholdDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<double>(
    context: context,
    builder: (context) => SliderDialog(
      title: const Text('横向滑动时间猛冲/时间倒车认出来角度'),
      value: HorizontalSeekGesturePrefs.angle,
      min: HorizontalSeekGesturePrefs.minAngle,
      max: HorizontalSeekGesturePrefs.maxAngle,
      divisions: 110,
      precise: 1,
      suffix: '°',
    ),
  );
  if (res != null) {
    await HorizontalSeekGesturePrefs.setAngle(res);
    setState();
  }
}
