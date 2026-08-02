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
    if (timestamp == null || timestamp <= 0) return '暂无';
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
      title: const Text('历史记录归档'),
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
                  '历史记录功能已关闭，本地归档同步已停止。此状态优先于下方自动归档开关。',
                  style: TextStyle(color: colors.onErrorContainer),
                ),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('自动归档'),
              subtitle: const Text('仅在 App 前台空闲且未播放视频或直播时执行'),
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
                const Expanded(child: Text('自动归档周期')),
                Text('$intervalDays 天'),
              ],
            ),
            Slider(
              min: 1,
              max: 30,
              divisions: 29,
              label: intervalDays == 30 ? '每月' : '$intervalDays 天',
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
              title: const Text('静默归档'),
              subtitle: const Text('关闭后自动归档结果将以 Toast 提示'),
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
              label: '上次归档时间',
              value: _formatTime(repository.lastArchiveAt),
            ),
            const SizedBox(height: 8),
            _StatusRow(
              label: '最新本地记录观看时间',
              value: _formatTime(repository.latestViewAt, seconds: true),
            ),
            const SizedBox(height: 8),
            _StatusRow(
              label: '本地存档记录数',
              value: '${repository.length}',
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: running ? null : _archiveNow,
              icon: const Icon(Icons.archive_outlined),
              label: Text(running ? '归档中…' : '立即归档'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: running ? null : _showImportExport,
              icon: const Icon(Icons.import_export_outlined),
              label: const Text('导入/导出 JSON 存档'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: running ? null : _confirmClear,
              icon: Icon(Icons.delete_outline, color: colors.error),
              label: Text('清除本地存档', style: TextStyle(color: colors.error)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: running ? null : () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  Future<void> _archiveNow() async {
    setState(() => running = true);
    SmartDialog.showLoading(msg: '正在归档历史记录');
    final result = await service.archiveNow();
    SmartDialog.dismiss();
    SmartDialog.showToast(result.message);
    if (mounted) setState(() => running = false);
  }

  void _showImportExport() {
    if (service.isBusy) {
      SmartDialog.showToast('已有归档或存档维护操作正在进行');
      return;
    }
    Navigator.of(context).pop();
    showImportExportDialog<Map<String, dynamic>>(
      widget.parentContext,
      title: '历史记录存档',
      onExport: service.exportJson,
      onImport: service.importJson,
      localFileName: () => 'history_archive',
    );
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除本地历史存档？'),
        content: const Text('此操作只清除本地总库，不会删除云端观看记录，且不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认清除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => running = true);
    SmartDialog.showLoading(msg: '正在清除本地存档');
    String message;
    try {
      await service.clear();
      message = '本地历史存档已清除';
    } catch (e) {
      message = '清除失败：$e';
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
