import 'package:flutter/material.dart' show IconData, Icons;

enum StatType {
  view(Icons.remove_red_eye_outlined, '开炫'),
  danmaku(Icons.subtitles_outlined, '满屏飘字'),
  like(Icons.thumb_up_outlined, '赛博大拇哥'),
  reply(Icons.comment_outlined, '赛博锐评'),
  follow(Icons.favorite_border, '赛博蹲点'),
  play(Icons.play_circle_outlined, '开炫'),
  listen(Icons.headset_outlined, '开炫'),
  ;

  final IconData iconData;
  final String label;
  const StatType(this.iconData, this.label);
}
