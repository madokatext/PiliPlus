import 'package:PiliPlus/models/common/enum_with_label.dart';

enum SuperResolutionType with EnumWithLabel {
  disable('当场封印'),
  efficiency('效率，曼波'),
  quality('眼睛待遇'),
  ;

  @override
  final String label;
  const SuperResolutionType(this.label);
}
