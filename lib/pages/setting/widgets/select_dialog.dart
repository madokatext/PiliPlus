import 'dart:async';

import 'package:PiliPlus/http/browser_ua.dart';
import 'package:PiliPlus/http/constants.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models/common/video/cdn_type.dart';
import 'package:PiliPlus/models/common/video/video_type.dart';
import 'package:PiliPlus/models/video/play/url.dart';
import 'package:PiliPlus/pages/setting/widgets/checkbox_num_list_tile.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/video_utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

class SelectDialog<T> extends StatelessWidget {
  final T? value;
  final String title;
  final List<(T, String)> values;
  final Widget Function(BuildContext, int)? subtitleBuilder;
  final bool toggleable;

  const SelectDialog({
    super.key,
    this.value,
    required this.values,
    required this.title,
    this.subtitleBuilder,
    this.toggleable = false,
  });

  @override
  Widget build(BuildContext context) {
    final titleMedium = TextTheme.of(context).titleMedium!;
    return AlertDialog(
      clipBehavior: Clip.hardEdge,
      title: Text(title),
      constraints: subtitleBuilder != null
          ? const BoxConstraints.tightFor(width: 320)
          : null,
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      content: Material(
        type: .transparency,
        child: SingleChildScrollView(
          child: RadioGroup<T>(
            onChanged: (v) => Navigator.of(context).pop(v ?? value),
            groupValue: value,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                values.length,
                (index) {
                  final item = values[index];
                  return RadioListTile<T>(
                    toggleable: toggleable,
                    dense: true,
                    value: item.$1,
                    title: Text(
                      item.$2,
                      style: titleMedium,
                    ),
                    subtitle: subtitleBuilder?.call(context, index),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CdnSelectDialog extends StatefulWidget {
  final BaseItem? sample;

  const CdnSelectDialog({
    super.key,
    this.sample,
  });

  @override
  State<CdnSelectDialog> createState() => _CdnSelectDialogState();
}

class _CdnSelectDialogState extends State<CdnSelectDialog> {
  late final List<ValueNotifier<String?>> _cdnResList;
  late final List<CancelToken?> _tokens;
  late final bool _cdnSpeedTest;
  late final Map<CDNService, int> _selected;

  @override
  void initState() {
    _selected = {
      for (final (index, service) in VideoUtils.cdnServices.indexed)
        service: index + 1,
    };
    _cdnSpeedTest = Pref.cdnSpeedTest;
    if (_cdnSpeedTest) {
      _dio =
          Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
              ),
            )
            ..options.headers = {
              'user-agent': BrowserUa.pc,
              'referer': HttpString.baseUrl,
            };
      final length = CDNService.values.length;
      _cdnResList = List.generate(
        length,
        (_) => ValueNotifier<String?>(null),
      );
      _tokens = List.generate(length, (_) => CancelToken());
      _startSpeedTest();
    }
    super.initState();
  }

  @override
  void dispose() {
    if (_cdnSpeedTest) {
      for (final e in _tokens) {
        e?.cancel();
      }
      for (final notifier in _cdnResList) {
        notifier.dispose();
      }
      _dio.close(force: true);
    }
    super.dispose();
  }

  Future<BaseItem> _getSampleUrl() async {
    final result = await VideoHttp.videoUrl(
      cid: 196018899,
      bvid: 'BV1fK4y1t7hj',
      tryLook: false,
      videoType: VideoType.ugc,
    );
    final item = result.dataOrNull?.dash?.video?.first;
    if (item == null) throw Exception('无法获取视频流');
    return item;
  }

  Future<void> _startSpeedTest() async {
    try {
      final videoItem = widget.sample ?? await _getSampleUrl();
      await _testAllCdnServices(videoItem);
    } catch (e) {
      if (kDebugMode) debugPrint('CDN speed test failed: $e');
    }
  }

  Future<void> _testAllCdnServices(BaseItem videoItem) async {
    for (final item in CDNService.values) {
      if (!mounted) break;
      await _testSingleCdn(item, videoItem);
    }
  }

  Future<void> _testSingleCdn(CDNService item, BaseItem videoItem) async {
    try {
      final cdnUrl = VideoUtils.getCdnUrl(
        videoItem.playUrls,
        defaultCDNService: item,
      );
      await _measureDownloadSpeed(cdnUrl, item.index);
    } catch (e) {
      _handleSpeedTestError(e, item.index);
    }
  }

  late final Dio _dio;

  Future<void> _measureDownloadSpeed(String url, int index) async {
    const maxSize = 8 * 1024 * 1024;
    int downloaded = 0;

    final cancelToken = _tokens[index];
    final start = DateTime.now().microsecondsSinceEpoch;

    void onClose() {
      cancelToken?.cancel();
      _tokens[index] = null;
    }

    await _dio.get(
      url,
      cancelToken: cancelToken,
      onReceiveProgress: (count, total) {
        if (!mounted) {
          return;
        }

        final duration = DateTime.now().microsecondsSinceEpoch - start;

        downloaded += count;

        if (duration > 15000000) {
          onClose();
          if (downloaded > 0) {
            _updateSpeedResult(index, downloaded, duration);
            downloaded = 0;
          } else {
            throw TimeoutException('测速超时');
          }
        } else if (downloaded >= maxSize) {
          onClose();
          _updateSpeedResult(index, downloaded, duration);
          downloaded = 0;
        }
      },
    );
  }

  void _updateSpeedResult(int index, int downloaded, int duration) {
    final speed = (downloaded / duration).toStringAsPrecision(3);
    _cdnResList[index].value = '${speed}MB/s';
  }

  void _handleSpeedTestError(dynamic error, int index) {
    _tokens
      ..[index]?.cancel()
      ..[index] = null;
    final item = _cdnResList[index];
    if (item.value != null) return;

    if (kDebugMode) debugPrint('CDN speed test error: $error');
    if (!mounted) return;
    String message;
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      if (statusCode != null && 400 <= statusCode && statusCode < 500) {
        message = '此视频可能无法替换为该CDN';
      } else {
        message = error.toString();
      }
    } else {
      message = error.toString();
    }
    if (message.isEmpty) {
      message = '测速失败';
    }
    item.value = message;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      clipBehavior: Clip.hardEdge,
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CDN 设置'),
          SizedBox(height: 4),
          Text(
            '新视频按勾选顺序轮换；无法播放时退出重开即可尝试下一个 CDN，最多选择 3 个',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.normal),
          ),
        ],
      ),
      constraints: _cdnSpeedTest
          ? const BoxConstraints.tightFor(width: 320)
          : null,
      contentPadding: const EdgeInsets.only(top: 12),
      content: Material(
        type: MaterialType.transparency,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: CDNService.values.map((service) {
              final order = _selected[service];
              return OrderedCheckboxListTile(
                dense: true,
                value: order,
                title: Text(
                  service.desc,
                  style: theme.textTheme.titleMedium,
                ),
                subtitle: _cdnSpeedTest
                    ? ValueListenableBuilder(
                        valueListenable: _cdnResList[service.index],
                        builder: (context, value, _) => Text(
                          value ?? '---',
                          style: const TextStyle(fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    : null,
                onChanged: (_) {
                  if (order == null) {
                    if (_selected.length == 3) {
                      SmartDialog.showToast('最多选择 3 个 CDN');
                      return;
                    }
                    setState(() {
                      _selected[service] = _selected.length + 1;
                    });
                    return;
                  }
                  if (_selected.length == 1) {
                    SmartDialog.showToast('至少保留 1 个 CDN');
                    return;
                  }
                  setState(() {
                    _selected.remove(service);
                    _selected.updateAll(
                      (key, value) => value > order ? value - 1 : value,
                    );
                  });
                },
              );
            }).toList(),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            '取消',
            style: TextStyle(color: theme.colorScheme.outline),
          ),
        ),
        TextButton(
          onPressed: () {
            final ordered = _selected.entries.toList()
              ..sort((a, b) => a.value.compareTo(b.value));
            Navigator.of(context).pop(
              ordered.map((item) => item.key).toList(growable: false),
            );
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}
