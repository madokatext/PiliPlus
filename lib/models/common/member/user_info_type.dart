import 'package:flutter/material.dart' show Alignment;

enum UserInfoType {
  fan('粉丝，不是哥们', .centerLeft),
  follow('赛博蹲点', .center),
  like('获赞，不是哥们', .centerRight),
  ;

  final String title;
  final Alignment alignment;

  const UserInfoType(this.title, this.alignment);
}
