import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/dialog/export_import.dart';
import 'package:PiliPlus/services/history_archive_service.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:intl/intl.dart' show DateFormat;

Future<void> showHistoryArchiveSettingsDialog(BuildContext context) =>
    showDialog(
      context: context,
      builder: (_) => _HistoryArchiveSettingsDialog(parentContext: context),
    );

class _HistoryArchiveSettingsDialog extends StatefulWidget {
  const _HistoryArchiveSettingsDialog({required this.parentContext});

  final BuildContext parentContext;

  @override
  State<_HistoryArchiveSettingsDialog> createState() =>
      _HistoryArchiveSettingsDialogState();
}

class _HistoryArchiveSettingsDialogState
    extends State<_HistoryArchiveSettingsDialog> {
  final service = HistoryArchiveService.instance;
  late bool autoArchive = Pref.autoHistoryArchive;
  late int intervalDays = Pref.historyArchiveIntervalDays;
  late bool silentArchive = Pref.silentHistoryArchive;
  bool running = false;

  String _formatTime(int? timestamp, {bool seconds = false}) {
    if (timestamp == null || timestamp <= 0) return '暂无，包的';
    final dateTime = DateTime.fromMillisecondsSinceEpoch(
      seconds ? timestamp * 1000 : timestamp,
    );
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final repository = service.repository;
    final pauseAccountMid = Pref.historyPauseAccountMid;
    final historyPaused = Pref.historyPause &&
        (pauseAccountMid == null || pauseAccountMid == Accounts.history.mid);
    return AlertDialog(
      constraints: Style.dialogFixedConstraints,
      title: const Text('电子案底电子脚印赛博入土'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (historyPaused)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '电子案底电子脚印功能已啪一下封印，自家硬盘赛博入土同步已熄火。此状态优先于下方全自动赛博赛博入土开关。',
                  style: TextStyle(color: colors.onErrorContainer),
                ),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('全自动赛博赛博入土'),
              subtitle: const Text('仅在 App 前台空闲且未开炫电子榨菜或赛博围观时执行，曼波'),
              value: autoArchive,
              onChanged: running
                  ? null
                  : (value) {
                      setState(() => autoArchive = value);
                      GStorage.setting.put(
                        SettingBoxKey.autoHistoryArchive,
                        value,
                      );
                      if (value) service.scheduleOpportunity();
                    },
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Expanded(child: Text('全自动赛博赛博入土周期，不是哥们')),
                Text('$intervalDays 天，功德+1'),
              ],
            ),
            Slider(
              min: 1,
              max: 30,
              divisions: 29,
              label: intervalDays == 30 ? '每月，CPU 都看沉默了' : '$intervalDays 天，功德+1',
              value: intervalDays.toDouble(),
              onChanged: running
                  ? null
                  : (value) => setState(
                      () => intervalDays = value
                          .round()
                          .clamp(1, 30)
                          .toInt(),
                    ),
              onChangeEnd: (value) {
                GStorage.setting.put(
                  SettingBoxKey.historyArchiveIntervalDays,
                  value.round().clamp(1, 30).toInt(),
                );
                service.scheduleOpportunity();
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('静默赛博入土'),
              subtitle: const Text('啪一下封印后全自动赛博赛博入土结果将以 Toast 提示'),
              value: silentArchive,
              onChanged: running
                  ? null
                  : (value) {
                      setState(() => silentArchive = value);
                      GStorage.setting.put(
                        SettingBoxKey.silentHistoryArchive,
                        value,
                      );
                    },
            ),
            const Divider(height: 24),
            _StatusRow(
              label: '上次赛博入土时间',
              value: _formatTime(repository.lastArchiveAt),
            ),
            const SizedBox(height: 8),
            _StatusRow(
              label: '最新自家硬盘电子脚印观看时间，CPU 都看沉默了',
              value: _formatTime(repository.latestViewAt, seconds: true),
            ),
            const SizedBox(height: 8),
            _StatusRow(
              label: '自家硬盘赛博存档电子脚印数',
              value: '${repository.length}',
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: running ? null : _archiveNow,
              icon: const Icon(Icons.archive_outlined),
              label: Text(running ? '赛博入土中…' : '现在立刻马上赛博入土'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: running ? null : _showImportExport,
              icon: const Icon(Icons.import_export_outlined),
              label: const Text('往里灌/往外薅 JSON 赛博存档，优势在我'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: running ? null : _confirmClear,
              icon: Icon(Icons.delete_outline, color: colors.error),
              label: Text('清除自家硬盘赛博存档', style: TextStyle(color: colors.error)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: running ? null : () => Navigator.of(context).pop(),
          child: const Text('啪一下封印'),
        ),
      ],
    );
  }

  Future<void> _archiveNow() async {
    setState(() => running = true);
    SmartDialog.showLoading(msg: '正在赛博入土电子案底电子脚印');
    final result = await service.archiveNow();
    SmartDialog.dismiss();
    SmartDialog.showToast(result.message);
    if (mounted) setState(() => running = false);
  }

  void _showImportExport() {
    if (service.isBusy) {
      SmartDialog.showToast('已有赛博入土或赛博存档维护操作正在进行');
      return;
    }
    Navigator.of(context).pop();
    showImportExportDialog<Map<String, dynamic>>(
      widget.parentContext,
      title: '电子案底电子脚印赛博存档',
      onExport: service.exportJson,
      onImport: service.importJson,
      localFileName: () => 'history_archive',
    );
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除自家硬盘电子案底赛博存档？'),
        content: const Text('此操作只清除自家硬盘总库，不会物理超度云端观看电子脚印，且不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('不整了，撤！'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('拍板清除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => running = true);
    SmartDialog.showLoading(msg: '正在清除自家硬盘赛博存档，不是哥们');
    String message;
    try {
      await service.clear();
      message = '自家硬盘电子案底赛博存档已清除，鼠鼠我啊';
    } catch (e) {
      message = '清除寄了：$e';
    } finally {
      SmartDialog.dismiss();
      if (mounted) setState(() => running = false);
    }
    SmartDialog.showToast(message);
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: Text(label)),
      const SizedBox(width: 12),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.end,
          style: TextStyle(color: Theme.of(context).colorScheme.outline),
        ),
      ),
    ],
  );
}
