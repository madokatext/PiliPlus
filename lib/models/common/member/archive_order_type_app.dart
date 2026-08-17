import 'package:PiliPlus/models/common/enum_with_label.dart';

enum ArchiveOrderTypeApp with EnumWithLabel {
  pubdate('刚出锅'),
  click('炫得最多'),
  ;

  @override
  final String label;
  const ArchiveOrderTypeApp(this.label);
}
