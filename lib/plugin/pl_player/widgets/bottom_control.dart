import 'package:PiliPlus/common/widgets/progress_bar/audio_video_progress_bar.dart';
import 'package:PiliPlus/common/widgets/progress_bar/segment_progress_bar.dart';
import 'package:PiliPlus/pages/video/controller.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/view/view.dart';
import 'package:PiliPlus/plugin/pl_player/widgets/app_bar_ani.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:PiliPlus/utils/extension/theme_ext.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class BottomControl extends StatelessWidget {
  const BottomControl({
    super.key,
    required this.maxWidth,
    required this.isFullScreen,
    required this.controller,
    required this.buildBottomControl,
    required this.videoDetailController,
  });

  final double maxWidth;
  final bool isFullScreen;
  final PlPlayerController controller;
  final ValueGetter<Widget> buildBottomControl;
  final VideoDetailController videoDetailController;

  bool get _canShowPreview =>
      !controller.isFileSource &&
      controller.showSeekPreviewOnSlider &&
      (isFullScreen || controller.showSeekPreviewInNonFullscreen);

  void onDragStart(ThumbDragDetails duration) {
    feedBack();
    controller
      ..position.value = duration.seconds
      ..isSeeking.value = true;
    if (_canShowPreview) {
      controller.updatePreviewIndex(
        duration.seconds,
        globalX: duration.globalPosition.dx,
      );
    }
  }

  void onDragUpdate(ThumbDragDetails duration) {
    if (_canShowPreview) {
      controller.updatePreviewIndex(
        duration.seconds,
        globalX: duration.globalPosition.dx,
      );
    }
    controller.position.value = duration.seconds;
  }

  void onSeek(int milliseconds) {
    controller
      ..onSeekEnd()
      ..seekTo(Duration(milliseconds: milliseconds), isSeek: false);
  }

  String _formatProgressTime(int seconds, int totalSeconds) {
    final value = seconds < 0 ? 0 : seconds;
    if (totalSeconds < Duration.secondsPerHour) {
      return DurationUtils.formatDuration(value);
    }

    final totalHourDigits = (totalSeconds ~/ Duration.secondsPerHour)
        .toString()
        .length;
    final hourWidth = totalHourDigits < 2 ? 2 : totalHourDigits;
    final hours = value ~/ Duration.secondsPerHour;
    final minutes =
        (value % Duration.secondsPerHour) ~/ Duration.secondsPerMinute;
    final secondsLeft = value % Duration.secondsPerMinute;
    return '${hours.toString().padLeft(hourWidth, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${secondsLeft.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => PlayerControlBarBuilder(
    builder: _buildControl,
  );

  Widget _buildControl(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final primary = colorScheme.isLight
        ? colorScheme.inversePrimary
        : colorScheme.primary;
    final thumbGlowColor = primary.withAlpha(80);
    final bufferedBarColor = primary.withValues(alpha: 0.4);
    final officialTimeStyle = controller.biliProgressTimeStyle;
    final compact = officialTimeStyle && !isFullScreen;
    final thicknessScale = controller.playerControlBarThicknessScale;
    final outerBottomPadding = officialTimeStyle
        ? (compact ? 2.0 : 6.0) * thicknessScale
        : 12.0 * thicknessScale;
    // 原来进度条总边距为 compact 12dp、普通 20dp。按钮边距改为可配置后，
    // 进度条仍保持原有位置，不被按钮边距设置连带修改。
    final progressHorizontalPadding = compact ? 12.0 : 20.0;
    final progressBottomPadding = officialTimeStyle
        ? (compact ? 2.0 : 4.0) * thicknessScale
        : 7.0 * thicknessScale;
    final barHeight = officialTimeStyle ? (compact ? 2.5 : 3.0) : 3.5;
    final thumbRadius = officialTimeStyle ? (compact ? 5.0 : 6.0) : 7.0;
    final thumbGlowRadius = officialTimeStyle
        ? (compact ? 18.0 : 22.0)
        : 25.0;
    final overlayOffset = officialTimeStyle ? (compact ? 2.0 : 1.0) : 0.0;

    Widget buildProgressTime(
      String label,
      int seconds,
      int totalSeconds,
    ) {
      final time = _formatProgressTime(seconds, totalSeconds);
      return Text(
        time,
        maxLines: 1,
        semanticsLabel: '$label $time',
        style: TextStyle(
          color: Colors.white,
          fontSize: compact ? 10 : 11,
          height: 1,
        ),
      );
    }

    Widget buildProgressStack() => Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        Obx(
          () => ProgressBar(
            progress: controller.position.value,
            buffered: controller.buffered.value,
            total: controller.duration.value,
            progressBarColor: primary,
            baseBarColor: const Color(0x33FFFFFF),
            bufferedBarColor: bufferedBarColor,
            thumbColor: primary,
            thumbGlowColor: thumbGlowColor,
            barHeight: barHeight,
            thumbRadius: thumbRadius,
            thumbGlowRadius: thumbGlowRadius,
            onDragStart: onDragStart,
            onDragUpdate: onDragUpdate,
            onSeek: onSeek,
          ),
        ),
        if (controller.enableBlock &&
            videoDetailController.segmentProgressList.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: 5.25 - overlayOffset,
            child: SegmentProgressBar(
              segments: videoDetailController.segmentProgressList,
            ),
          ),
        if (controller.showViewPoints &&
            videoDetailController.viewPointList.isNotEmpty &&
            videoDetailController.showVP.value)
          Padding(
            padding: EdgeInsets.only(bottom: 8.75 - overlayOffset),
            child: Obx(
              () => ViewPointSegmentProgressBar(
                segments: videoDetailController.viewPointList,
                progress: controller.duration.value <= 0
                    ? 0.0
                    : controller.position.value / controller.duration.value,
                onSeek: PlatformUtils.isDesktop
                    ? (position) => controller.seekTo(position, isSeek: false)
                    : null,
              ),
            ),
          ),
        if (videoDetailController.showDmTrendChart.value)
          if (videoDetailController.dmTrend.value?.dataOrNull case final list?)
            buildDmChart(
              primary,
              list,
              videoDetailController,
              4.5 - overlayOffset,
            ),
      ],
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        0,
        0,
        0,
        outerBottomPadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              progressHorizontalPadding,
              0,
              progressHorizontalPadding,
              progressBottomPadding,
            ),
            child: Obx(
              () => Offstage(
                offstage: !controller.showControls.value,
                child: officialTimeStyle
                    ? Row(
                        children: [
                          buildProgressTime(
                            '当前时间',
                            controller.position.value,
                            controller.duration.value,
                          ),
                          SizedBox(width: compact ? 5 : 8),
                          Expanded(child: buildProgressStack()),
                          SizedBox(width: compact ? 5 : 8),
                          buildProgressTime(
                            '总时长',
                            controller.duration.value,
                            controller.duration.value,
                          ),
                        ],
                      )
                    : buildProgressStack(),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: controller.playerControlHorizontalPadding,
            ),
            child: buildBottomControl(),
          ),
        ],
      ),
    );
  }
}
