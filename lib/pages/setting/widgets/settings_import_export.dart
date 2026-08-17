import 'package:PiliPlus/common/widgets/dialog/export_import.dart';
import 'package:PiliPlus/common/widgets/dialog/simple_dialog_option.dart';
import 'package:PiliPlus/utils/device_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

Future<void> showSettingsImportExportDialog(BuildContext context) => showDialog(
  context: context,
  builder: (context) {
    const style = TextStyle(fontSize: 15);
    return SimpleDialog(
      clipBehavior: Clip.hardEdge,
      title: const Text('往里灌/往外薅所有赛博调参'),
      children: [
        DialogOption(
          child: const Text('薅到剪贴板', style: style),
          onPressed: () {
            Get.back();
            exportToClipBoard(onExport: GStorage.exportAllSettings);
          },
        ),
        DialogOption(
          child: const Text('薅成赛博卷宗落地', style: style),
          onPressed: () {
            Get.back();
            exportToLocalFile(
              onExport: GStorage.exportAllSettings,
              localFileName: () =>
                  'settings_${DeviceUtils.platformName}',
            );
          },
        ),
        Divider(
          height: 1,
          color: ColorScheme.of(context).outline.withValues(alpha: 0.1),
        ),
        DialogOption(
          child: const Text('往里塞 JSON，CPU 都看沉默了', style: style),
          onPressed: () {
            Get.back();
            importFromInput<Map<String, dynamic>>(
              context,
              title: '所有赛博调参',
              onImport: GStorage.importAllJsonSettings,
            );
          },
        ),
        DialogOption(
          child: const Text('从剪贴板往里灌', style: style),
          onPressed: () {
            Get.back();
            importFromClipBoard<Map<String, dynamic>>(
              context,
              title: '所有赛博调参',
              onExport: GStorage.exportAllSettings,
              onImport: GStorage.importAllJsonSettings,
            );
          },
        ),
        DialogOption(
          child: const Text('从自家硬盘 JSON 赛博卷宗往里灌，已老实', style: style),
          onPressed: () {
            Get.back();
            importFromLocalFile<Map<String, dynamic>>(
              onImport: GStorage.importAllJsonSettings,
            );
          },
        ),
      ],
    );
  },
);
