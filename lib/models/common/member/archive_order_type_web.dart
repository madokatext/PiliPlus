import 'package:PiliPlus/models/common/enum_with_label.dart';

enum ArchiveOrderTypeWeb with EnumWithLabel {
  pubdate('刚出锅'),
  click('炫得最多'),
  stow('最多塞进电子小被窝'),
  ;

  @override
  final String label;
  const ArchiveOrderTypeWeb(this.label);
}
