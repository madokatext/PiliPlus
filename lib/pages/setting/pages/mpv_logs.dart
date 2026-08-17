import 'package:PiliPlus/common/widgets/dialog/export_import.dart';
import 'package:PiliPlus/services/mpv_log_service.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

class MpvLogsPage extends StatefulWidget {
  const MpvLogsPage({super.key});

  @override
  State<MpvLogsPage> createState() => _MpvLogsPageState();
}

class _MpvLogsPageState extends State<MpvLogsPage> {
  late final Future<String> _future = MpvLogService.readLastLog();
  bool _saving = false;

  Future<void> _copy() async {
    final content = await MpvLogService.readLastLog();
    if (content.isEmpty) {
      SmartDialog.showToast('暂无日志，功德+1');
      return;
    }
    Utils.copyText(content);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final content = await MpvLogService.readLastLog();
      if (content.isEmpty) {
        SmartDialog.showToast('暂无日志，功德+1');
        return;
      }
      await exportToLocalFile(
        onExport: () => content,
        localFileName: () => 'mpv_log',
        fileExtension: 'log',
        allowedExtensions: const ['log', 'txt'],
      );
    } catch (e) {
      SmartDialog.showToast('焊死寄了：$e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.viewPaddingOf(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('上次 mpv 开炫日志'),
        actions: [
          IconButton(
            tooltip: '焊死至自家硬盘',
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_alt),
          ),
          IconButton(
            tooltip: '赛博复刻',
            onPressed: _copy,
            icon: const Icon(Icons.copy_outlined),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Text(
              '详细日志可能包含先凑合开炫地址或敲机房大爹家门信息，到处扩散前请检查。',
            ),
          ),
          Expanded(
            child: FutureBuilder<String>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: SelectableText('${snapshot.error}'));
                }
                final content = snapshot.data ?? '';
                if (content.isEmpty) {
                  return const Center(child: Text('暂无 mpv 开炫日志'));
                }
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    padding.left + 12,
                    8,
                    padding.right + 12,
                    padding.bottom + 24,
                  ),
                  child: SelectableText(
                    content,
                    style: const TextStyle(
                      fontFamily: 'Monospace',
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
