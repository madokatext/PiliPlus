import 'dart:async';

import 'package:PiliPlus/common/assets.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:PiliPlus/utils/extension/num_ext.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class PlayerBufferingOverlay extends StatefulWidget {
  const PlayerBufferingOverlay({
    required this.controller,
    this.forceVisible = false,
    super.key,
  });

  final PlPlayerController controller;
  final bool forceVisible;

  @override
  State<PlayerBufferingOverlay> createState() =>
      _PlayerBufferingOverlayState();
}

class _PlayerBufferingOverlayState extends State<PlayerBufferingOverlay> {
  late final bool _showBufferingInfo = Pref.showBufferingInfo;
  final RxBool _hasValidBufferingSpeed = false.obs;
  final RxString _bufferingSpeed = '--/s'.obs;
  Timer? _bufferingSpeedTimer;

  bool get _isVisible =>
      widget.forceVisible || widget.controller.shouldShowBufferingOverlay;

  static String _formatBufferSize(num bytes) {
    if (!bytes.isFinite || bytes < 0) {
      return '--';
    }

    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }

    final fractionDigits = unitIndex == 0
        ? 0
        : value >= 100
        ? 0
        : value >= 10
        ? 1
        : 2;
    return '${value.toStringAsFixed(fractionDigits)} ${units[unitIndex]}';
  }

  num? _readBufferingSpeed() {
    final players = [
      widget.controller.videoPlayerController,
      widget.controller.standbyVideoPlayerController,
    ];
    for (final player in players) {
      if (player == null) {
        continue;
      }
      try {
        final cacheSpeed = double.tryParse(
          player.getProperty('cache-speed').trim(),
        );
        if (cacheSpeed == null ||
            !cacheSpeed.isFinite ||
            cacheSpeed < 0) {
          continue;
        }
        return cacheSpeed;
      } catch (_) {
        // 主实例尚未提供有效速度时继续尝试备用实例。
      }
    }
    return null;
  }

  void _updateBufferingSpeed() {
    if (!_showBufferingInfo || !_isVisible) {
      _bufferingSpeed.value = '--/s';
      _hasValidBufferingSpeed.value = false;
      return;
    }

    final cacheSpeed = _readBufferingSpeed();
    if (cacheSpeed == null) {
      _bufferingSpeed.value = '--/s';
      _hasValidBufferingSpeed.value = false;
      return;
    }

    _bufferingSpeed.value = '${_formatBufferSize(cacheSpeed)}/s';
    _hasValidBufferingSpeed.value = true;
  }

  @override
  void initState() {
    super.initState();
    if (_showBufferingInfo) {
      _updateBufferingSpeed();
      _bufferingSpeedTimer = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => _updateBufferingSpeed(),
      );
    }
  }

  @override
  void dispose() {
    _bufferingSpeedTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Obx(() {
    if (!_isVisible) {
      return const SizedBox.shrink();
    }

    return Center(
      child: GestureDetector(
        onTap: widget.controller.refreshPlayer,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [Colors.black26, Colors.transparent],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                Assets.buffering,
                height: 25,
                cacheHeight: 25.cacheSize(context),
                semanticLabel: '加载中',
                color: Colors.white,
              ),
              if (_showBufferingInfo)
                if (_hasValidBufferingSpeed.value) ...[
                  Text(
                    DurationUtils.formatDuration(
                      widget.controller.buffered.value,
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    _bufferingSpeed.value,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ] else
                  const Text(
                    '加载中',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  )
              else if (widget.controller.isBuffering.value)
                Text(
                  widget.controller.buffered.value == 0
                      ? '加载中...'
                      : DurationUtils.formatDuration(
                          widget.controller.buffered.value,
                        ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  });
}
