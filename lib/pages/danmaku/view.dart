import 'dart:convert';
import 'package:PiliPlus/models/common/danmaku_merge_mode.dart';
import 'package:PiliPlus/pages/danmaku/burst_danmaku_aggregator.dart';
import 'package:PiliPlus/utils/local_font_manager.dart';
import 'package:PiliPlus/grpc/bilibili/community/service/dm/v1.pb.dart';
import 'package:PiliPlus/pages/danmaku/controller.dart';
import 'package:PiliPlus/pages/danmaku/danmaku_model.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/models/play_status.dart';
import 'package:PiliPlus/plugin/pl_player/utils/danmaku_options.dart';
import 'package:PiliPlus/utils/danmaku_utils.dart';
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 传入播放器控制器，监听播放进度，加载对应弹幕
class PlDanmaku extends StatefulWidget {
  final int cid;
  final PlPlayerController playerController;
  final bool isPipMode;
  final bool isFullScreen;
  final bool isFileSource;
  final Size size;

  const PlDanmaku({
    super.key,
    required this.cid,
    required this.playerController,
    this.isPipMode = false,
    required this.isFullScreen,
    required this.isFileSource,
    required this.size,
  });

  @override
  State<PlDanmaku> createState() => _PlDanmakuState();

  bool get notFullscreen => !isFullScreen || isPipMode;
}

class _PlDanmakuState extends State<PlDanmaku> {
  PlPlayerController get playerController => widget.playerController;

  late final PlDanmakuController _plDanmakuController;
  DanmakuController<DanmakuExtra>? _controller;
  int latestAddedPosition = -1;
  final BurstDanmakuAggregator _burstAggregator =
    BurstDanmakuAggregator();

List<BurstDanmakuSnapshot> _burstSnapshots = const [];

int? _lastBurstPositionMs;

  @override
  void initState() {
    super.initState();
    _plDanmakuController = PlDanmakuController(
      widget.cid,
      playerController,
      widget.isFileSource,
    );
    if (playerController.enableShowDanmaku.value) {
      if (widget.isFileSource) {
        _plDanmakuController.initFileDmIfNeeded();
      } else {
        _plDanmakuController.queryDanmaku(
          PlDanmakuController.calcSegment(
            playerController.positionInMilliseconds,
          ),
        );
      }
    }
        playerController
      ..addStatusLister(playerListener)
      ..addPositionListener(videoPositionListen);

    playerController.onDanmakuMergeSettingsChanged =
        _handleDanmakuMergeSettingsChanged;
  }

  void _handleDanmakuMergeSettingsChanged(bool reset) {
    if (reset) {
      _burstAggregator.reset();
      _lastBurstPositionMs = null;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _burstSnapshots = _burstAggregator.activeSnapshots;
    });
  }

  @override
  void didUpdateWidget(PlDanmaku oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.notFullscreen != widget.notFullscreen &&
        !DanmakuOptions.sameFontScale) {
      _controller?.updateOption(
        DanmakuOptions.get(notFullscreen: widget.notFullscreen),
      );
    }
  }

  // 播放器状态监听
  void playerListener(PlayerStatus status) {
    if (_controller case final controller?) {
      if (status.isPlaying) {
        controller.resume();
      } else {
        controller.pause();
      }
    }
  }
bool _canUseBurstMerge(DanmakuElem element) {
  if (element.isSelf) {
    return false;
  }

  final type = DmUtils.getPosition(element.mode);

  return switch (type) {
    DanmakuItemType.scroll =>
      !DanmakuOptions.blockTypes.contains(2),
    DanmakuItemType.top =>
      !DanmakuOptions.blockTypes.contains(5),
    DanmakuItemType.bottom =>
      !DanmakuOptions.blockTypes.contains(4),
    DanmakuItemType.special => false,
  };
}

void _refreshBurstOverlay(bool changed) {
  if (!changed || !mounted) {
    return;
  }

  setState(() {
    _burstSnapshots = _burstAggregator.activeSnapshots;
  });
}
  @pragma('vm:notify-debugger-on-exception')
void videoPositionListen(Duration position) {
  if (_controller == null ||
      !playerController.enableShowDanmaku.value) {
    return;
  }

  if (!playerController.showDanmaku &&
      !widget.isPipMode) {
    return;
  }

  if (!playerController.playerStatus.isPlaying) {
    return;
  }

  var currentPosition = position.inMilliseconds;

  // 弹幕数据以 100ms 为一个索引单位。
  currentPosition -= currentPosition % 100;

  if (currentPosition == latestAddedPosition) {
    return;
  }

  latestAddedPosition = currentPosition;

  final mergeMode = DanmakuOptions.mergeMode;

  final windowMs =
      (DanmakuOptions.burstDanmakuWindowSeconds * 1000)
          .round();

  final cooldownMs =
      (DanmakuOptions.burstDanmakuCooldownSeconds * 1000)
          .round();

  var burstChanged = false;

  if (mergeMode == DanmakuMergeMode.burst) {
    final previousPosition = _lastBurstPositionMs;

    // 向后拖动时，旧时间点中的统计不能带到新的时间线。
    if (previousPosition != null &&
        currentPosition < previousPosition) {
      _burstAggregator.reset();
      burstChanged = _burstSnapshots.isNotEmpty;
    }

    _lastBurstPositionMs = currentPosition;

    // 即使当前 100ms 没有弹幕，也要推进冷却计时。
    burstChanged = _burstAggregator.advance(
          progressMs: currentPosition,
          windowMs: windowMs,
          cooldownMs: cooldownMs,
        ) ||
        burstChanged;
  } else {
    _lastBurstPositionMs = null;

    // 从高频模式切换到其它模式时移除顶部聚合层。
    if (!_burstAggregator.isEmpty ||
        _burstSnapshots.isNotEmpty) {
      _burstAggregator.reset();
      burstChanged = true;
    }
  }

  final currentDanmakuList =
      _plDanmakuController.getCurrentDanmaku(
    currentPosition,
    mergeMode,
  );

  if (currentDanmakuList == null) {
    _refreshBurstOverlay(burstChanged);
    return;
  }

  final blockColorful = DanmakuOptions.blockColorful;
  final danmakuWeight = DanmakuOptions.danmakuWeight;
  final highLikeThreshold =
      DanmakuOptions.highLikeDanmakuThreshold;

  for (final element in currentDanmakuList) {
    // 必须是 continue，不能使用原代码中的 return。
    // return 会导致同一 100ms 批次后面的所有弹幕都被跳过。
    if (element.weight < danmakuWeight) {
      continue;
    }

    final likeCount = element.likeCount.toInt();

    final showLikeIcon =
        highLikeThreshold > 0 &&
        likeCount >= highLikeThreshold;

    final effectiveColor = blockColorful
        ? Colors.white
        : DmUtils.decimalToColor(element.color);

    if (mergeMode == DanmakuMergeMode.burst &&
        _canUseBurstMerge(element)) {
      final suppressNormalDanmaku =
          _burstAggregator.add(
        text: element.content,
        color: effectiveColor,
        progressMs: currentPosition,
        triggerCount:
            DanmakuOptions.burstDanmakuTriggerCount,
        windowMs: windowMs,
      );

      if (suppressNormalDanmaku) {
        // 当前条刚好达到阈值，或者该文本已经处于聚合状态。
        // 此时只更新顶部计数，不再作为普通弹幕加入画布。
        burstChanged = true;
        continue;
      }
    }

    if (element.mode == 7) {
      try {
        _controller!.addDanmaku(
          SpecialDanmakuContentItem.fromList(
            effectiveColor,
            element.fontsize.toDouble(),
            jsonDecode(
              element.content.replaceAll('\n', '\\n'),
            ),
            showLikeIcon: showLikeIcon,
            extra: VideoDanmaku(
              id: element.id.toInt(),
              mid: element.midHash,
              like: likeCount,
            ),
          ),
        );
      } catch (_) {}

      continue;
    }

    _controller!.addDanmaku(
      DanmakuContentItem(
        element.content,
        color: effectiveColor,
        type: DmUtils.getPosition(element.mode),
        isColorful:
            playerController.showVipDanmaku &&
            element.colorful ==
                DmColorfulType.VipGradualColor,
        count: element.count > 1
            ? element.count
            : null,
        selfSend: element.isSelf,
        showLikeIcon: showLikeIcon,
        extra: VideoDanmaku(
          id: element.id.toInt(),
          mid: element.midHash,
          like: likeCount,
        ),
      ),
    );
  }

  _refreshBurstOverlay(burstChanged);
}

  @override
void dispose() {
  playerController.onDanmakuMergeSettingsChanged = null;

  _burstAggregator.reset();
  _burstSnapshots = const [];
  _lastBurstPositionMs = null;

  playerController
    ..removePositionListener(videoPositionListen)
    ..removeStatusLister(playerListener);

  _plDanmakuController.dispose();
  _controller = null;

  super.dispose();
}

  @override
Widget build(BuildContext context) {
  final option = DanmakuOptions.get(
    notFullscreen: widget.notFullscreen,
    speed: playerController.playbackSpeed,
  );

  return Obx(
    () => AnimatedOpacity(
      opacity: playerController.enableShowDanmaku.value
          ? playerController.danmakuOpacity.value
          : 0,
      duration: const Duration(milliseconds: 100),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DanmakuScreen<DanmakuExtra>(
            createdController: (controller) {
              playerController.danmakuController =
                  _controller = controller;
            },
            option: option,
            size: widget.size,
          ),
          if (DanmakuOptions.mergeMode ==
                  DanmakuMergeMode.burst &&
              _burstSnapshots.isNotEmpty)
            _BurstDanmakuOverlay(
              snapshots: _burstSnapshots,
              notFullscreen: widget.notFullscreen,
            ),
        ],
      ),
    ),
  );
}
}
class _BurstDanmakuOverlay extends StatelessWidget {
  const _BurstDanmakuOverlay({
    required this.snapshots,
    required this.notFullscreen,
  });

  final List<BurstDanmakuSnapshot> snapshots;
  final bool notFullscreen;

  @override
  Widget build(BuildContext context) {
    final option = DanmakuOptions.get(
      notFullscreen: notFullscreen,
    );

    final fontSize =
        option.fontSize *
        DanmakuOptions.burstDanmakuFontScale;

    final fontFamilies =
        LocalFontManager.danmakuFontFamilies;

    // 数字明确优先使用用户设置的弹幕英文字体。
    // 未设置英文字体时，退回当前弹幕的 Latin 主字体。
    final englishFontFamily =
        LocalFontManager.familyFor(
          LocalFontSlot.danmakuEnglish,
        ) ??
        fontFamilies.primary;

    final fontWeightIndex =
        DanmakuOptions.danmakuFontWeight
            .clamp(
              0,
              FontWeight.values.length - 1,
            )
            .toInt();

    final strokeWidth = option.strokeWidth;

final strokePaint = strokeWidth > 0
    ? (Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth)
    : null;

TextSpan buildSpan(
  BurstDanmakuSnapshot snapshot, {
  required bool stroke,
}) {
  return TextSpan(
    style: TextStyle(
      color: stroke ? null : snapshot.color,
      foreground: stroke ? strokePaint : null,
      fontSize: fontSize,
      fontWeight: FontWeight.values[fontWeightIndex],
      fontStyle: FontStyle.normal,
      fontFamily: fontFamilies.primary,
      fontFamilyFallback: fontFamilies.fallback,
    ),
    children: [
      TextSpan(
        text: snapshot.text,
      ),
      const TextSpan(
        // U+00D7：真正的乘号，不是字母 x。
        text: ' × ',
        style: TextStyle(
          fontWeight: FontWeight.normal,
          fontStyle: FontStyle.normal,
        ),
      ),
      TextSpan(
        text: snapshot.count.toString(),
        style: TextStyle(
          fontFamily: englishFontFamily,
          fontFamilyFallback: fontFamilies.fallback,
          fontWeight: FontWeight.bold,
          fontStyle: FontStyle.italic,
        ),
      ),
    ],
  );
}

Widget buildText(
  BurstDanmakuSnapshot snapshot, {
  required bool stroke,
}) {
  return Text.rich(
    buildSpan(
      snapshot,
      stroke: stroke,
    ),
    textAlign: TextAlign.center,
    maxLines: 1,
    softWrap: false,
    overflow: TextOverflow.fade,
  );
}

    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: FractionallySizedBox(
          widthFactor: 0.96,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final snapshot in snapshots)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(
                      vertical: 2,
                    ),
                    child: Padding(
  // 普通弹幕会给描边预留 strokeWidth / 2 的外扩空间。
  padding: EdgeInsets.all(strokeWidth / 2),
  child: Stack(
    alignment: Alignment.center,
    clipBehavior: Clip.none,
    children: [
      if (strokePaint != null)
        buildText(
          snapshot,
          stroke: true,
        ),
      buildText(
        snapshot,
        stroke: false,
      ),
    ],
  ),
),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
