import 'package:PiliPlus/models/common/enum_with_label.dart';

enum SkipType implements EnumWithLabel {
  alwaysSkip('总是跳过，属实绷不住'),
  skipOnce('跳过一次，曼波'),
  skipManually('亲自下场跳过'),
  showOnly('仅亮出来'),
  disable('当场封印'),
  ;

  @override
  final String label;
  const SkipType(this.label);
}
