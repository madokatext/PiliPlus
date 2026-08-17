import 'package:PiliPlus/models/common/enum_with_label.dart';

enum ArchiveSortTypeApp with EnumWithLabel {
  desc('祖传默认'),
  asc('反着排'),
  ;

  @override
  final String label;
  const ArchiveSortTypeApp(this.label);
}
