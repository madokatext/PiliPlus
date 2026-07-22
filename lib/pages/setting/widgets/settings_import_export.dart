import 'dart:io' show Platform;

import 'package:PiliPlus/common/widgets/dialog/export_import.dart';
import 'package:PiliPlus/common/widgets/dialog/simple_dialog_option.dart';
import 'package:PiliPlus/utils/device_utils.dart';
import 'package:PiliPlus/utils/permission_handler.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' show DateFormat;

const _storageChannel = MethodChannel('com.example.piliplus/storage');

Future<void> _exportSettingsToDownloads() async {
  if (!Platform.isAndroid) {
    await exportToLocalFile(
      onExport: GStorage.exportAllSettings,
      localFileName: () => 'settings_${DeviceUtils.platformName}',
    );
    return;
  }

  if (DeviceUtils.sdkInt < 29) {
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      SmartDialog.showToast('存储权限未授权，无法写入主存储 Download 目录');
      return;
    }
  }

  final fileName =
      'piliplus_settings_${DeviceUtils.platformName}_'
      '${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json';
  try {
    final savedPath = await _storageChannel.invokeMethod<String>(
      'saveTextToDownloads',
      {
        'fileName': fileName,
        'content': GStorage.exportAllSettings(),
      },
    );
    SmartDialog.showToast('已导出至 ${savedPath ?? 'Download/$fileName'}');
  } on PlatformException catch (e) {
    SmartDialog.showToast('导出失败：${e.message ?? e.code}');
  } catch (e) {
    SmartDialog.showToast('导出失败：$e');
  }
}

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
          child: const Text('导出文件至主存储 Download', style: style),
          onPressed: () {
            Get.back();
            _exportSettingsToDownloads();
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
