import 'package:PiliPlus/models/common/enum_with_label.dart';

enum HomeCardAspectRatio implements EnumWithLabel {
  sixteenNine('16:9', 16 / 9),
  sixteenTen('16:10', 16 / 10),
  fourThree('4:3', 4 / 3),
  ;

  const HomeCardAspectRatio(this.label, this.ratio);

  @override
  final String label;
  final double ratio;

  static HomeCardAspectRatio fromStorage(Object? value) {
    if (value is String) {
      for (final aspectRatio in values) {
        if (aspectRatio.name == value) {
          return aspectRatio;
        }
      }
    }
    return fourThree;
  }
}
