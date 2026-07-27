import 'dart:async';
import 'dart:math' as math;

import 'package:PiliPlus/plugin/pl_player/models/video_fit_type.dart';
import 'package:PiliPlus/utils/mpv_utils.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

typedef MpvVideoTransform = ({double zoom, double panX, double panY});

@visibleForTesting
MpvVideoTransform calculateMpvVideoTransform({
  required Matrix4 matrix,
  required Size viewportSize,
  required Size fittedVideoSize,
  required Alignment alignment,
}) {
  final scale = matrix.getMaxScaleOnAxis().clamp(0.01, 100.0);
  final translation = matrix.getTranslation();
  final alignmentOrigin = Offset(
    viewportSize.width * (alignment.x + 1) / 2,
    viewportSize.height * (alignment.y + 1) / 2,
  );
  // InteractiveViewer scales from the viewport's top-left, while mpv zooms
  // from the configured video alignment point.
  final originCompensation = alignmentOrigin * (scale - 1);

  return (
    zoom: math.log(scale) / math.ln2,
    panX:
        (translation.x + originCompensation.dx) /
        (fittedVideoSize.width * scale),
    panY:
        (translation.y + originCompensation.dy) /
        (fittedVideoSize.height * scale),
  );
}

class MpvVideoOutput extends StatefulWidget {
  const MpvVideoOutput({
    required this.controller,
    required this.fit,
    required this.fill,
    required this.alignment,
    required this.transformationController,
    this.waitForResizeFrame = false,
    super.key,
  });

  final VideoController controller;
  final VideoFitType fit;
  final Color fill;
  final Alignment alignment;
  final TransformationController transformationController;
  final bool waitForResizeFrame;

  @override
  State<MpvVideoOutput> createState() => _MpvVideoOutputState();
}

class _MpvVideoOutputState extends State<MpvVideoOutput> {
  StreamSubscription<(int, int)>? _sizeSubscription;
  late int _sourceWidth;
  late int _sourceHeight;
  _MpvOutputConfiguration? _pendingConfiguration;
  bool _pendingWaitForFrame = false;
  _MpvOutputConfiguration? _appliedConfiguration;
  _MpvOutputConfiguration? _applyingConfiguration;
  bool _configurationScheduled = false;
  bool _configurationApplying = false;
  int _configurationGeneration = 0;

  @override
  void initState() {
    super.initState();
    _listenToController();
    widget.transformationController.addListener(_onTransformationChanged);
  }

  @override
  void didUpdateWidget(covariant MpvVideoOutput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _sizeSubscription?.cancel();
      _configurationGeneration++;
      _pendingConfiguration = null;
      _pendingWaitForFrame = false;
      _appliedConfiguration = null;
      _applyingConfiguration = null;
      _listenToController();
    }
    if (widget.transformationController != oldWidget.transformationController) {
      oldWidget.transformationController.removeListener(
        _onTransformationChanged,
      );
      widget.transformationController.addListener(_onTransformationChanged);
    }
  }

  void _listenToController() {
    final player = widget.controller.player;
    _sourceWidth = player.state.width;
    _sourceHeight = player.state.height;
    _sizeSubscription = player.stream.size.listen((size) {
      if (_sourceWidth == size.$1 && _sourceHeight == size.$2) return;
      _sourceWidth = size.$1;
      _sourceHeight = size.$2;
      if (mounted) setState(() {});
    });
  }

  void _onTransformationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.transformationController.removeListener(_onTransformationChanged);
    _sizeSubscription?.cancel();
    super.dispose();
  }

  _MpvOutputConfiguration _createConfiguration(
    Size logicalSize,
    double devicePixelRatio,
  ) {
    final width = math.max(1, (logicalSize.width * devicePixelRatio).round());
    final height = math.max(1, (logicalSize.height * devicePixelRatio).round());
    final viewportAspectRatio = width / height;
    final sourceAspectRatio =
        widget.fit.aspectRatio ??
        (_sourceWidth > 0 && _sourceHeight > 0
            ? _sourceWidth / _sourceHeight
            : viewportAspectRatio);
    final baseVideoSize = _fittedVideoSize(
      logicalSize,
      devicePixelRatio,
      sourceAspectRatio,
    );
    final transform = calculateMpvVideoTransform(
      matrix: widget.transformationController.value,
      viewportSize: logicalSize,
      fittedVideoSize: baseVideoSize,
      alignment: widget.alignment,
    );

    return (
      width: width,
      height: height,
      panscan: widget.fit.mpvPanscan(
        sourceAspectRatio,
        viewportAspectRatio,
      ),
      videoUnscaled: widget.fit.mpvVideoUnscaled,
      aspectOverride: widget.fit.mpvAspectOverride(viewportAspectRatio),
      alignX: widget.alignment.x.clamp(-1.0, 1.0).toString(),
      alignY: widget.alignment.y.clamp(-1.0, 1.0).toString(),
      zoom: transform.zoom.toString(),
      panX: transform.panX.toString(),
      panY: transform.panY.toString(),
    );
  }

  Size _fittedVideoSize(
    Size viewport,
    double devicePixelRatio,
    double sourceAspectRatio,
  ) {
    if (widget.fit == VideoFitType.fill) return viewport;

    final sourceHeight = _sourceHeight > 0
        ? _sourceHeight / devicePixelRatio
        : viewport.width / sourceAspectRatio;
    final sourceSize = Size(sourceHeight * sourceAspectRatio, sourceHeight);
    final widthScale = viewport.width / sourceSize.width;
    final heightScale = viewport.height / sourceSize.height;
    final scale = switch (widget.fit) {
      VideoFitType.cover => math.max(widthScale, heightScale),
      VideoFitType.fitWidth => widthScale,
      VideoFitType.fitHeight => heightScale,
      VideoFitType.none => 1.0,
      VideoFitType.scaleDown => math.min(
        1.0,
        math.min(widthScale, heightScale),
      ),
      _ => math.min(widthScale, heightScale),
    };
    return Size(sourceSize.width * scale, sourceSize.height * scale);
  }

  bool _rectMatches(Rect? rect, _MpvOutputConfiguration configuration) =>
      rect != null &&
      (rect.width - configuration.width).abs() < 0.5 &&
      (rect.height - configuration.height).abs() < 0.5;

  void _requestConfiguration(
    _MpvOutputConfiguration configuration, {
    required bool waitForFrame,
  }) {
    if (_appliedConfiguration == configuration ||
        _applyingConfiguration == configuration) {
      return;
    }

    if (_pendingConfiguration == configuration) {
      _pendingWaitForFrame |= waitForFrame;
      return;
    }

    _pendingConfiguration = configuration;
    _pendingWaitForFrame = waitForFrame;
    _scheduleConfiguration();
  }

  void _scheduleConfiguration() {
    if (_configurationScheduled || _configurationApplying) return;
    _configurationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _configurationScheduled = false;
      if (mounted) unawaited(_drainConfigurations());
    });
  }

  Future<void> _drainConfigurations() async {
    if (_configurationApplying) return;
    _configurationApplying = true;
    try {
      while (mounted && _pendingConfiguration != null) {
        final configuration = _pendingConfiguration;
        final waitForFrame = _pendingWaitForFrame;
        _pendingConfiguration = null;
        _pendingWaitForFrame = false;
        if (configuration == null) continue;

        final controller = widget.controller;
        final generation = _configurationGeneration;
        final rect = controller.rect.value;
        _applyingConfiguration = configuration;

        final applied = await _applyConfiguration(
          controller,
          configuration,
          resize: !_rectMatches(rect, configuration),
          waitForFrame: waitForFrame,
        );
        if (applied &&
            mounted &&
            generation == _configurationGeneration &&
            identical(controller, widget.controller)) {
          _appliedConfiguration = configuration;
        }
      }
    } finally {
      _applyingConfiguration = null;
      _configurationApplying = false;
      if (mounted && _pendingConfiguration != null) {
        _scheduleConfiguration();
      }
    }
  }

  Future<bool> _applyConfiguration(
    VideoController controller,
    _MpvOutputConfiguration configuration, {
    required bool resize,
    required bool waitForFrame,
  }) async {
    final player = controller.player;

    final customOptions = MpvUtils.customOptions;
    void setBuiltInProperty(String name, String value) {
      if (!customOptions.containsKey(name)) {
        player.setProperty(name, value);
      }
    }

    try {
      setBuiltInProperty('keepaspect', 'yes');
      setBuiltInProperty('panscan', configuration.panscan);
      setBuiltInProperty('video-unscaled', configuration.videoUnscaled);
      setBuiltInProperty('video-aspect-override', configuration.aspectOverride);
      setBuiltInProperty('video-align-x', configuration.alignX);
      setBuiltInProperty('video-align-y', configuration.alignY);
      setBuiltInProperty('video-zoom', configuration.zoom);
      setBuiltInProperty('video-pan-x', configuration.panX);
      setBuiltInProperty('video-pan-y', configuration.panY);

      if (resize) {
        await controller.setSize(
          width: configuration.width,
          height: configuration.height,
          waitForFrame: waitForFrame,
        );
      }
      return true;
    } catch (error, stackTrace) {
      assert(() {
        debugPrint('Failed to resize mpv video output: $error');
        debugPrintStack(stackTrace: stackTrace);
        return true;
      }());
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final logicalSize = constraints.biggest;
        final configuration = _createConfiguration(
          logicalSize,
          devicePixelRatio,
        );
        return ListenableBuilder(
          listenable: widget.controller.rect,
          builder: (context, _) {
            final rect = widget.controller.rect.value;
            _requestConfiguration(
              configuration,
              waitForFrame: widget.waitForResizeFrame,
            );
            final outputWidth =
                rect != null && rect.width > 1
                ? rect.width / devicePixelRatio
                : configuration.width / devicePixelRatio;
            final outputHeight =
                rect != null && rect.height > 1
                ? rect.height / devicePixelRatio
                : configuration.height / devicePixelRatio;
            final texture = SizedBox(
              width: outputWidth,
              height: outputHeight,
              child: SimpleVideo(
                controller: widget.controller,
                fill: widget.fill,
                filterQuality: FilterQuality.none,
              ),
            );
            final outputMatches = _rectMatches(rect, configuration);
            final currentAspectRatio = outputWidth / outputHeight;
            final targetAspectRatio =
                configuration.width / configuration.height;
            final BoxFit pendingFit;
            if (widget.fit == VideoFitType.fill) {
              pendingFit = BoxFit.fill;
            } else if (targetAspectRatio < currentAspectRatio) {
              pendingFit = BoxFit.cover;
            } else {
              pendingFit = BoxFit.contain;
            }
            final output = outputMatches
                ? texture
                : FittedBox(
                    fit: pendingFit,
                    alignment: widget.alignment,
                    child: texture,
                  );

            return ColoredBox(
              color: widget.fill,
              child: ClipRect(
                child: output,
              ),
            );
          },
        );
      },
    );
  }
}

typedef _MpvOutputConfiguration = ({
  int width,
  int height,
  String panscan,
  String videoUnscaled,
  String aspectOverride,
  String alignX,
  String alignY,
  String zoom,
  String panX,
  String panY,
});
