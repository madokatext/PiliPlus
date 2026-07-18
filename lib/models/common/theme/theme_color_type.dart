import 'package:flutter/material.dart';

enum ThemeColorMode {
  dynamic('动态取色'),
  preset('预设单种子'),
  customMultiSeed('自定义多种子'),
  ;

  const ThemeColorMode(this.label);

  final String label;
}

typedef ThemeSeedColors = ({
  Color primary,
  Color secondary,
  Color tertiary,
});

enum ThemeToneRole {
  page('页面背景', 'Scaffold、页面底色'),
  card('卡片背景', '普通卡片、列表块'),
  elevated('浮层背景', '弹窗、菜单、较高层容器'),
  selected('选中项背景', '选中标签、导航项、强调容器'),
  content('主要内容', '正文、主要图标'),
  selectedContent('选中项内容', '选中容器上的文字和图标'),
  mutedContent('次要内容', '说明文字、弱化图标'),
  border('边框分隔', '弱边框和分隔线'),
  ;

  const ThemeToneRole(this.label, this.description);

  final String label;
  final String description;
}

const ThemeSeedColors defaultCustomThemeSeeds = (
  primary: Color(0xFF5CB67B),
  secondary: Color(0xFF42A5F5),
  tertiary: Color(0xFFFF7299),
);

const List<({Color color, String label})> colorThemeTypes = [
  (color: Color(0xFF5CB67B), label: '默认绿'),
  (color: Color(0xFFFF7299), label: '粉红色'),
  (color: Colors.red, label: '红色'),
  (color: Colors.orange, label: '橙色'),
  (color: Colors.amber, label: '琥珀色'),
  (color: Colors.yellow, label: '黄色'),
  (color: Colors.lime, label: '酸橙色'),
  (color: Colors.lightGreen, label: '浅绿色'),
  (color: Colors.green, label: '绿色'),
  (color: Colors.teal, label: '青色'),
  (color: Colors.cyan, label: '蓝绿色'),
  (color: Colors.lightBlue, label: '浅蓝色'),
  (color: Colors.blue, label: '蓝色'),
  (color: Colors.indigo, label: '靛蓝色'),
  (color: Colors.purple, label: '紫色'),
  (color: Colors.deepPurple, label: '深紫色'),
  (color: Colors.blueGrey, label: '蓝灰色'),
  (color: Colors.brown, label: '棕色'),
  (color: Colors.grey, label: '灰色'),
];
