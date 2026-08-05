import 'dart:async';
import 'dart:math' as math;

import 'package:PiliPlus/pages/video/controller.dart';
import 'package:PiliPlus/pages/video/stein_progress_debug.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PlayerInstanceStatusOverlay extends StatefulWidget {
  const PlayerInstanceStatusOverlay({
    required this.controller,
    required this.maxWidth,
    required this.maxHeight,
    this.videoDetailController,
    super.key,
  });

  final PlPlayerController controller;
  final VideoDetailController? videoDetailController;
  final double maxWidth;
  final double maxHeight;

  @override
  State<PlayerInstanceStatusOverlay> createState() =>
      _PlayerInstanceStatusOverlayState();
}

class _PlayerInstanceStatusOverlayState
    extends State<PlayerInstanceStatusOverlay> {
  late final bool _showPlayerInstances = Pref.showPlayerInstanceStatus;
  late final bool _showSteinProgress =
      Pref.showSteinProgressDebug && widget.videoDetailController != null;
  final RxInt _revision = 0.obs;
  final ScrollController _steinLogScrollController = ScrollController();
  SteinProgressDebugEvent? _latestSteinDebugEvent;
  bool _steinLogScrollScheduled = false;
  Timer? _timer;

  void _scrollSteinLogToLatest(List<SteinProgressDebugEvent> events) {
    final latestEvent = events.isEmpty ? null : events.first;
    if (latestEvent == null || identical(latestEvent, _latestSteinDebugEvent)) {
      return;
    }
    _latestSteinDebugEvent = latestEvent;
    if (_steinLogScrollScheduled) return;
    _steinLogScrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _steinLogScrollScheduled = false;
      if (!mounted || !_steinLogScrollController.hasClients) return;
      _steinLogScrollController.jumpTo(
        _steinLogScrollController.position.maxScrollExtent,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    if (_showPlayerInstances) {
      _timer = Timer.periodic(
        const Duration(milliseconds: 200),
        (_) => _revision.value++,
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _steinLogScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showPlayerInstances && !_showSteinProgress) {
      return const SizedBox.shrink();
    }

    final overlay = Align(
      alignment: const Alignment(-0.72, 0),
      child: Obx(() {
          _revision.value;
          final controller = widget.controller;
          final videoController = widget.videoDetailController;
          final statuses = _showPlayerInstances
              ? controller.playerInstanceGateStatuses
              : null;
          if (_showPlayerInstances) {
            controller.videoOutputRevision.value;
            controller.dataStatus.value;
          }

          final debugEvents = _showSteinProgress
              ? videoController!.steinProgressDebugEvents.toList(
                  growable: false,
                )
              : const <SteinProgressDebugEvent>[];
          if (_showSteinProgress) {
            _scrollSteinLogToLatest(debugEvents);
          }

          Color conditionColor(PlayerGateConditionState state) =>
              switch (state) {
                .met => const Color(0xFF8DE5A1),
                .waiting => const Color(0xFFFFD166),
                .bypassed => const Color(0xFFB9C2CC),
                .failed => const Color(0xFFFF7B7B),
              };

          String conditionPrefix(PlayerGateConditionState state) =>
              switch (state) {
                .met => '✓',
                .waiting => '○',
                .bypassed => '↷',
                .failed => '×',
              };

          Color debugColor(SteinProgressDebugLevel level) => switch (level) {
            .info => const Color(0xFFD5D9DE),
            .success => const Color(0xFF8DE5A1),
            .warning => const Color(0xFFFFD166),
            .error => const Color(0xFFFF7B7B),
          };

          String debugPrefix(SteinProgressDebugLevel level) => switch (level) {
            .info => '○',
            .success => '✓',
            .warning => '!',
            .error => '×',
          };

          String formatTime(DateTime time) =>
              '${time.hour.toString().padLeft(2, '0')}:'
              '${time.minute.toString().padLeft(2, '0')}:'
              '${time.second.toString().padLeft(2, '0')}.'
              '${time.millisecond.toString().padLeft(3, '0')}';

          Widget buildInstanceStatus(int index) {
            final status = statuses![index];
            final cdn = index == 0
                ? controller.mainPlayerCdnName
                : controller.standbyPlayerCdnName;
            final hasSource = index == 0
                ? controller.mainPlayerHasVideoSource
                : controller.standbyPlayerHasVideoSource;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${status.name} [${cdn ?? '--'}] · ${hasSource ? '已加载视频源' : '未加载视频源'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${status.playerState} · ${status.gateState}',
                  style: const TextStyle(
                    color: Color(0xFFD5D9DE),
                    fontSize: 9,
                  ),
                ),
                if (status.conditions.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 3,
                    children: status.conditions.map((condition) {
                      final detail = condition.detail;
                      return Text(
                        '${conditionPrefix(condition.state)} ${condition.label}${detail == null ? '' : ' $detail'}',
                        style: TextStyle(
                          color: conditionColor(condition.state),
                          fontSize: 9,
                          fontFamily: 'Monospace',
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            );
          }

          Widget buildSteinStatus() {
            final progressCount = videoController!.steinProgressList.length;
            final storyCount =
                videoController.steinEdgeInfo?.storyList?.length ?? 0;
            final questionCount =
                videoController.steinEdgeInfo?.edges?.questions?.length ?? 0;
            final cid = videoController.cid.value;
            videoController.showSteinEdgeInfo.value;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '互动视频历史进度链路',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  videoController.steinProgressDebugState,
                  style: const TextStyle(
                    color: Color(0xFFD5D9DE),
                    fontSize: 9,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'bvid=${videoController.bvid} · cid=$cid · graph=${videoController.graphVersion ?? '--'} · '
                  '互动=${videoController.isInteractiveVideo} · 请求中=${videoController.isQuerying}',
                  style: const TextStyle(
                    color: Color(0xFFB9C2CC),
                    fontSize: 9,
                    fontFamily: 'Monospace',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'story=$storyCount · 有效进度=$progressCount · questions=$questionCount · '
                  '选择中=${videoController.selectingSteinChoice} · '
                  '回溯定位=${videoController.seekSteinProgressToEnd} · '
                  'seek=${videoController.defaultST?.inMilliseconds ?? '--'}ms',
                  style: const TextStyle(
                    color: Color(0xFFB9C2CC),
                    fontSize: 9,
                    fontFamily: 'Monospace',
                  ),
                ),
              ],
            );
          }

          Widget buildSteinLog() {
            if (debugEvents.isEmpty) {
              return const Text(
                '等待链路事件',
                style: TextStyle(
                  color: Color(0xFFFFD166),
                  fontSize: 9,
                  fontFamily: 'Monospace',
                ),
              );
            }
            return Scrollbar(
              controller: _steinLogScrollController,
              child: SingleChildScrollView(
                controller: _steinLogScrollController,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: debugEvents.reversed
                      .map(
                        (event) => Padding(
                          padding: const EdgeInsets.only(bottom: 5, right: 8),
                          child: Text.rich(
                            TextSpan(
                              style: const TextStyle(
                                color: Color(0xFFD5D9DE),
                                fontSize: 9,
                                fontFamily: 'Monospace',
                                height: 1.2,
                              ),
                              children: [
                                TextSpan(
                                  text:
                                      '${debugPrefix(event.level)} ${formatTime(event.time)} ${event.stage}\n',
                                  style: TextStyle(
                                    color: debugColor(event.level),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                TextSpan(text: event.detail),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            );
          }

          return Container(
            constraints: BoxConstraints(
              maxWidth: math.min(widget.maxWidth * 0.9, 620),
              maxHeight: widget.maxHeight * 0.96,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.72),
              borderRadius: const BorderRadius.all(Radius.circular(7)),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_showPlayerInstances) ...[
                  buildInstanceStatus(0),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 5),
                    child: Divider(height: 1, color: Colors.white24),
                  ),
                  buildInstanceStatus(1),
                ],
                if (_showPlayerInstances && _showSteinProgress)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 5),
                    child: Divider(height: 1, color: Colors.white24),
                  ),
                if (_showSteinProgress) ...[
                  buildSteinStatus(),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 5),
                    child: Divider(height: 1, color: Colors.white24),
                  ),
                  Flexible(child: buildSteinLog()),
                ],
              ],
            ),
          );
      }),
    );
    return _showSteinProgress ? overlay : IgnorePointer(child: overlay);
  }
}
