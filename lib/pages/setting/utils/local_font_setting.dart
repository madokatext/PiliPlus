import 'package:PiliPlus/utils/local_font_manager.dart';
import 'package:flutter/material.dart';

Future<void> showLocalFontSetting(
  BuildContext context, {
  required LocalFontSlot slot,
  required VoidCallback onChanged,
}) async {
  var isBusy = false;
  var pendingReset = false;
  String? errorText;
  LocalFontCandidate? pendingCandidate;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        final previewFamily = pendingReset
            ? null
            : pendingCandidate?.family ??
                  LocalFontManager.familyFor(slot);

        final pendingLabel = pendingReset
            ? '系统大爹祖传默认，曼波'
            : pendingCandidate?.sourceName;

        Future<void> selectFont() async {
          setDialogState(() {
            isBusy = true;
            errorText = null;
          });

          try {
            final candidate = await LocalFontManager.pickCandidate(slot);

            if (candidate != null && dialogContext.mounted) {
              setDialogState(() {
                pendingCandidate = candidate;
                pendingReset = false;
              });
            }
          } catch (e) {
            if (dialogContext.mounted) {
              setDialogState(() {
                errorText = '赛博字骨疯狂搬赛博粮寄了：$e';
              });
            }
          } finally {
            if (dialogContext.mounted) {
              setDialogState(() {
                isBusy = false;
              });
            }
          }
        }

        void stageReset() {
          setDialogState(() {
            pendingCandidate = null;
            pendingReset = true;
            errorText = null;
          });
        }

        Future<void> confirm() async {
          final candidate = pendingCandidate;
          final hasPendingChange = pendingReset || candidate != null;

          // 没有选择新字体时，确认只关闭弹窗。
          if (!hasPendingChange) {
            Navigator.of(dialogContext).pop();
            return;
          }

          setDialogState(() {
            isBusy = true;
            errorText = null;
          });

          try {
            if (pendingReset) {
              await LocalFontManager.reset(slot);
            } else {
              await LocalFontManager.commitCandidate(candidate!);
            }

            // 只有提交成功后才刷新 App 或弹幕字体。
            onChanged();

            if (dialogContext.mounted) {
              Navigator.of(dialogContext).pop();
            }
          } catch (e) {
            if (dialogContext.mounted) {
              setDialogState(() {
                errorText = '赛博字骨这坨 App寄了：$e';
                isBusy = false;
              });
            }
          }
        }

        return PopScope(
          canPop: !isBusy,
          child: AlertDialog(
            title: Text(slot.label),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '眼下这坨：${LocalFontManager.selectionLabel(slot)}',
                ),
                if (pendingLabel != null) ...[
                  const SizedBox(height: 4),
                  Text('待拍板：$pendingLabel'),
                ],
                const SizedBox(height: 16),
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    borderRadius: const BorderRadius.all(
                      Radius.circular(8),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      slot.sample,
                      style: TextStyle(
                        fontFamily: previewFamily,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  slot.usesLatinSubset
                      ? '支持 TTF、OTF、TTC；抓一个后仅在此处预览拉丁字符子集，点击“拍板”后这坨 App。，曼波'
                      : '支持 TTF、OTF、TTC；抓一个后仅在此处预览，点击“拍板”后这坨 App。',
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorText!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              if (LocalFontManager.isConfigured(slot) ||
                  pendingCandidate != null)
                TextButton(
                  onPressed: isBusy ? null : stageReset,
                  child: const Text('复活系统大爹祖传默认，启动！'),
                ),
              TextButton(
                onPressed: isBusy ? null : selectFont,
                child: const Text('抓一个赛博字骨赛博卷宗，优势在我'),
              ),
              TextButton(
                onPressed: isBusy
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: const Text('不整了，撤！'),
              ),
              TextButton(
                onPressed: isBusy ? null : confirm,
                child: const Text('拍板，启动！'),
              ),
            ],
          ),
        );
      },
    ),
  );
}
