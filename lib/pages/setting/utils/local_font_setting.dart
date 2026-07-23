import 'package:PiliPlus/utils/local_font_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

Future<void> showLocalFontSetting(
  BuildContext context, {
  required LocalFontSlot slot,
  required VoidCallback onChanged,
}) async {
  var isBusy = false;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        final family = LocalFontManager.familyFor(slot);

        Future<void> selectFont() async {
          setDialogState(() => isBusy = true);
          try {
            if (await LocalFontManager.pickAndInstall(slot)) {
              onChanged();
              if (dialogContext.mounted) {
                setDialogState(() {});
              }
              SmartDialog.showToast('${slot.label}已更新，请确认预览效果');
            }
          } catch (e) {
            SmartDialog.showToast('字体加载失败：$e');
          } finally {
            if (dialogContext.mounted) {
              setDialogState(() => isBusy = false);
            }
          }
        }

        Future<void> resetFont() async {
          setDialogState(() => isBusy = true);
          try {
            await LocalFontManager.reset(slot);
            onChanged();
            if (dialogContext.mounted) {
              setDialogState(() {});
            }
            SmartDialog.showToast('${slot.label}已恢复系统默认');
          } catch (e) {
            SmartDialog.showToast('字体加载失败：$e');
          } finally {
            if (dialogContext.mounted) {
              setDialogState(() => isBusy = false);
            }
          }
        }

        return AlertDialog(
          title: Text(slot.label),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('当前：${LocalFontManager.selectionLabel(slot)}'),
              const SizedBox(height: 16),
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline,
                  ),
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
                onPressed: isBusy ? null : resetFont,
                child: const Text('恢复系统默认'),
              ),
            TextButton(
              onPressed: isBusy ? null : selectFont,
              child: const Text('选择字体文件'),
            ),
            TextButton(
              onPressed: isBusy
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              child: const Text('确认'),
            ),
          ],
        );
      },
    ),
  );
}
