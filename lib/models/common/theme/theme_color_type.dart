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

enum ThemeColorFamily {
  primary('主色系'),
  secondary('次色系'),
  tertiary('第三色系'),
  error('错误色系'),
  surface('中性色与表面色系'),
  ;

  const ThemeColorFamily(this.label);

  final String label;
}

/// Material 颜色表中的可分配颜色，以及每个颜色槽默认负责的 UI 元素。
///
/// 配置界面把这里的每一项同时作为“颜色来源”和“UI 颜色槽”。默认情况下
/// 每个颜色槽使用自身生成的颜色，用户也可以把它改为任意其他颜色来源。
enum ThemeSchemeColor {
  primary(
    ThemeColorFamily.primary,
    '主色',
    '开关、主按钮、主进度条和主要交互状态',
  ),
  onPrimary(
    ThemeColorFamily.primary,
    '主色内容',
    '主色背景上的文字与图标',
  ),
  primaryContainer(
    ThemeColorFamily.primary,
    '主色容器',
    '主色系选中项和强调容器的背景',
  ),
  onPrimaryContainer(
    ThemeColorFamily.primary,
    '主色容器内容',
    '主色容器上的文字与图标',
  ),
  primaryFixed(
    ThemeColorFamily.primary,
    '固定主色',
    '不随明暗主题改变用途的主色背景',
  ),
  primaryFixedDim(
    ThemeColorFamily.primary,
    '弱化固定主色',
    '固定主色的低强调背景',
  ),
  onPrimaryFixed(
    ThemeColorFamily.primary,
    '固定主色内容',
    '固定主色背景上的主要文字与图标',
  ),
  onPrimaryFixedVariant(
    ThemeColorFamily.primary,
    '固定主色次要内容',
    '固定主色背景上的次要文字与图标',
  ),
  inversePrimary(
    ThemeColorFamily.primary,
    '反色主色',
    '反色表面中的主要交互元素',
  ),
  secondary(
    ThemeColorFamily.secondary,
    '次色',
    '次级按钮、“我的”页快捷入口等次级交互',
  ),
  onSecondary(
    ThemeColorFamily.secondary,
    '次色内容',
    '次色背景上的文字与图标',
  ),
  secondaryContainer(
    ThemeColorFamily.secondary,
    '次色容器',
    '次级选中项、提示条和次级强调容器背景',
  ),
  onSecondaryContainer(
    ThemeColorFamily.secondary,
    '次色容器内容',
    '次色容器上的文字与图标',
  ),
  secondaryFixed(
    ThemeColorFamily.secondary,
    '固定次色',
    '不随明暗主题改变用途的次色背景',
  ),
  secondaryFixedDim(
    ThemeColorFamily.secondary,
    '弱化固定次色',
    '固定次色的低强调背景',
  ),
  onSecondaryFixed(
    ThemeColorFamily.secondary,
    '固定次色内容',
    '固定次色背景上的主要文字与图标',
  ),
  onSecondaryFixedVariant(
    ThemeColorFamily.secondary,
    '固定次色次要内容',
    '固定次色背景上的次要文字与图标',
  ),
  tertiary(
    ThemeColorFamily.tertiary,
    '第三色',
    '第三层级强调元素和辅助装饰',
  ),
  onTertiary(
    ThemeColorFamily.tertiary,
    '第三色内容',
    '第三色背景上的文字与图标',
  ),
  tertiaryContainer(
    ThemeColorFamily.tertiary,
    '第三色容器',
    '第三色系选中项和辅助强调容器背景',
  ),
  onTertiaryContainer(
    ThemeColorFamily.tertiary,
    '第三色容器内容',
    '第三色容器上的文字与图标',
  ),
  tertiaryFixed(
    ThemeColorFamily.tertiary,
    '固定第三色',
    '不随明暗主题改变用途的第三色背景',
  ),
  tertiaryFixedDim(
    ThemeColorFamily.tertiary,
    '弱化固定第三色',
    '固定第三色的低强调背景',
  ),
  onTertiaryFixed(
    ThemeColorFamily.tertiary,
    '固定第三色内容',
    '固定第三色背景上的主要文字与图标',
  ),
  onTertiaryFixedVariant(
    ThemeColorFamily.tertiary,
    '固定第三色次要内容',
    '固定第三色背景上的次要文字与图标',
  ),
  error(
    ThemeColorFamily.error,
    '错误色',
    '错误按钮、危险操作和错误状态',
  ),
  onError(
    ThemeColorFamily.error,
    '错误色内容',
    '错误色背景上的文字与图标',
  ),
  errorContainer(
    ThemeColorFamily.error,
    '错误容器',
    '错误提示和危险状态容器背景',
  ),
  onErrorContainer(
    ThemeColorFamily.error,
    '错误容器内容',
    '错误容器上的文字与图标',
  ),
  surface(
    ThemeColorFamily.surface,
    '页面表面',
    '页面、弹窗和底部面板的基础背景',
  ),
  onSurface(
    ThemeColorFamily.surface,
    '页面表面内容',
    '正文、标题和主要图标',
  ),
  surfaceDim(
    ThemeColorFamily.surface,
    '暗化表面',
    '需要压低层级的页面背景',
  ),
  surfaceBright(
    ThemeColorFamily.surface,
    '亮化表面',
    '需要抬高亮度的页面背景',
  ),
  surfaceContainerLowest(
    ThemeColorFamily.surface,
    '最低层容器',
    '层级最低的容器背景',
  ),
  surfaceContainerLow(
    ThemeColorFamily.surface,
    '低层容器',
    '普通卡片和低层列表块背景',
  ),
  surfaceContainer(
    ThemeColorFamily.surface,
    '普通容器',
    '菜单、浮层和普通容器背景',
  ),
  surfaceContainerHigh(
    ThemeColorFamily.surface,
    '高层容器',
    '弹出菜单和较高层浮层背景',
  ),
  surfaceContainerHighest(
    ThemeColorFamily.surface,
    '最高层容器',
    '最高层弹窗和强分层容器背景',
  ),
  onSurfaceVariant(
    ThemeColorFamily.surface,
    '表面次要内容',
    '说明文字、次要正文和弱化图标',
  ),
  outline(
    ThemeColorFamily.surface,
    '轮廓色',
    '控件轮廓、说明文字和弱化图标',
  ),
  outlineVariant(
    ThemeColorFamily.surface,
    '弱轮廓色',
    '弱边框、分隔线和低强调轮廓',
  ),
  shadow(
    ThemeColorFamily.surface,
    '阴影色',
    '卡片、弹窗和浮层阴影',
  ),
  scrim(
    ThemeColorFamily.surface,
    '遮罩色',
    '模态窗口后方和过渡状态遮罩',
  ),
  inverseSurface(
    ThemeColorFamily.surface,
    '反色表面',
    '与当前页面明暗关系相反的提示背景',
  ),
  onInverseSurface(
    ThemeColorFamily.surface,
    '反色表面内容',
    '反色提示内容及应用中的兼容卡片背景',
  ),
  surfaceTint(
    ThemeColorFamily.surface,
    '表面着色',
    'Material 表面层级的主题色叠加',
  ),
  ;

  const ThemeSchemeColor(this.family, this.label, this.usage);

  final ThemeColorFamily family;
  final String label;
  final String usage;
}

enum ThemeToneRole {
  primaryAccent(
    '主强调色',
    '开关、主按钮、主进度条等',
  ),
  primaryAccentContent(
    '主强调色内容',
    '主强调色上的文字和图标',
  ),
  secondaryAccent(
    '次强调色',
    '“我的”页快捷入口、次级操作等',
  ),
  secondaryAccentContent(
    '次强调色内容',
    '次强调色上的文字和图标',
  ),
  tertiaryAccent(
    '第三强调色',
    '第三层级强调元素',
  ),
  tertiaryAccentContent(
    '第三强调色内容',
    '第三强调色上的文字和图标',
  ),
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
