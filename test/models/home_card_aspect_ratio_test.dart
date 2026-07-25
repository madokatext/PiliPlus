import 'package:PiliPlus/models/common/home_card_aspect_ratio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomeCardAspectRatio', () {
    test('provides the supported display ratios', () {
      expect(HomeCardAspectRatio.sixteenNine.label, '16:9');
      expect(HomeCardAspectRatio.sixteenNine.ratio, closeTo(16 / 9, 0.0001));
      expect(HomeCardAspectRatio.sixteenTen.label, '16:10');
      expect(HomeCardAspectRatio.sixteenTen.ratio, closeTo(16 / 10, 0.0001));
      expect(HomeCardAspectRatio.fourThree.label, '4:3');
      expect(HomeCardAspectRatio.fourThree.ratio, closeTo(4 / 3, 0.0001));
    });

    test('restores a persisted ratio and falls back to 4:3', () {
      expect(
        HomeCardAspectRatio.fromStorage('sixteenNine'),
        HomeCardAspectRatio.sixteenNine,
      );
      expect(
        HomeCardAspectRatio.fromStorage('unknown'),
        HomeCardAspectRatio.fourThree,
      );
      expect(
        HomeCardAspectRatio.fromStorage(null),
        HomeCardAspectRatio.fourThree,
      );
    });
  });
}
