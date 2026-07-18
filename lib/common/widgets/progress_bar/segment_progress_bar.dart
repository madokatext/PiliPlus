/*
 * This file is part of PiliPlus
 *
 * PiliPlus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * PiliPlus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with PiliPlus.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'package:PiliPlus/common/widgets/marquee.dart';
import 'package:PiliPlus/utils/extension/iterable_ext.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

@immutable
sealed class BaseSegment {
  final double end;

  const BaseSegment({
    required this.end,
  });
}

@immutable
class Segment extends BaseSegment {
  final double start;
  final Color color;

  const Segment({
    required this.start,
    required super.end,
    required this.color,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is Segment) {
      return start == other.start && end == other.end && color == other.color;
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(start, end, color);
}

@immutable
class ViewPointSegment extends BaseSegment {
  final String? title;
  final String? url;
  final int? from;
  final int? to;

  const ViewPointSegment({
    required super.end,
    this.title,
    this.url,
    this.from,
    this.to,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is ViewPointSegment) {
      return end == other.end &&
          title == other.title &&
          url == other.url &&
          from == other.from &&
          to == other.to;
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(end, title, url, from, to);
}

class SegmentProgressBar extends BaseSegmentProgressBar<Segment> {
  const SegmentProgressBar({
    super.key,
    super.height,
    required super.segments,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderProgressBar(
      height: height,
      segments: segments,
    );
  }
}

class RenderProgressBar extends BaseRenderProgressBar<Segment> {
  RenderProgressBar({
    required super.height,
    required super.segments,
  });

  @override
  void paint(PaintingContext context, Offset offset) {
    final size = this.size;
    final canvas = context.canvas;
    final paint = Paint()..style = PaintingStyle.fill;

    for (final segment in segments) {
      paint.color = segment.color;
      final segmentStart = offset.dx + segment.start * size.width;
      final segmentEnd = offset.dx + segment.end * size.width;

      if (segmentEnd > segmentStart ||
          (segmentEnd == segmentStart && segmentStart > 0)) {
        canvas.drawRect(
          Rect.fromLTRB(
            segmentStart,
            offset.dy,
            segmentEnd == segmentStart ? segmentStart + 2 : segmentEnd,
            size.height + offset.dy,
          ),
          paint,
        );
      }
    }
  }
}

class ViewPointSegmentProgressBar extends StatelessWidget {
  const ViewPointSegmentProgressBar({
    super.key,
    this.height = 3.5,
    required this.segments,
    required this.progress,
    this.onSeek,
  });

  final double height;
  final List<ViewPointSegment> segments;
  final double progress;
  final ValueSetter<Duration>? onSeek;

  static const double _barHeight = 15.0;
  static const double _dividerWidth = 2.0;
  static const double _fontSize = 10.5;
  static const double _textPadding = 3.0;
  static const textStyle = TextStyle(
    color: Colors.white,
    fontSize: _fontSize,
    height: 1,
  );
  static const strutStyle = StrutStyle(
    fontSize: _fontSize,
    height: 1,
    leading: 0,
    forceStrutHeight: true,
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final normalizedProgress = progress.clamp(0.0, 1.0).toDouble();
      var currentIndex = segments.indexWhere(
        (segment) => normalizedProgress <= segment.end,
      );
      if (currentIndex == -1 && segments.isNotEmpty) {
        currentIndex = segments.length - 1;
      }

      final labels = <Widget>[];
      var previousEnd = 0.0;
      for (var index = 0; index < segments.length; index++) {
        final segment = segments[index];
        final title = segment.title;
        final left = previousEnd * width + (index == 0 ? 0 : _dividerWidth);
        final right = segment.end * width;
        final segmentWidth = right - left;
        previousEnd = segment.end;

        if (title == null || title.isEmpty || segmentWidth <= _textPadding) {
          continue;
        }

        final availableWidth = (segmentWidth - _textPadding * 2)
            .clamp(0.0, width)
            .toDouble();
        final isCurrent = index == currentIndex;
        labels.add(
          Positioned(
            left: left + _textPadding,
            top: 0,
            width: availableWidth,
            height: _barHeight,
            child: Align(
              alignment: Alignment.centerLeft,
              child: isCurrent
                  ? MarqueeText(
                      title,
                      spacing: 24,
                      velocity: 24,
                      style: textStyle,
                      strutStyle: strutStyle,
                    )
                  : Text(
                      title,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.clip,
                      textAlign: TextAlign.left,
                      style: textStyle,
                      strutStyle: strutStyle,
                    ),
            ),
          ),
        );
      }

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: onSeek == null || segments.isEmpty
            ? null
            : (details) {
                final value = (details.localPosition.dx / width)
                    .clamp(0.0, 1.0)
                    .toDouble();
                final index = segments
                    .lowerBoundByKey((item) => item.end, value)
                    .clamp(0, segments.length - 1)
                    .toInt();
                if (segments[index].from case final from?) {
                  onSeek?.call(Duration(seconds: from));
                }
              },
        child: SizedBox(
          height: _barHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _ViewPointBackgroundPainter(
                    segments: segments,
                    dividerExtension: height,
                  ),
                ),
              ),
              ...labels,
            ],
          ),
        ),
      );
    },
  );
}

class _ViewPointBackgroundPainter extends CustomPainter {
  const _ViewPointBackgroundPainter({
    required this.segments,
    required this.dividerExtension,
  });

  final List<ViewPointSegment> segments;
  final double dividerExtension;

  @override
  void paint(Canvas canvas, Size size) {
    assert(segments.isSortedBy((item) => item.end));
    final paint = Paint()..style = PaintingStyle.fill;
    canvas.drawRect(
      Offset.zero & size,
      paint..color = Colors.grey[600]!.withValues(alpha: 0.45),
    );
    paint.color = Colors.black.withValues(alpha: 0.5);
    for (final segment in segments) {
      final end = segment.end * size.width;
      canvas.drawRect(
        Rect.fromLTRB(
          end,
          0,
          end + ViewPointSegmentProgressBar._dividerWidth,
          size.height + dividerExtension,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ViewPointBackgroundPainter oldDelegate) =>
      dividerExtension != oldDelegate.dividerExtension ||
      !listEquals(segments, oldDelegate.segments);
}

abstract class BaseSegmentProgressBar<T extends BaseSegment>
    extends LeafRenderObjectWidget {
  const BaseSegmentProgressBar({
    super.key,
    this.height = 3.5,
    required this.segments,
  });

  final double height;
  final List<T> segments;

  @override
  void updateRenderObject(
    BuildContext context,
    BaseRenderProgressBar renderObject,
  ) {
    renderObject
      ..height = height
      ..segments = segments;
  }
}

class BaseRenderProgressBar<T extends BaseSegment> extends RenderBox {
  BaseRenderProgressBar({
    required this._height,
    required this._segments,
  });

  double _height;
  double get height => _height;
  set height(double value) {
    if (_height == value) return;
    _height = value;
    markNeedsLayout();
  }

  List<T> _segments;
  List<T> get segments => _segments;
  set segments(List<T> value) {
    if (listEquals(_segments, value)) return;
    _segments = value;
    markNeedsPaint();
  }

  @override
  void performLayout() {
    size = constraints.constrainDimensions(constraints.maxWidth, height);
  }
}
