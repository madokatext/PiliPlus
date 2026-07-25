import 'package:PiliPlus/plugin/pl_player/models/video_fit_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VideoFitType mpv mapping', () {
    test('maps crop behavior without Flutter fitting', () {
      expect(VideoFitType.contain.mpvPanscan(16 / 9, 4 / 3), '0.0');
      expect(VideoFitType.cover.mpvPanscan(16 / 9, 4 / 3), '1.0');
      expect(VideoFitType.fitWidth.mpvPanscan(4 / 3, 16 / 9), '1.0');
      expect(VideoFitType.fitWidth.mpvPanscan(16 / 9, 4 / 3), '0.0');
      expect(VideoFitType.fitHeight.mpvPanscan(16 / 9, 4 / 3), '1.0');
      expect(VideoFitType.fitHeight.mpvPanscan(4 / 3, 16 / 9), '0.0');
    });

    test('maps unscaled modes', () {
      expect(VideoFitType.none.mpvVideoUnscaled, 'yes');
      expect(VideoFitType.scaleDown.mpvVideoUnscaled, 'downscale-big');
      expect(VideoFitType.contain.mpvVideoUnscaled, 'no');
    });

    test('uses mpv aspect override for stretch and fixed ratios', () {
      expect(VideoFitType.fill.mpvAspectOverride(2), '2.0');
      expect(VideoFitType.ratio_4x3.mpvAspectOverride(2), '4:3');
      expect(VideoFitType.ratio_16x9.mpvAspectOverride(2), '16:9');
      expect(VideoFitType.contain.mpvAspectOverride(2), 'no');
    });
  });
}
