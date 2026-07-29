import 'dart:io' show Platform;

import 'package:PiliPlus/services/mpv_log_service.dart';
import 'package:PiliPlus/utils/device_utils.dart';
import 'package:PiliPlus/utils/permission_handler.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:intl/intl.dart' show DateFormat;

const _storageChannel = MethodChannel('com.max.piliplus/storage');

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
      SmartDialog.showToast('暂无日志');
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
        SmartDialog.showToast('暂无日志');
        return;
      }
      if (!Platform.isAndroid) {
        SmartDialog.showToast('保存至主存储 Download 目录仅支持 Android');
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
          'piliplus_mpv_log_'
          '${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.log';
      final savedPath = await _storageChannel.invokeMethod<String>(
        'saveTextToDownloads',
        {
          'fileName': fileName,
          'content': content,
        },
      );
      SmartDialog.showToast('已保存至 ${savedPath ?? 'Download/$fileName'}');
    } on PlatformException catch (e) {
      SmartDialog.showToast('保存失败：${e.message ?? e.code}');
    } catch (e) {
      SmartDialog.showToast('保存失败：$e');
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
        title: const Text('上次 mpv 播放日志'),
        actions: [
          IconButton(
            tooltip: '保存至本地',
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_alt),
          ),
          IconButton(
            tooltip: '复制',
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
