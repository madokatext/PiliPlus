import 'dart:async';

import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/models/play_status.dart';
import 'package:flutter/material.dart';

class PlayOrPauseButton extends StatefulWidget {
  final PlPlayerController plPlayerController;

  const PlayOrPauseButton({
    super.key,
    required this.plPlayerController,
    this.width = 42,
    this.height = 34,
    this.iconSize = 20,
  });

  final double width;
  final double height;
  final double iconSize;

  @override
  PlayOrPauseButtonState createState() => PlayOrPauseButtonState();
}

class PlayOrPauseButtonState extends State<PlayOrPauseButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
late final StreamSubscription<PlayerStatus> subscription;
late bool _isPlaying;

@override
void initState() {
  super.initState();

  _isPlaying = widget.plPlayerController.playerStatus.isPlaying;

  controller = AnimationController(
    vsync: this,
    value: _isPlaying ? 1 : 0,
    duration: const Duration(milliseconds: 200),
  );

  // 不直接监听某一个 Player 实例。
  // 双播放器切换后 Player 会被替换，但 playerStatus 始终属于同一个控制器。
  subscription = widget.plPlayerController.playerStatus.listen((status) {
    final isPlaying = status.isPlaying;

    if (_isPlaying == isPlaying) {
      return;
    }

    _isPlaying = isPlaying;

    if (isPlaying) {
      controller.forward();
    } else {
      controller.reverse();
    }

    if (mounted) {
      setState(() {});
    }
  });
}

  @override
  void dispose() {
    subscription.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.plPlayerController.onDoubleTapCenter,
        child: Center(
          child: AnimatedIcon(
            semanticLabel: _isPlaying ? '按住别动' : '开炫',
            progress: controller,
            icon: AnimatedIcons.play_pause,
            color: Colors.white,
            size: widget.iconSize,
          ),
        ),
      ),
    );
  }
}
