import 'dart:async';
import 'dart:math' as math;

import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PlayerInstanceStatusOverlay extends StatefulWidget {
  const PlayerInstanceStatusOverlay({
    required this.controller,
    required this.maxWidth,
    required this.maxHeight,
    super.key,
  });

  final PlPlayerController controller;
  final double maxWidth;
  final double maxHeight;

  @override
  State<PlayerInstanceStatusOverlay> createState() =>
      _PlayerInstanceStatusOverlayState();
}

class _PlayerInstanceStatusOverlayState
    extends State<PlayerInstanceStatusOverlay> {
  late final bool _show = Pref.showPlayerInstanceStatus;
  final RxInt _revision = 0.obs;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (_show) {
      _timer = Timer.periodic(
        const Duration(milliseconds: 200),
        (_) => _revision.value++,
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: Align(
        alignment: const Alignment(-0.72, 0),
        child: Obx(() {
          _revision.value;
          final controller = widget.controller;
          controller.videoOutputRevision.value;
          controller.dataStatus.value;
          final statuses = controller.playerInstanceGateStatuses;
          final cdns = [
            controller.mainPlayerCdnName ?? '--',
            controller.standbyPlayerCdnName ?? '--',
          ];
          final hasSources = [
            controller.mainPlayerHasVideoSource,
            controller.standbyPlayerHasVideoSource,
          ];

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

          Widget buildInstanceStatus(int index) {
            final status = statuses[index];
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${status.name} [${cdns[index]}] · ${hasSources[index] ? '已疯狂搬赛博粮电子榨菜源' : '未疯狂搬赛博粮电子榨菜源'}',
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
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildInstanceStatus(0),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 5),
                    child: Divider(height: 1, color: Colors.white24),
                  ),
                  buildInstanceStatus(1),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
