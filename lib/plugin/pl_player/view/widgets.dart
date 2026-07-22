part of 'view.dart';

Widget buildDmChart(
  Color color,
  List<double> dmTrend,
  VideoDetailController videoDetailController, [
  double offset = 0,
]) {
  return IgnorePointer(
    child: Container(
      height: 12,
      margin: EdgeInsets.only(
        bottom:
            videoDetailController.viewPointList.isNotEmpty &&
                videoDetailController.showVP.value
            ? 19.25 + offset
            : 4.25 + offset,
      ),
      child: LineChart(
        LineChartData(
          titlesData: const FlTitlesData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (dmTrend.length - 1).toDouble(),
          minY: 0,
          maxY: dmTrend.max,
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(
                dmTrend.length,
                (index) => FlSpot(
                  index.toDouble(),
                  dmTrend[index],
                ),
              ),
              isCurved: true,
              barWidth: 1,
              color: color,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget buildSeekPreviewWidget(
  PlPlayerController plPlayerController,
  double maxWidth,
  double maxHeight,
  ValueGetter<bool> isMounted,
  double? Function(double globalX) globalToLocalX,
  ValueGetter<double?> progressBarCenterY,
) {
  return Obx(
    () {
      if (!plPlayerController.showPreview.value) {
        return const SizedBox.shrink();
      }

      try {
        final double baseScale =
            plPlayerController.isFullScreen.value &&
                (PlatformUtils.isDesktop || !plPlayerController.isVertical)
            ? 4
            : 3;
        double height =
            27 * baseScale * plPlayerController.seekPreviewScale;
        final compatHeight = maxHeight - 140;
        if (compatHeight > 50) {
          height = math.min(height, compatHeight);
        }
        const verticalMargin = 8.0;
        final maxPreviewHeight = maxHeight - verticalMargin * 2;
        if (maxPreviewHeight > 0) {
          height = math.min(height, maxPreviewHeight);
        }

        const horizontalMargin = 8.0;
        final maxPreviewWidth = maxWidth - horizontalMargin * 2;
        final videoWidth = plPlayerController.width ?? 0;
        final videoHeight = plPlayerController.height ?? 0;
        final videoAspectRatio = videoWidth > 0 && videoHeight > 0
            ? videoWidth / videoHeight
            : Style.aspectRatio;

        double fitHeight(double value, double aspectRatio) {
          if (maxPreviewWidth > 0 &&
              aspectRatio.isFinite &&
              aspectRatio > 0) {
            return math.min(value, maxPreviewWidth / aspectRatio);
          }
          return value;
        }

        Widget positionPreview(Widget preview) {
          var centerX = maxWidth / 2;
final globalX = plPlayerController.previewGlobalX.value;

if (globalX != null) {
  centerX = globalToLocalX(globalX) ?? centerX;
}
          return CustomSingleChildLayout(
            delegate: _SeekPreviewLayoutDelegate(
              centerX: centerX,
              bottomY:
                  (progressBarCenterY() ?? maxHeight - 48) -
                  plPlayerController.seekPreviewProgressBarGap,
              margin: horizontalMargin,
            ),
            child: preview,
          );
        }

        Widget loadingPreview(double aspectRatio) {
          final previewHeight = fitHeight(height, aspectRatio);
          return positionPreview(
            ClipRRect(
              borderRadius: Style.mdRadius,
              child: SizedBox(
                width: previewHeight * aspectRatio,
                height: previewHeight,
                child: const ColoredBox(
                  color: Color(0xB3000000),
                  child: Center(
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        final data = plPlayerController.videoShot?.dataOrNull;
        final index = plPlayerController.previewIndex.value;
        if (data == null ||
            index == null ||
            data.image.isEmpty ||
            data.imgXLen <= 0 ||
            data.imgYLen <= 0) {
          return loadingPreview(videoAspectRatio);
        }

        final imgXLen = data.imgXLen;
        final imgYLen = data.imgYLen;
        final totalPerImage = data.totalPerImage;
        var imgXSize = data.imgXSize;
        var imgYSize = data.imgYSize;
        final hasValidCellSize = imgXSize.isFinite &&
            imgYSize.isFinite &&
            imgXSize > 0 &&
            imgYSize > 0;
        final aspectRatio = hasValidCellSize
            ? imgXSize / imgYSize
            : videoAspectRatio;
        height = fitHeight(height, aspectRatio);

        final pageIndex = (index ~/ totalPerImage).clamp(
          0,
          data.image.length - 1,
        );
        final align = index % totalPerImage;
        final x = align % imgXLen;
        final y = align ~/ imgXLen;
        final url = data.image[pageIndex];

        final preview = ClipRRect(
          borderRadius: Style.mdRadius,
          child: VideoShotImage(
            key: ValueKey('${plPlayerController.previewGeneration}:$url'),
            url: url,
            x: x,
            y: y,
            imgXSize: imgXSize,
            imgYSize: imgYSize,
            imgXLen: imgXLen,
            imgYLen: imgYLen,
            height: height,
            maxWidth: maxPreviewWidth,
            videoAspectRatio: videoAspectRatio,
            generation: plPlayerController.previewGeneration,
            imageCache: plPlayerController.previewCache,
            imageLoadTasks: plPlayerController.previewLoadTasks,
            onSetSize: (xSize, ySize) => data
              ..imgXSize = imgXSize = xSize
              ..imgYSize = imgYSize = ySize,
            isMounted: isMounted,
          ),
        );
        return positionPreview(preview);
      } catch (e) {
        if (kDebugMode) rethrow;
        return const SizedBox.shrink();
      }
    },
  );
}

class _SeekPreviewLayoutDelegate extends SingleChildLayoutDelegate {
  const _SeekPreviewLayoutDelegate({
    required this.centerX,
    required this.bottomY,
    required this.margin,
  });

  final double centerX;
  final double bottomY;
  final double margin;

  @override
  Size getSize(BoxConstraints constraints) => constraints.biggest;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints.loose(
      Size(
        math.max(0.0, constraints.maxWidth - margin * 2),
        math.max(0.0, constraints.maxHeight - margin * 2),
      ),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final horizontalSpace = math.max(0.0, size.width - childSize.width);
    final minLeft = math.min(margin, horizontalSpace / 2);
    final maxLeft = math.max(minLeft, horizontalSpace - minLeft);
    final left = (centerX - childSize.width / 2)
        .clamp(minLeft, maxLeft)
        .toDouble();
    final verticalSpace = math.max(0.0, size.height - childSize.height);
    final minTop = math.min(margin, verticalSpace / 2);
    final maxTop = math.max(minTop, verticalSpace - minTop);
    final top = (bottomY - childSize.height)
        .clamp(minTop, maxTop)
        .toDouble();
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(_SeekPreviewLayoutDelegate oldDelegate) =>
      centerX != oldDelegate.centerX ||
      bottomY != oldDelegate.bottomY ||
      margin != oldDelegate.margin;
}

class VideoShotImage extends StatefulWidget {
  const VideoShotImage({
    super.key,
    required this.imageCache,
    required this.url,
    required this.x,
    required this.y,
    required this.imgXSize,
    required this.imgYSize,
    required this.imgXLen,
    required this.imgYLen,
    required this.height,
    required this.maxWidth,
    required this.videoAspectRatio,
    required this.generation,
    required this.imageLoadTasks,
    required this.onSetSize,
    required this.isMounted,
  });

  final Map<String, ui.Image> imageCache;
  final Map<String, Future<ui.Image?>> imageLoadTasks;
  final String url;
  final int x;
  final int y;
  final double imgXSize;
  final double imgYSize;
  final int imgXLen;
  final int imgYLen;
  final double height;
  final double maxWidth;
  final double videoAspectRatio;
  final int generation;
  final Function(double imgXSize, double imgYSize) onSetSize;
  final ValueGetter<bool> isMounted;

  @override
  State<VideoShotImage> createState() => _VideoShotImageState();
}

Future<ui.Image?> _getImg(String url) async {
  final cacheKey = Utils.getFileName(url, fileExt: false);
  try {
    final fileInfo = await CacheManager.manager.getSingleFile(
      ImageUtils.safeThumbnailUrl(url),
      key: cacheKey,
      headers: Constants.baseHeaders,
    );
    return await _loadImg(fileInfo.path);
  } catch (_) {
    return null;
  }
}

Future<ui.Image?> _loadImg(String path) async {
  final codec = await ui.instantiateImageCodecFromBuffer(
    await ImmutableBuffer.fromFilePath(path),
  );
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

class _VideoShotImageState extends State<VideoShotImage> {
  late Size _size;
  late Rect _srcRect;
  late Rect _dstRect;
  late RRect _rrect;
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _initSize();
    _loadImg();
  }

  bool get _hasValidMetadata =>
      widget.imgXSize.isFinite &&
      widget.imgYSize.isFinite &&
      widget.imgXSize > 0 &&
      widget.imgYSize > 0;

  double get _videoAspectRatio =>
      widget.videoAspectRatio.isFinite && widget.videoAspectRatio > 0
      ? widget.videoAspectRatio
      : Style.aspectRatio;

  bool _hasSameAspectRatio(double first, double second) =>
      (first - second).abs() / math.max(first, second) <= 0.01;

  Size? get _cellSize {
    if (_hasValidMetadata) {
      return Size(widget.imgXSize, widget.imgYSize);
    }
    if (_image != null && widget.imgXLen > 0 && widget.imgYLen > 0) {
      return Size(
        _image!.width / widget.imgXLen,
        _image!.height / widget.imgYLen,
      );
    }
    return null;
  }

  void _initSize() {
    final cellSize = _cellSize;
    final frameAspectRatio = cellSize == null
        ? _videoAspectRatio
        : cellSize.width / cellSize.height;
    // The server may stretch a video frame to the sprite cell's aspect ratio.
    // Keep that ratio for cropping and the outer frame, but restore the video's
    // aspect ratio inside it so any remaining space becomes letterboxing.
    final contentAspectRatio = cellSize != null &&
            !_hasSameAspectRatio(frameAspectRatio, _videoAspectRatio)
        ? _videoAspectRatio
        : frameAspectRatio;
    var height = widget.height.isFinite && widget.height > 0
        ? widget.height
        : 0.0;
    if (widget.maxWidth.isFinite &&
        widget.maxWidth > 0 &&
        frameAspectRatio > 0) {
      height = math.min(height, widget.maxWidth / frameAspectRatio);
    }
    _setRect(
      height * frameAspectRatio,
      height,
      contentAspectRatio,
    );

    if (cellSize != null) {
      _setSrcRect(cellSize.width, cellSize.height);
      if (!_hasValidMetadata) {
        widget.onSetSize(cellSize.width, cellSize.height);
      }
    } else {
      _setSrcRect(0, 0);
    }
  }

  void _setRect(double width, double height, double contentAspectRatio) {
    _size = Size(width, height);
    final frameRect = Rect.fromLTRB(0, 0, width, height);
    if (width > 0 &&
        height > 0 &&
        contentAspectRatio.isFinite &&
        contentAspectRatio > 0) {
      final frameAspectRatio = width / height;
      if (contentAspectRatio > frameAspectRatio) {
        final contentHeight = width / contentAspectRatio;
        _dstRect = Rect.fromLTWH(
          0,
          (height - contentHeight) / 2,
          width,
          contentHeight,
        );
      } else {
        final contentWidth = height * contentAspectRatio;
        _dstRect = Rect.fromLTWH(
          (width - contentWidth) / 2,
          0,
          contentWidth,
          height,
        );
      }
    } else {
      _dstRect = frameRect;
    }
    _rrect = RRect.fromRectAndRadius(frameRect, const Radius.circular(10));
  }

  void _setSrcRect(double imgXSize, double imgYSize) {
    _srcRect = Rect.fromLTWH(
      widget.x * imgXSize,
      widget.y * imgYSize,
      imgXSize,
      imgYSize,
    );
  }

  void _loadImg() {
    final url = widget.url;
    final generation = widget.generation;
    _image = widget.imageCache[url];
    if (_image != null) {
      _initSize();
      return;
    }

    _initSize();
    final task = widget.imageLoadTasks.putIfAbsent(url, () => _getImg(url));
    task.then((image) {
      final isActiveTask = identical(widget.imageLoadTasks[url], task);
      if (image == null) {
        if (isActiveTask) {
          widget.imageLoadTasks.remove(url);
        }
        return;
      }

      if (isActiveTask) {
        widget.imageLoadTasks.remove(url);
        if (widget.isMounted() && widget.generation == generation) {
          widget.imageCache[url] = image;
        } else {
          image.dispose();
          return;
        }
      }

      final resolvedImage = widget.imageCache[url];
      if (resolvedImage != null &&
          mounted &&
          widget.url == url &&
          widget.generation == generation) {
        _image = resolvedImage;
        _initSize();
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(VideoShotImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url ||
        oldWidget.generation != widget.generation) {
      _image = null;
      _loadImg();
      return;
    }
    if (oldWidget.x != widget.x ||
        oldWidget.y != widget.y ||
        oldWidget.imgXSize != widget.imgXSize ||
        oldWidget.imgYSize != widget.imgYSize ||
        oldWidget.imgXLen != widget.imgXLen ||
        oldWidget.imgYLen != widget.imgYLen ||
        oldWidget.height != widget.height ||
        oldWidget.maxWidth != widget.maxWidth ||
        oldWidget.videoAspectRatio != widget.videoAspectRatio) {
      _initSize();
    }
    if (_image == null) {
      _loadImg();
    }
  }

  late final _imgPaint = Paint()..filterQuality = FilterQuality.medium;
  late final _borderPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  @override
  Widget build(BuildContext context) {
    if (_image != null && _srcRect.width > 0 && _srcRect.height > 0) {
      return SizedBox.fromSize(
        size: _size,
        child: ColoredBox(
          color: Colors.black,
          child: CroppedImage(
            size: _size,
            image: _image!,
            srcRect: _srcRect,
            dstRect: _dstRect,
            rrect: _rrect,
            imgPaint: _imgPaint,
            borderPaint: _borderPaint,
          ),
        ),
      );
    }
    return SizedBox.fromSize(
      size: _size,
      child: const ColoredBox(
        color: Color(0xB3000000),
        child: Center(
          child: SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

const double _triangleHeight = 5.6;

class _DanmakuTip extends SingleChildRenderObjectWidget {
  const _DanmakuTip({
    this.offset = 0,
    super.child,
  });

  final double offset;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderDanmakuTip(offset: offset);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderDanmakuTip renderObject,
  ) {
    renderObject.offset = offset;
  }
}

class _RenderDanmakuTip extends RenderProxyBox {
  _RenderDanmakuTip({
    required this._offset,
  });

  double _offset;
  double get offset => _offset;
  set offset(double value) {
    if (_offset == value) return;
    _offset = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final paint = Paint()
      ..color = const Color(0xB3000000)
      ..style = .fill;

    final radius = size.height / 2;
    const triangleBase = _triangleHeight * 2 / 3;

    final triangleCenterX = (size.width / 2 + _offset).clamp(
      radius + triangleBase,
      size.width - radius - triangleBase,
    );
    final path = Path()
      // triangle (exceed)
      ..moveTo(triangleCenterX - triangleBase, 0)
      ..lineTo(triangleCenterX, -_triangleHeight)
      ..lineTo(triangleCenterX + triangleBase, 0)
      // top
      ..lineTo(size.width - radius, 0)
      // right
      ..arcToPoint(
        Offset(size.width - radius, size.height),
        radius: Radius.circular(radius),
      )
      // bottom
      ..lineTo(radius, size.height)
      // left
      ..arcToPoint(
        Offset(radius, 0),
        radius: Radius.circular(radius),
      )
      ..close();

    context.canvas
      ..save()
      ..translate(offset.dx, offset.dy)
      ..drawPath(path, paint)
      ..drawPath(
        path,
        paint
          ..color = const Color(0x7EFFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.25,
      )
      ..restore();

    super.paint(context, offset);
  }
}

class _VideoTime extends LeafRenderObjectWidget {
  const _VideoTime({
    required this.position,
    required this.duration,
  });

  final String position;
  final String duration;

  @override
  _RenderVideoTime createRenderObject(BuildContext context) => _RenderVideoTime(
    position: position,
    duration: duration,
  );

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderVideoTime renderObject,
  ) {
    renderObject
      ..position = position
      ..duration = duration;
  }
}

class _RenderVideoTime extends RenderBox {
  _RenderVideoTime({
    required this._position,
    required this._duration,
  });

  String _duration;
  set duration(String value) {
    _duration = value;
    final paragraph = _buildParagraph(const Color(0xFFD0D0D0), _duration);
    if (paragraph.maxIntrinsicWidth != _cache?.maxIntrinsicWidth) {
      markNeedsLayout();
    }
    _cache?.dispose();
    _cache = paragraph;
    markNeedsSemanticsUpdate();
  }

  String _position;
  set position(String value) {
    _position = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  ui.Paragraph? _cache;

  ui.Paragraph _buildParagraph(Color color, String time) {
    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              fontSize: 10,
              height: 1.4,
              fontFamily: 'Monospace',
            ),
          )
          ..pushStyle(
            ui.TextStyle(
              color: color,
              fontSize: 10,
              height: 1.4,
              fontFamily: 'Monospace',
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          )
          ..addText(time);
    return builder.build()
      ..layout(const ui.ParagraphConstraints(width: .infinity));
  }

  @override
  ui.Size computeDryLayout(covariant BoxConstraints constraints) {
    final paragraph = _cache ??= _buildParagraph(
      const Color(0xFFD0D0D0),
      _duration,
    );
    return Size(paragraph.maxIntrinsicWidth, paragraph.height * 2);
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config.label = 'position:$_position\nduration:$_duration';
  }

  @override
  void performLayout() {
    size = computeDryLayout(constraints);
  }

  @override
  void paint(PaintingContext context, ui.Offset offset) {
    final para = _buildParagraph(Colors.white, _position);
    context.canvas
      ..drawParagraph(
        para,
        Offset(
          offset.dx + _cache!.maxIntrinsicWidth - para.maxIntrinsicWidth,
          offset.dy,
        ),
      )
      ..drawParagraph(_cache!, Offset(offset.dx, offset.dy + para.height));
    para.dispose();
  }

  @override
  void dispose() {
    _cache?.dispose();
    _cache = null;
    super.dispose();
  }

  @override
  bool get isRepaintBoundary => true;
}
