import 'package:PiliPlus/utils/bili_colors.dart';
import 'package:flutter/material.dart';

enum BadgeType {
  none(),
  vip('尊贵氪佬通行证'),
  person('认证个人，CPU 都看沉默了', BiliColors.yellow),
  institution('认证机构，我嘞个豆', Colors.lightBlueAccent),
  ;

  final String? desc;
  final Color? color;
  const BadgeType([this.desc, this.color]);
}
