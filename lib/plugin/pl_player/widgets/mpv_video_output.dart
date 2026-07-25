import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:PiliPlus/plugin/pl_player/models/video_fit_type.dart';
import 'package:PiliPlus/utils/mpv_utils.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    super.key,
  });

  final VideoController controller;
  final VideoFitType fit;
  final Color fill;
  final Alignment alignment;
  final TransformationController transformationController;

  @override
  State<MpvVideoOutput> createState() => _MpvVideoOutputState();
}

class _MpvVideoOutputState extends State<MpvVideoOutput> {
  static const _androidVideoChannel = MethodChannel(
    'com.alexmercerind/media_kit_video',
  );

  StreamSubscription<(int, int)>? _sizeSubscription;
  late int _sourceWidth;
  late int _sourceHeight;
  _MpvOutputConfiguration? _pendingConfiguration;
  _MpvOutputConfiguration? _lastRequestedConfiguration;
  Rect? _lastMismatchedRect;
  bool _pendingResize = false;
  bool _configurationScheduled = false;
  _MpvOutputConfiguration? _pendingResizeConfiguration;
  bool _resizeInProgress = false;

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
      _pendingResizeConfiguration = null;
      _lastRequestedConfiguration = null;
      _lastMismatchedRect = null;
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
      _lastRequestedConfiguration = null;
      if (mounted) setState(() {});
    });
  }

  void _onTransformationChanged() {
    _lastRequestedConfiguration = null;
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
    _MpvOutputConfiguration configuration,
    Rect? rect,
  ) {
    final matches = _rectMatches(rect, configuration);
    if (_lastRequestedConfiguration == configuration &&
        (matches || _lastMismatchedRect == rect)) {
      return;
    }

    _lastRequestedConfiguration = configuration;
    _lastMismatchedRect = matches ? null : rect;
    _pendingConfiguration = configuration;
    _pendingResize = _pendingResize || !matches;
    if (_configurationScheduled) return;
    _configurationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _configurationScheduled = false;
      final pending = _pendingConfiguration;
      final resize = _pendingResize;
      _pendingConfiguration = null;
      _pendingResize = false;
      if (mounted && pending != null) {
        unawaited(_applyConfiguration(pending, resize: false));
        if (resize || _resizeInProgress) _requestOutputResize(pending);
      }
    });
  }

  void _requestOutputResize(_MpvOutputConfiguration configuration) {
    _pendingResizeConfiguration = configuration;
    if (!_resizeInProgress) unawaited(_drainOutputResizes());
  }

  Future<void> _drainOutputResizes() async {
    _resizeInProgress = true;
    try {
      while (mounted) {
        final configuration = _pendingResizeConfiguration;
        if (configuration == null) break;
        _pendingResizeConfiguration = null;
        await _applyConfiguration(configuration, resize: true);
      }
    } finally {
      _resizeInProgress = false;
    }
  }

  Future<void> _applyConfiguration(
    _MpvOutputConfiguration configuration, {
    required bool resize,
  }) async {
    final controller = widget.controller;
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

      if (!resize) return;
      if (Platform.isAndroid) {
        // media_kit does not implement VideoController.setSize on Android.
        await _androidVideoChannel.invokeMethod<void>(
          'VideoOutputManager.SetSurfaceTextureSize',
          {
            'handle': player.handle.toString(),
            'width': configuration.width.toString(),
            'height': configuration.height.toString(),
          },
        );
        player.setProperty(
          'android-surface-size',
          '${configuration.width}x${configuration.height}',
        );
        // Do not publish an obsolete half-screen size while a newer full-screen
        // resize is already queued. The latest resize runs immediately afterward.
        if (_pendingResizeConfiguration == null) {
          controller.rect.value = Rect.fromLTWH(
            0,
            0,
            configuration.width.toDouble(),
            configuration.height.toDouble(),
          );
        }
      } else {
        await controller.setSize(
          width: configuration.width,
          height: configuration.height,
        );
      }
    } catch (error, stackTrace) {
      assert(() {
        debugPrint('Failed to resize mpv video output: $error');
        debugPrintStack(stackTrace: stackTrace);
        return true;
      }());
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
            _requestConfiguration(configuration, rect);

            return ColoredBox(
              color: widget.fill,
              child: ClipRect(
                // The texture and this box share the same physical pixel size.
                child: OverflowBox(
                  alignment: Alignment.center,
                  minWidth: configuration.width / devicePixelRatio,
                  maxWidth: configuration.width / devicePixelRatio,
                  minHeight: configuration.height / devicePixelRatio,
                  maxHeight: configuration.height / devicePixelRatio,
                  child: SimpleVideo(
                    controller: widget.controller,
                    fill: widget.fill,
                    filterQuality: FilterQuality.none,
                  ),
                ),
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
