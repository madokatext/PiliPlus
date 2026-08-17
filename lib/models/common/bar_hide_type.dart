import 'package:PiliPlus/models/common/enum_with_label.dart';

enum BarHideType with EnumWithLabel {
  instant('即时，曼波'),
  sync('同步，启动！'),
  ;

  @override
  final String label;
  const BarHideType(this.label);
}
