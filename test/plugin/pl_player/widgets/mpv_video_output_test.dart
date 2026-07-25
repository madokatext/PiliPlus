import 'dart:math' as math;

import 'package:PiliPlus/plugin/pl_player/widgets/mpv_video_output.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('calculateMpvVideoTransform', () {
    test('keeps a centered pinch anchored to the viewport center', () {
      final matrix = Matrix4.identity()
        ..scaleByDouble(2, 2, 2, 1)
        ..translateByDouble(-250, -200, 0, 1);

      final transform = calculateMpvVideoTransform(
        matrix: matrix,
        viewportSize: const Size(1000, 800),
        fittedVideoSize: const Size(1000, 800),
        alignment: Alignment.center,
      );

      expect(transform.zoom, 1);
      expect(transform.panX, closeTo(0, 1e-12));
      expect(transform.panY, closeTo(0, 1e-12));
    });

    test('keeps an off-center pinch anchored to the touch position', () {
      final matrix = Matrix4.identity()
        ..scaleByDouble(2, 2, 2, 1)
        ..translateByDouble(-125, -100, 0, 1);

      final transform = calculateMpvVideoTransform(
        matrix: matrix,
        viewportSize: const Size(1000, 800),
        fittedVideoSize: const Size(800, 600),
        alignment: Alignment.center,
      );

      expect(transform.zoom, 1);
      expect(transform.panX, closeTo(0.15625, 1e-12));
      expect(transform.panY, closeTo(1 / 6, 1e-12));
    });

    test('uses the configured video alignment as the scale origin', () {
      final matrix = Matrix4.identity()
        ..scaleByDouble(1.5, 1.5, 1.5, 1)
        ..translateByDouble(-100, -80, 0, 1);

      final transform = calculateMpvVideoTransform(
        matrix: matrix,
        viewportSize: const Size(1000, 800),
        fittedVideoSize: const Size(800, 600),
        alignment: Alignment.topLeft,
      );

      expect(transform.zoom, closeTo(mathLog2(1.5), 1e-12));
      expect(transform.panX, closeTo(-0.125, 1e-12));
      expect(transform.panY, closeTo(-0.13333333333333333, 1e-12));
    });
  });
}

double mathLog2(double value) => math.log(value) / math.ln2;
