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
      title: const Text('导入/导出所有设置'),
      children: [
        DialogOption(
          child: const Text('导出至剪贴板', style: style),
          onPressed: () {
            Get.back();
            exportToClipBoard(onExport: GStorage.exportAllSettings);
          },
        ),
        DialogOption(
          child: const Text('导出文件至本地', style: style),
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
          child: const Text('输入 JSON', style: style),
          onPressed: () {
            Get.back();
            importFromInput<Map<String, dynamic>>(
              context,
              title: '所有设置',
              onImport: GStorage.importAllJsonSettings,
            );
          },
        ),
        DialogOption(
          child: const Text('从剪贴板导入', style: style),
          onPressed: () {
            Get.back();
            importFromClipBoard<Map<String, dynamic>>(
              context,
              title: '所有设置',
              onExport: GStorage.exportAllSettings,
              onImport: GStorage.importAllJsonSettings,
            );
          },
        ),
        DialogOption(
          child: const Text('从本地 JSON 文件导入', style: style),
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
