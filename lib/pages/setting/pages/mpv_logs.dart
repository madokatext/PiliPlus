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
  late Future<String> _future = MpvLogService.readLastLog();

  void _reload() {
    setState(() => _future = MpvLogService.readLastLog());
  }

  Future<void> _copy() async {
    final content = await MpvLogService.readLastLog();
    if (content.isEmpty) {
      SmartDialog.showToast('暂无日志');
      return;
    }
    Utils.copyText(content);
  }

  Future<void> _clear() async {
    await MpvLogService.clear();
    if (!mounted) return;
    _reload();
    SmartDialog.showToast('已清空');
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.viewPaddingOf(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('上次 mpv 播放日志'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: '复制',
            onPressed: _copy,
            icon: const Icon(Icons.copy_outlined),
          ),
          IconButton(
            tooltip: '清空',
            onPressed: _clear,
            icon: const Icon(Icons.delete_outline),
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
              '详细日志可能包含临时播放地址或请求信息，分享前请检查。',
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
                  return const Center(child: Text('暂无 mpv 播放日志'));
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
