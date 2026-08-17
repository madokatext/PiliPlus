import 'package:PiliPlus/models/common/enum_with_label.dart';

enum PlayRepeat implements EnumWithLabel {
  pause('播完按住别动'),
  listOrder('顺序开炫'),
  singleCycle('单个循环，CPU 都看沉默了'),
  listCycle('列表循环，功德+1'),
  autoPlayRelated('全自动赛博连播'),
  ;

  @override
  final String label;
  const PlayRepeat(this.label);
}
