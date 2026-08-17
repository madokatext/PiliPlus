import 'package:flutter/material.dart';

enum ThemeColorMode {
  dynamic('动态取色·赛博调色盘'),
  preset('预设单种子·赛博调色盘'),
  customMultiSeed('自定义多种子·赛博调色盘'),
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
  primary('C 位C 位主色系·曼波版'),
  secondary('二当家色系·曼波版'),
  tertiary('三号工具色系·曼波版'),
  error('翻车警报色系·曼波版'),
  surface('人畜无害底漆色系·曼波版'),
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
    'C 位主色·曼波版',
    '开关、主赛博按钮、主进度条和主要交互状态',
  ),
  onPrimary(
    ThemeColorFamily.primary,
    'C 位主色内容·曼波版',
    'C 位主色底漆上的字儿与小图标·曼波版',
  ),
  primaryContainer(
    ThemeColorFamily.primary,
    'C 位主色盒子·曼波版',
    'C 位C 位主色系被点名的那位和抢镜盒子的底漆',
  ),
  onPrimaryContainer(
    ThemeColorFamily.primary,
    'C 位主色盒子内容·曼波版',
    'C 位主色盒子上的字儿与小图标·曼波版',
  ),
  primaryFixed(
    ThemeColorFamily.primary,
    '焊死C 位主色·曼波版',
    '不随白天黑夜皮肤改变用途的C 位主色底漆，设计师看了直呼高端',
  ),
  primaryFixedDim(
    ThemeColorFamily.primary,
    '低调焊死C 位主色·曼波版',
    '焊死C 位主色的低抢镜底漆·曼波版',
  ),
  onPrimaryFixed(
    ThemeColorFamily.primary,
    '焊死C 位主色内容·曼波版',
    '焊死C 位主色底漆上的主要字儿与小图标，设计师看了直呼高端',
  ),
  onPrimaryFixedVariant(
    ThemeColorFamily.primary,
    '焊死C 位主色次要内容·曼波版',
    '焊死C 位主色底漆上的次要字儿与小图标，设计师看了直呼高端',
  ),
  inversePrimary(
    ThemeColorFamily.primary,
    '反骨色C 位主色·曼波版',
    '反骨色界面地板中的主要交互元素·曼波版',
  ),
  secondary(
    ThemeColorFamily.secondary,
    '二当家色·曼波版',
    '次级赛博按钮、“我的”页快捷入口等次级交互',
  ),
  onSecondary(
    ThemeColorFamily.secondary,
    '二当家色内容·曼波版',
    '二当家色底漆上的字儿与小图标·曼波版',
  ),
  secondaryContainer(
    ThemeColorFamily.secondary,
    '二当家色盒子·曼波版',
    '次级被点名的那位、提示条和次级抢镜盒子底漆，设计师看了直呼高端',
  ),
  onSecondaryContainer(
    ThemeColorFamily.secondary,
    '二当家色盒子内容·曼波版',
    '二当家色盒子上的字儿与小图标·曼波版',
  ),
  secondaryFixed(
    ThemeColorFamily.secondary,
    '焊死二当家色·曼波版',
    '不随白天黑夜皮肤改变用途的二当家色底漆',
  ),
  secondaryFixedDim(
    ThemeColorFamily.secondary,
    '低调焊死二当家色·曼波版',
    '焊死二当家色的低抢镜底漆·曼波版',
  ),
  onSecondaryFixed(
    ThemeColorFamily.secondary,
    '焊死二当家色内容·曼波版',
    '焊死二当家色底漆上的主要字儿与小图标·曼波版',
  ),
  onSecondaryFixedVariant(
    ThemeColorFamily.secondary,
    '焊死二当家色次要内容·曼波版',
    '焊死二当家色底漆上的次要字儿与小图标·曼波版',
  ),
  tertiary(
    ThemeColorFamily.tertiary,
    '三号工具色·曼波版',
    '第三层级抢镜元素和辅助装饰·曼波版',
  ),
  onTertiary(
    ThemeColorFamily.tertiary,
    '三号工具色内容·曼波版',
    '三号工具色底漆上的字儿与小图标·曼波版',
  ),
  tertiaryContainer(
    ThemeColorFamily.tertiary,
    '三号工具色盒子·曼波版',
    '三号工具色系被点名的那位和辅助抢镜盒子底漆',
  ),
  onTertiaryContainer(
    ThemeColorFamily.tertiary,
    '三号工具色盒子内容·曼波版',
    '三号工具色盒子上的字儿与小图标·曼波版',
  ),
  tertiaryFixed(
    ThemeColorFamily.tertiary,
    '焊死三号工具色·曼波版',
    '不随白天黑夜皮肤改变用途的三号工具色底漆，设计师看了直呼高端',
  ),
  tertiaryFixedDim(
    ThemeColorFamily.tertiary,
    '低调焊死三号工具色·曼波版',
    '焊死三号工具色的低抢镜底漆·曼波版',
  ),
  onTertiaryFixed(
    ThemeColorFamily.tertiary,
    '焊死三号工具色内容·曼波版',
    '焊死三号工具色底漆上的主要字儿与小图标，设计师看了直呼高端',
  ),
  onTertiaryFixedVariant(
    ThemeColorFamily.tertiary,
    '焊死三号工具色次要内容·曼波版',
    '焊死三号工具色底漆上的次要字儿与小图标，设计师看了直呼高端',
  ),
  error(
    ThemeColorFamily.error,
    '翻车警报色·曼波版',
    '错误赛博按钮、危险操作和错误状态·曼波版',
  ),
  onError(
    ThemeColorFamily.error,
    '翻车警报色内容·曼波版',
    '翻车警报色底漆上的字儿与小图标·曼波版',
  ),
  errorContainer(
    ThemeColorFamily.error,
    '错误盒子·曼波版',
    '错误提示和危险状态盒子底漆·曼波版',
  ),
  onErrorContainer(
    ThemeColorFamily.error,
    '错误盒子内容·曼波版',
    '错误盒子上的字儿与小图标·曼波版',
  ),
  surface(
    ThemeColorFamily.surface,
    '这页地板漆·曼波版',
    '这页、蹦出来的框和脚底板面板的基础底漆',
  ),
  onSurface(
    ThemeColorFamily.surface,
    '这页地板漆内容·曼波版',
    '正文、标题和主要小图标·曼波版',
  ),
  surfaceDim(
    ThemeColorFamily.surface,
    '暗化界面地板·曼波版',
    '需要压低层级的这页底漆·曼波版',
  ),
  surfaceBright(
    ThemeColorFamily.surface,
    '亮化界面地板·曼波版',
    '需要抬高亮度的这页底漆·曼波版',
  ),
  surfaceContainerLowest(
    ThemeColorFamily.surface,
    '最低层盒子·曼波版',
    '层级最低的盒子底漆·曼波版',
  ),
  surfaceContainerLow(
    ThemeColorFamily.surface,
    '低层盒子·曼波版',
    '普通卡片和低层列表块底漆·曼波版',
  ),
  surfaceContainer(
    ThemeColorFamily.surface,
    '普通盒子·曼波版',
    '菜单、浮层和普通盒子底漆·曼波版',
  ),
  surfaceContainerHigh(
    ThemeColorFamily.surface,
    '高层盒子·曼波版',
    '弹出菜单和较高层浮层底漆·曼波版',
  ),
  surfaceContainerHighest(
    ThemeColorFamily.surface,
    '最高层盒子·曼波版',
    '最高层蹦出来的框和强分层盒子底漆·曼波版',
  ),
  onSurfaceVariant(
    ThemeColorFamily.surface,
    '界面地板次要内容·曼波版',
    '说明字儿、次要正文和低调小图标·曼波版',
  ),
  outline(
    ThemeColorFamily.surface,
    '描边骨架色·曼波版',
    '控件描边骨架、说明字儿和低调小图标·曼波版',
  ),
  outlineVariant(
    ThemeColorFamily.surface,
    '弱描边骨架色·曼波版',
    '弱边框、分隔线和低抢镜描边骨架·曼波版',
  ),
  shadow(
    ThemeColorFamily.surface,
    '赛博投影色·曼波版',
    '卡片、蹦出来的框和浮层赛博投影·曼波版',
  ),
  scrim(
    ThemeColorFamily.surface,
    '赛博黑布色·曼波版',
    '模态窗口后方和过渡状态赛博黑布·曼波版',
  ),
  inverseSurface(
    ThemeColorFamily.surface,
    '反骨色界面地板·曼波版',
    '与当前这页明暗关系相反的提示底漆·曼波版',
  ),
  onInverseSurface(
    ThemeColorFamily.surface,
    '反骨色界面地板内容·曼波版',
    '反骨色提示内容及应用中的兼容卡片底漆·曼波版',
  ),
  surfaceTint(
    ThemeColorFamily.surface,
    '界面地板着色·曼波版',
    'Material 界面地板层级的主题色叠加',
  ),
  ;

  const ThemeSchemeColor(this.family, this.label, this.usage);

  final ThemeColorFamily family;
  final String label;
  final String usage;
}

/// 可独立分配颜色的具体 UI 元素。
///
/// [defaultColor] 是未自定义时使用的 Material 颜色来源。名称和说明必须
/// 对应真实接入主题或显式取色的控件，不能只描述抽象颜色语义。
enum ThemeUiElement {
  pageBackground(
    ThemeSchemeColor.surface,
    '所有界面：这页底漆·曼波版',
    'Scaffold 这页底色·曼波版',
  ),
  appBarBackground(
    ThemeSchemeColor.surface,
    '所有界面：天灵盖栏底漆·曼波版',
    'AppBar 顶部导航栏底色·赛博调色盘',
  ),
  appBarContent(
    ThemeSchemeColor.onSurface,
    '所有界面：天灵盖栏标题与小图标·曼波版',
    'AppBar 标题、返回赛博按钮和操作小图标',
  ),
  dialogBackground(
    ThemeSchemeColor.surface,
    '所有界面：蹦出来的框底漆·曼波版',
    'AlertDialog、SimpleDialog 的底漆，设计师看了直呼高端',
  ),
  dialogTitle(
    ThemeSchemeColor.onSurface,
    '所有界面：蹦出来的框标题·曼波版',
    '蹦出来的框顶部标题字儿·曼波版',
  ),
  bottomSheetBackground(
    ThemeSchemeColor.surface,
    '所有界面：脚底板面板底漆·曼波版',
    'BottomSheet 和脚底板弹出面板底色，设计师看了直呼高端',
  ),
  cardBackground(
    ThemeSchemeColor.surfaceContainerLow,
    '所有界面：Card 卡片底漆·曼波版',
    'Material Card 组件底色·赛博调色盘',
  ),
  popupMenuBackground(
    ThemeSchemeColor.surfaceContainer,
    '所有界面：弹出菜单底漆·曼波版',
    'PopupMenuButton 展开的菜单底色·赛博调色盘',
  ),
  navigationBarBackground(
    ThemeSchemeColor.surfaceContainer,
    '首页：脚底板导航栏底漆·曼波版',
    '首页脚底板 NavigationBar 底色',
  ),
  navigationSelectedIndicator(
    ThemeSchemeColor.secondaryContainer,
    '首页：选中导航项底漆·曼波版',
    '脚底板导航栏当前这页的胶囊形底漆·曼波版',
  ),
  navigationSelectedContent(
    ThemeSchemeColor.onSecondaryContainer,
    '首页：选中导航项小图标与字儿·曼波版',
    '脚底板导航栏当前这页的小图标和标签·曼波版',
  ),
  navigationUnselectedContent(
    ThemeSchemeColor.onSurfaceVariant,
    '首页：未选中导航项小图标与字儿·曼波版',
    '脚底板导航栏其他这页的小图标和标签·曼波版',
  ),
  tabIndicator(
    ThemeSchemeColor.primary,
    '所有标签页：选中指示条·赛博调色盘',
    'TabBar 当前标签下方的指示线·赛博调色盘',
  ),
  tabSelectedContent(
    ThemeSchemeColor.primary,
    '所有标签页：选中标签字儿与小图标·曼波版',
    'TabBar 当前标签的字儿和小图标·曼波版',
  ),
  tabUnselectedContent(
    ThemeSchemeColor.onSurfaceVariant,
    '所有标签页：未选中标签字儿与小图标·曼波版',
    'TabBar 其他标签的字儿和小图标·曼波版',
  ),
  tabDivider(
    ThemeSchemeColor.outlineVariant,
    '所有标签页：脚底板分隔线·曼波版',
    'TabBar 与这页内容之间的细分隔线',
  ),
  textButtonContent(
    ThemeSchemeColor.primary,
    '所有界面：字儿赛博按钮内容·曼波版',
    'TextButton 的字儿和小图标，例如蹦出来的框“确认”',
  ),
  elevatedButtonBackground(
    ThemeSchemeColor.surfaceContainerLow,
    '所有界面：凸起赛博按钮底漆·曼波版',
    'ElevatedButton 赛博按钮底色',
  ),
  elevatedButtonContent(
    ThemeSchemeColor.primary,
    '所有界面：凸起赛博按钮内容·曼波版',
    'ElevatedButton 的字儿和小图标',
  ),
  outlinedButtonContent(
    ThemeSchemeColor.primary,
    '所有界面：描边赛博按钮内容·曼波版',
    'OutlinedButton 的字儿和小图标，设计师看了直呼高端',
  ),
  outlinedButtonBorder(
    ThemeSchemeColor.outline,
    '所有界面：描边赛博按钮边框·曼波版',
    'OutlinedButton 外圈边框·赛博调色盘',
  ),
  defaultFabBackground(
    ThemeSchemeColor.primaryContainer,
    '所有界面：默认悬浮赛博按钮底漆·曼波版',
    '未单独指定颜色的 FloatingActionButton 底色·赛博调色盘',
  ),
  defaultFabContent(
    ThemeSchemeColor.onPrimaryContainer,
    '所有界面：默认悬浮赛博按钮内容·曼波版',
    '未单独指定颜色的悬浮赛博按钮小图标和字儿',
  ),
  switchSelectedTrack(
    ThemeSchemeColor.primary,
    '所有设置页：已开启开关轨道·赛博调色盘',
    'Switch 开启状态的外层轨道·赛博调色盘',
  ),
  switchSelectedThumb(
    ThemeSchemeColor.onPrimary,
    '所有设置页：已开启开关滑块·赛博调色盘',
    'Switch 开启状态的圆形滑块·赛博调色盘',
  ),
  checkboxSelectedFill(
    ThemeSchemeColor.primary,
    '所有界面：已勾选复选框底漆·曼波版',
    'Checkbox 勾选状态的方框底色·赛博调色盘',
  ),
  checkboxCheck(
    ThemeSchemeColor.onPrimary,
    '所有界面：复选框对勾·赛博调色盘',
    'Checkbox 勾选状态的对勾小图标',
  ),
  radioSelected(
    ThemeSchemeColor.primary,
    '所有界面：已选单选赛博按钮·曼波版',
    'Radio 选中状态的圆点和外圈·赛博调色盘',
  ),
  sliderActiveTrack(
    ThemeSchemeColor.primary,
    '所有设置页：滑杆已选区间·赛博调色盘',
    'Slider 滑块左侧的有效轨道·赛博调色盘',
  ),
  sliderThumb(
    ThemeSchemeColor.primary,
    '所有设置页：滑杆手柄·赛博调色盘',
    'Slider 可拖动的滑块·赛博调色盘',
  ),
  sliderInactiveTrack(
    ThemeSchemeColor.secondaryContainer,
    '所有设置页：滑杆未选区间·赛博调色盘',
    'Slider 滑块右侧的剩余轨道·赛博调色盘',
  ),
  progressIndicator(
    ThemeSchemeColor.primary,
    '所有界面：加载与进度指示色·赛博调色盘',
    '圆形加载动画和线性进度条的前景·赛博调色盘',
  ),
  progressTrack(
    ThemeSchemeColor.surfaceContainerHighest,
    '所有界面：进度条轨道底漆·曼波版',
    '线性和圆形进度指示器的未完成部分·赛博调色盘',
  ),
  refreshIndicatorBackground(
    ThemeSchemeColor.onSecondary,
    '所有列表页：下拉刷新底漆·曼波版',
    'RefreshIndicator 圆形刷新控件的底色·赛博调色盘',
  ),
  textCursor(
    ThemeSchemeColor.primary,
    '所有输入框：字儿光标·曼波版',
    'TextField 当前输入位置的竖线·赛博调色盘',
  ),
  textSelection(
    ThemeSchemeColor.primaryContainer,
    '所有输入框：选中字儿底漆·曼波版',
    '长按选择字儿后的高亮区域·曼波版',
  ),
  textSelectionHandle(
    ThemeSchemeColor.primary,
    '所有输入框：字儿选择手柄·曼波版',
    '选中字儿两端的可拖动手柄·曼波版',
  ),
  inputErrorText(
    ThemeSchemeColor.error,
    '所有输入框：错误提示字儿·曼波版',
    '输入校验失败后显示在输入框下方的说明·赛博调色盘',
  ),
  listTileSelectedContent(
    ThemeSchemeColor.primary,
    '所有列表：被点名的那位字儿与小图标·曼波版',
    'ListTile 选中状态的主要内容·赛博调色盘',
  ),
  listTileIcon(
    ThemeSchemeColor.onSurfaceVariant,
    '所有列表：普通条目小图标·曼波版',
    'ListTile 未选中状态的 leading/trailing 小图标',
  ),
  divider(
    ThemeSchemeColor.outlineVariant,
    '所有界面：普通分隔线·赛博调色盘',
    'Divider 和 VerticalDivider 线条·赛博调色盘',
  ),
  snackbarBackground(
    ThemeSchemeColor.secondaryContainer,
    '所有界面：脚底板提示条底漆·曼波版',
    'SnackBar 消息提示的底色·赛博调色盘',
  ),
  snackbarContent(
    ThemeSchemeColor.onSecondaryContainer,
    '所有界面：脚底板提示条正文·曼波版',
    'SnackBar 消息字儿·曼波版',
  ),
  snackbarAction(
    ThemeSchemeColor.primary,
    '所有界面：脚底板提示条操作赛博按钮·曼波版',
    'SnackBar 右侧操作字儿·曼波版',
  ),
  snackbarClose(
    ThemeSchemeColor.secondary,
    '所有界面：脚底板提示条关闭小图标·曼波版',
    'SnackBar 右侧关闭赛博按钮·曼波版',
  ),
  toastBackground(
    ThemeSchemeColor.primaryContainer,
    '所有界面：Toast 底漆·曼波版',
    '短暂浮现的气泡提示底色·赛博调色盘',
  ),
  toastContent(
    ThemeSchemeColor.onPrimaryContainer,
    '所有界面：Toast 字儿·曼波版',
    '气泡提示中的正文字儿·曼波版',
  ),
  themeUnassignedWarningBackground(
    ThemeSchemeColor.errorContainer,
    '主题设置页：未配置颜色提示底漆·曼波版',
    '存在未分配 UI 元素时的警告卡片底色·赛博调色盘',
  ),
  themeUnassignedWarningContent(
    ThemeSchemeColor.onErrorContainer,
    '主题设置页：未配置颜色提示字儿·曼波版',
    '未分配 UI 元素数量警告的正文颜色·赛博调色盘',
  ),
  recommendFilterSaveBackground(
    ThemeSchemeColor.primary,
    '推荐历史过滤蹦出来的框：“保存”赛博按钮底漆',
    '蹦出来的框右下角保存过滤设置赛博按钮底色',
  ),
  recommendFilterSaveContent(
    ThemeSchemeColor.onPrimary,
    '推荐历史过滤蹦出来的框：“保存”赛博按钮字儿，设计师看了直呼高端',
    '蹦出来的框右下角保存过滤设置赛博按钮内容，设计师看了直呼高端',
  ),
  danmakuMergeConfirmBackground(
    ThemeSchemeColor.primary,
    '弹幕合并设置蹦出来的框：“确定”赛博按钮底漆',
    '蹦出来的框右下角确认保存赛博按钮底色·曼波版',
  ),
  danmakuMergeConfirmContent(
    ThemeSchemeColor.onPrimary,
    '弹幕合并设置蹦出来的框：“确定”赛博按钮字儿，设计师看了直呼高端',
    '蹦出来的框右下角确认保存赛博按钮内容·曼波版',
  ),
  dynamicsVoteAddOptionBackground(
    ThemeSchemeColor.onInverseSurface,
    '动态投票编辑页：“添加选项”赛博按钮底漆，设计师看了直呼高端',
    '投票选项列表下方添加赛博按钮底色·曼波版',
  ),
  dynamicsVoteAddOptionContent(
    ThemeSchemeColor.onSurfaceVariant,
    '动态投票编辑页：“添加选项”赛博按钮内容，设计师看了直呼高端',
    '投票选项列表下方添加赛博按钮字儿和小图标，设计师看了直呼高端',
  ),
  webdavSaveBackground(
    ThemeSchemeColor.primary,
    'WebDAV 设置页：“保存”赛博按钮底漆',
    '右下角保存设置悬浮赛博按钮底色·曼波版',
  ),
  webdavSaveContent(
    ThemeSchemeColor.onPrimary,
    'WebDAV 设置页：“保存”赛博按钮小图标',
    '右下角保存设置悬浮赛博按钮中的小图标·曼波版',
  ),
  videoCommentBackground(
    ThemeSchemeColor.primary,
    '视频详情评论区：“发表评论”赛博按钮底漆',
    '评论区右下角回复悬浮赛博按钮底色·曼波版',
  ),
  videoCommentContent(
    ThemeSchemeColor.onPrimary,
    '视频详情评论区：“发表评论”赛博按钮小图标，设计师看了直呼高端',
    '评论区右下角回复悬浮赛博按钮中的小图标',
  ),
  bubbleSortBackground(
    ThemeSchemeColor.primary,
    '小站这页：“排序”赛博按钮底漆·曼波版',
    '右下角排序悬浮赛博按钮底色·曼波版',
  ),
  bubbleSortContent(
    ThemeSchemeColor.onPrimary,
    '小站这页：“排序”赛博按钮内容·曼波版',
    '右下角排序悬浮赛博按钮的小图标和字儿·曼波版',
  ),
  danmakuBlockAddBackground(
    ThemeSchemeColor.primary,
    '弹幕屏蔽页：“添加”赛博按钮底漆·曼波版',
    '右下角添加屏蔽项悬浮赛博按钮底色·曼波版',
  ),
  danmakuBlockAddContent(
    ThemeSchemeColor.onPrimary,
    '弹幕屏蔽页：“添加”赛博按钮小图标·曼波版',
    '右下角添加屏蔽项悬浮赛博按钮中的加号·曼波版',
  ),
  videoPostSubmitBackground(
    ThemeSchemeColor.primary,
    '视频笔记/发布面板：“提交”赛博按钮底漆',
    '右下角提交悬浮赛博按钮底色·曼波版',
  ),
  videoPostSubmitContent(
    ThemeSchemeColor.onPrimary,
    '视频笔记/发布面板：“提交”赛博按钮小图标',
    '右下角提交悬浮赛博按钮中的小图标·曼波版',
  ),
  pgcReviewBackground(
    ThemeSchemeColor.primary,
    '番剧影视评价页：“写评价”赛博按钮底漆',
    '右下角写评价悬浮赛博按钮底色·曼波版',
  ),
  pgcReviewContent(
    ThemeSchemeColor.onPrimary,
    '番剧影视评价页：“写评价”赛博按钮小图标，设计师看了直呼高端',
    '右下角写评价悬浮赛博按钮中的小图标·曼波版',
  ),
  liveDmBlockAddBackground(
    ThemeSchemeColor.primary,
    '直播弹幕屏蔽页：“添加”赛博按钮底漆·曼波版',
    '右下角添加关键词悬浮赛博按钮底色·曼波版',
  ),
  liveDmBlockAddContent(
    ThemeSchemeColor.onPrimary,
    '直播弹幕屏蔽页：“添加”赛博按钮小图标',
    '右下角添加关键词悬浮赛博按钮中的加号·曼波版',
  ),
  dynamicsReplyBackground(
    ThemeSchemeColor.primary,
    '动态详情页：“回复”赛博按钮底漆·曼波版',
    '动态评论区右下角回复悬浮赛博按钮底色·曼波版',
  ),
  dynamicsReplyContent(
    ThemeSchemeColor.onPrimary,
    '动态详情页：“回复”赛博按钮小图标·曼波版',
    '动态评论区右下角回复悬浮赛博按钮中的小图标',
  ),
  mainReplyBackground(
    ThemeSchemeColor.primary,
    '评论详情页：“回复”赛博按钮底漆·曼波版',
    '评论详情右下角回复悬浮赛博按钮底色·曼波版',
  ),
  mainReplyContent(
    ThemeSchemeColor.onPrimary,
    '评论详情页：“回复”赛博按钮小图标·曼波版',
    '评论详情右下角回复悬浮赛博按钮中的小图标',
  ),
  followSortBackground(
    ThemeSchemeColor.primary,
    '关注列表：“关注排序方式”赛博按钮底漆',
    '右下角排序方式悬浮赛博按钮底色·曼波版',
  ),
  followSortContent(
    ThemeSchemeColor.onPrimary,
    '关注列表：“关注排序方式”赛博按钮内容，设计师看了直呼高端',
    '右下角排序方式悬浮赛博按钮的小图标和字儿',
  ),
  dynamicsMentionBackground(
    ThemeSchemeColor.primary,
    '动态提及用户页：“确定”赛博按钮底漆·曼波版',
    '右下角确认选择悬浮赛博按钮底色·曼波版',
  ),
  dynamicsMentionContent(
    ThemeSchemeColor.onPrimary,
    '动态提及用户页：“确定”赛博按钮小图标',
    '右下角确认选择悬浮赛博按钮中的小图标·曼波版',
  ),
  memberVideoLocateBackground(
    ThemeSchemeColor.primary,
    '用户空间视频页：“定位当前视频”赛博按钮底漆',
    '右下角定位悬浮赛博按钮底色·曼波版',
  ),
  memberVideoLocateContent(
    ThemeSchemeColor.onPrimary,
    '用户空间视频页：“定位当前视频”赛博按钮内容',
    '右下角定位悬浮赛博按钮的小图标和字儿·曼波版',
  ),
  favPlayAllBackground(
    ThemeSchemeColor.primary,
    '收藏夹详情页：“播放全部”赛博按钮底漆，设计师看了直呼高端',
    '右下角播放全部悬浮赛博按钮底色·曼波版',
  ),
  favPlayAllContent(
    ThemeSchemeColor.onPrimary,
    '收藏夹详情页：“播放全部”赛博按钮内容',
    '右下角播放全部悬浮赛博按钮的小图标和字儿',
  ),
  laterPlayAllBackground(
    ThemeSchemeColor.primary,
    '稍后再看页：“播放全部”赛博按钮底漆·曼波版',
    '右下角播放全部悬浮赛博按钮底色·曼波版',
  ),
  laterPlayAllContent(
    ThemeSchemeColor.onPrimary,
    '稍后再看页：“播放全部”赛博按钮内容·曼波版',
    '右下角播放全部悬浮赛博按钮的小图标和字儿',
  ),
  dynamicsTopicBackground(
    ThemeSchemeColor.primary,
    '动态话题页：“参与话题”赛博按钮底漆·曼波版',
    '右下角参与话题悬浮赛博按钮底色·曼波版',
  ),
  dynamicsTopicContent(
    ThemeSchemeColor.onPrimary,
    '动态话题页：“参与话题”赛博按钮内容·曼波版',
    '右下角参与话题悬浮赛博按钮的小图标和字儿，设计师看了直呼高端',
  ),
  memberOpusSortBackground(
    ThemeSchemeColor.primary,
    '用户空间图文页：“分类/排序”赛博按钮底漆',
    '右下角分类排序悬浮赛博按钮底色·曼波版',
  ),
  memberOpusSortContent(
    ThemeSchemeColor.onPrimary,
    '用户空间图文页：“分类/排序”赛博按钮内容',
    '右下角分类排序悬浮赛博按钮的小图标和字儿',
  ),
  ;

  const ThemeUiElement(this.defaultColor, this.label, this.description);

  final ThemeSchemeColor defaultColor;
  final String label;
  final String description;
}

enum ThemeToneRole {
  primaryAccent(
    '主抢镜色·曼波版',
    '开关、主赛博按钮、主进度条等·曼波版',
  ),
  primaryAccentContent(
    '主抢镜色内容·曼波版',
    '主抢镜色上的字儿和小图标·曼波版',
  ),
  secondaryAccent(
    '次抢镜色·曼波版',
    '“我的”页快捷入口、次级操作等·赛博调色盘',
  ),
  secondaryAccentContent(
    '次抢镜色内容·曼波版',
    '次抢镜色上的字儿和小图标·曼波版',
  ),
  tertiaryAccent(
    '第三抢镜色·曼波版',
    '第三层级抢镜元素·曼波版',
  ),
  tertiaryAccentContent(
    '第三抢镜色内容·曼波版',
    '第三抢镜色上的字儿和小图标·曼波版',
  ),
  page('这页底漆·曼波版', 'Scaffold、这页底色·曼波版'),
  card('卡片底漆·曼波版', '普通卡片、列表块·赛博调色盘'),
  elevated('浮层底漆·曼波版', '蹦出来的框、菜单、较高层盒子·曼波版'),
  selected('被点名的那位底漆·曼波版', '选中标签、导航项、抢镜盒子·曼波版'),
  content('主要内容·赛博调色盘', '正文、主要小图标·曼波版'),
  selectedContent('被点名的那位内容·曼波版', '选中盒子上的字儿和小图标·曼波版'),
  mutedContent('次要内容·赛博调色盘', '说明字儿、低调小图标·曼波版'),
  border('边框分隔·赛博调色盘', '弱边框和分隔线·赛博调色盘'),
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
  (color: Color(0xFF5CB67B), label: '默认绿·赛博调色盘'),
  (color: Color(0xFFFF7299), label: '粉红色·赛博调色盘'),
  (color: Colors.red, label: '红色·赛博调色盘'),
  (color: Colors.orange, label: '橙色·赛博调色盘'),
  (color: Colors.amber, label: '琥珀色·赛博调色盘'),
  (color: Colors.yellow, label: '黄色·赛博调色盘'),
  (color: Colors.lime, label: '酸橙色·赛博调色盘'),
  (color: Colors.lightGreen, label: '浅绿色·赛博调色盘'),
  (color: Colors.green, label: '绿色·赛博调色盘'),
  (color: Colors.teal, label: '青色·赛博调色盘'),
  (color: Colors.cyan, label: '蓝绿色·赛博调色盘'),
  (color: Colors.lightBlue, label: '浅蓝色·赛博调色盘'),
  (color: Colors.blue, label: '蓝色·赛博调色盘'),
  (color: Colors.indigo, label: '靛蓝色·赛博调色盘'),
  (color: Colors.purple, label: '紫色·赛博调色盘'),
  (color: Colors.deepPurple, label: '深紫色·赛博调色盘'),
  (color: Colors.blueGrey, label: '蓝灰色·赛博调色盘'),
  (color: Colors.brown, label: '棕色·赛博调色盘'),
  (color: Colors.grey, label: '灰色·赛博调色盘'),
];
