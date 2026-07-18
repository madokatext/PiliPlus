import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/models/video_fit_type.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

const _itemTextStyle = TextStyle(color: Colors.white, fontSize: 13);

class PlayerFitButton extends StatelessWidget {
  const PlayerFitButton({
    super.key,
    required this.controller,
    required this.height,
  });

  final PlPlayerController controller;
  final double height;

  @override
  Widget build(BuildContext context) => Obx(() {
    final fit = controller.videoFit.value;
    return PopupMenuButton<VideoFitType>(
      tooltip: '画面比例',
      requestFocus: false,
      initialValue: fit,
      color: Colors.black.withValues(alpha: 0.8),
      itemBuilder: (context) => VideoFitType.values
          .map(
            (boxFit) => PopupMenuItem<VideoFitType>(
              height: 35,
              padding: const EdgeInsets.only(left: 30),
              value: boxFit,
              onTap: () => controller.toggleVideoFit(boxFit),
              child: Text(boxFit.desc, style: _itemTextStyle),
            ),
          )
          .toList(),
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Center(
            child: Text(fit.desc, style: _itemTextStyle),
          ),
        ),
      ),
    );
  });
}

class PlayerSpeedButton extends StatelessWidget {
  const PlayerSpeedButton({
    super.key,
    required this.controller,
    required this.height,
  });

  final PlPlayerController controller;
  final double height;

  @override
  Widget build(BuildContext context) => Obx(
    () => PopupMenuButton<double>(
      tooltip: '倍速',
      requestFocus: false,
      initialValue: controller.playbackSpeed,
      color: Colors.black.withValues(alpha: 0.8),
      itemBuilder: (context) => controller.speedList
          .map(
            (speed) => PopupMenuItem<double>(
              height: 35,
              padding: const EdgeInsets.only(left: 30),
              value: speed,
              onTap: () => controller.setPlaybackSpeed(speed),
              child: Text(
                '${speed}X',
                style: _itemTextStyle,
                semanticsLabel: '$speed倍速',
              ),
            ),
          )
          .toList(),
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Center(
            child: Text(
              '${controller.playbackSpeed}X',
              style: _itemTextStyle,
              semanticsLabel: '${controller.playbackSpeed}倍速',
            ),
          ),
        ),
      ),
    ),
  );
}
