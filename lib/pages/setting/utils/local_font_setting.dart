import 'package:PiliPlus/utils/local_font_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

enum _LocalFontAction { select, reset }

Future<void> showLocalFontSetting(
  BuildContext context, {
  required LocalFontSlot slot,
  required VoidCallback onChanged,
}) async {
  final family = LocalFontManager.familyFor(slot);
  final action = await showDialog<_LocalFontAction>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(slot.label),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('当前：${LocalFontManager.selectionLabel(slot)}'),
          const SizedBox(height: 16),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: const BorderRadius.all(Radius.circular(8)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                slot.sample,
                style: TextStyle(fontFamily: family),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            slot.usesLatinSubset
                ? '支持 TTF、OTF、TTC；选择后会立即生成拉丁字符子集缓存。'
                : '支持 TTF、OTF、TTC；选中的文件会复制到应用目录。',
          ),
        ],
      ),
      actions: [
        if (LocalFontManager.isConfigured(slot))
          TextButton(
            onPressed: () => Get.back(result: _LocalFontAction.reset),
            child: const Text('恢复系统默认'),
          ),
        TextButton(
          onPressed: () => Get.back(result: _LocalFontAction.select),
          child: const Text('选择字体文件'),
        ),
        TextButton(
          onPressed: Get.back,
          child: const Text('取消'),
        ),
      ],
    ),
  );

  try {
    switch (action) {
      case _LocalFontAction.select:
        if (await LocalFontManager.pickAndInstall(slot)) {
          onChanged();
          SmartDialog.showToast('${slot.label}已更新');
        }
      case _LocalFontAction.reset:
        await LocalFontManager.reset(slot);
        onChanged();
        SmartDialog.showToast('${slot.label}已恢复系统默认');
      case null:
        break;
    }
  } catch (e) {
    SmartDialog.showToast('字体加载失败：$e');
  }
}
