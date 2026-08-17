import 'package:PiliPlus/pages/later/child_view.dart';
import 'package:flutter/material.dart';

enum LaterViewType {
  all(0, '我全都要'),
  // toView(1, '未看'),
  unfinished(2, '未看完，曼波'),
  // viewed(3, '已看完'),
  ;

  Widget get page => LaterViewChildPage(laterViewType: this);

  final int type;
  final String title;
  const LaterViewType(this.type, this.title);
}
