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

/// 可独立分配颜色的具体 UI 元素。
///
/// [defaultColor] 是未自定义时使用的 Material 颜色来源。名称和说明必须
/// 对应真实接入主题或显式取色的控件，不能只描述抽象颜色语义。
enum ThemeUiElement {
  pageBackground(
    ThemeSchemeColor.surface,
    '所有界面：页面背景',
    'Scaffold 页面底色',
  ),
  appBarBackground(
    ThemeSchemeColor.surface,
    '所有界面：顶部栏背景',
    'AppBar 顶部导航栏底色',
  ),
  appBarContent(
    ThemeSchemeColor.onSurface,
    '所有界面：顶部栏标题与图标',
    'AppBar 标题、返回按钮和操作图标',
  ),
  dialogBackground(
    ThemeSchemeColor.surface,
    '所有界面：弹窗背景',
    'AlertDialog、SimpleDialog 的背景',
  ),
  dialogTitle(
    ThemeSchemeColor.onSurface,
    '所有界面：弹窗标题',
    '弹窗顶部标题文字',
  ),
  bottomSheetBackground(
    ThemeSchemeColor.surface,
    '所有界面：底部面板背景',
    'BottomSheet 和底部弹出面板底色',
  ),
  cardBackground(
    ThemeSchemeColor.surfaceContainerLow,
    '所有界面：Card 卡片背景',
    'Material Card 组件底色',
  ),
  popupMenuBackground(
    ThemeSchemeColor.surfaceContainer,
    '所有界面：弹出菜单背景',
    'PopupMenuButton 展开的菜单底色',
  ),
  navigationBarBackground(
    ThemeSchemeColor.surfaceContainer,
    '首页：底部导航栏背景',
    '首页底部 NavigationBar 底色',
  ),
  navigationSelectedIndicator(
    ThemeSchemeColor.secondaryContainer,
    '首页：选中导航项背景',
    '底部导航栏当前页面的胶囊形背景',
  ),
  navigationSelectedContent(
    ThemeSchemeColor.onSecondaryContainer,
    '首页：选中导航项图标与文字',
    '底部导航栏当前页面的图标和标签',
  ),
  navigationUnselectedContent(
    ThemeSchemeColor.onSurfaceVariant,
    '首页：未选中导航项图标与文字',
    '底部导航栏其他页面的图标和标签',
  ),
  tabIndicator(
    ThemeSchemeColor.primary,
    '所有标签页：选中指示条',
    'TabBar 当前标签下方的指示线',
  ),
  tabSelectedContent(
    ThemeSchemeColor.primary,
    '所有标签页：选中标签文字与图标',
    'TabBar 当前标签的文字和图标',
  ),
  tabUnselectedContent(
    ThemeSchemeColor.onSurfaceVariant,
    '所有标签页：未选中标签文字与图标',
    'TabBar 其他标签的文字和图标',
  ),
  tabDivider(
    ThemeSchemeColor.outlineVariant,
    '所有标签页：底部分隔线',
    'TabBar 与页面内容之间的细分隔线',
  ),
  textButtonContent(
    ThemeSchemeColor.primary,
    '所有界面：文字按钮内容',
    'TextButton 的文字和图标，例如弹窗“确认”',
  ),
  elevatedButtonBackground(
    ThemeSchemeColor.surfaceContainerLow,
    '所有界面：凸起按钮背景',
    'ElevatedButton 按钮底色',
  ),
  elevatedButtonContent(
    ThemeSchemeColor.primary,
    '所有界面：凸起按钮内容',
    'ElevatedButton 的文字和图标',
  ),
  outlinedButtonContent(
    ThemeSchemeColor.primary,
    '所有界面：描边按钮内容',
    'OutlinedButton 的文字和图标',
  ),
  outlinedButtonBorder(
    ThemeSchemeColor.outline,
    '所有界面：描边按钮边框',
    'OutlinedButton 外圈边框',
  ),
  defaultFabBackground(
    ThemeSchemeColor.primaryContainer,
    '所有界面：默认悬浮按钮背景',
    '未单独指定颜色的 FloatingActionButton 底色',
  ),
  defaultFabContent(
    ThemeSchemeColor.onPrimaryContainer,
    '所有界面：默认悬浮按钮内容',
    '未单独指定颜色的悬浮按钮图标和文字',
  ),
  switchSelectedTrack(
    ThemeSchemeColor.primary,
    '所有设置页：已开启开关轨道',
    'Switch 开启状态的外层轨道',
  ),
  switchSelectedThumb(
    ThemeSchemeColor.onPrimary,
    '所有设置页：已开启开关滑块',
    'Switch 开启状态的圆形滑块',
  ),
  checkboxSelectedFill(
    ThemeSchemeColor.primary,
    '所有界面：已勾选复选框背景',
    'Checkbox 勾选状态的方框底色',
  ),
  checkboxCheck(
    ThemeSchemeColor.onPrimary,
    '所有界面：复选框对勾',
    'Checkbox 勾选状态的对勾图标',
  ),
  radioSelected(
    ThemeSchemeColor.primary,
    '所有界面：已选单选按钮',
    'Radio 选中状态的圆点和外圈',
  ),
  sliderActiveTrack(
    ThemeSchemeColor.primary,
    '所有设置页：滑杆已选区间',
    'Slider 滑块左侧的有效轨道',
  ),
  sliderThumb(
    ThemeSchemeColor.primary,
    '所有设置页：滑杆手柄',
    'Slider 可拖动的滑块',
  ),
  sliderInactiveTrack(
    ThemeSchemeColor.secondaryContainer,
    '所有设置页：滑杆未选区间',
    'Slider 滑块右侧的剩余轨道',
  ),
  progressIndicator(
    ThemeSchemeColor.primary,
    '所有界面：加载与进度指示色',
    '圆形加载动画和线性进度条的前景',
  ),
  progressTrack(
    ThemeSchemeColor.surfaceContainerHighest,
    '所有界面：进度条轨道背景',
    '线性和圆形进度指示器的未完成部分',
  ),
  refreshIndicatorBackground(
    ThemeSchemeColor.onSecondary,
    '所有列表页：下拉刷新背景',
    'RefreshIndicator 圆形刷新控件的底色',
  ),
  textCursor(
    ThemeSchemeColor.primary,
    '所有输入框：文字光标',
    'TextField 当前输入位置的竖线',
  ),
  textSelection(
    ThemeSchemeColor.primaryContainer,
    '所有输入框：选中文字背景',
    '长按选择文字后的高亮区域',
  ),
  textSelectionHandle(
    ThemeSchemeColor.primary,
    '所有输入框：文字选择手柄',
    '选中文字两端的可拖动手柄',
  ),
  inputErrorText(
    ThemeSchemeColor.error,
    '所有输入框：错误提示文字',
    '输入校验失败后显示在输入框下方的说明',
  ),
  listTileSelectedContent(
    ThemeSchemeColor.primary,
    '所有列表：选中项文字与图标',
    'ListTile 选中状态的主要内容',
  ),
  listTileIcon(
    ThemeSchemeColor.onSurfaceVariant,
    '所有列表：普通条目图标',
    'ListTile 未选中状态的 leading/trailing 图标',
  ),
  divider(
    ThemeSchemeColor.outlineVariant,
    '所有界面：普通分隔线',
    'Divider 和 VerticalDivider 线条',
  ),
  snackbarBackground(
    ThemeSchemeColor.secondaryContainer,
    '所有界面：底部提示条背景',
    'SnackBar 消息提示的底色',
  ),
  snackbarContent(
    ThemeSchemeColor.onSecondaryContainer,
    '所有界面：底部提示条正文',
    'SnackBar 消息文字',
  ),
  snackbarAction(
    ThemeSchemeColor.primary,
    '所有界面：底部提示条操作按钮',
    'SnackBar 右侧操作文字',
  ),
  snackbarClose(
    ThemeSchemeColor.secondary,
    '所有界面：底部提示条关闭图标',
    'SnackBar 右侧关闭按钮',
  ),
  themeUnassignedWarningBackground(
    ThemeSchemeColor.errorContainer,
    '主题设置页：未配置颜色提示背景',
    '存在未分配 UI 元素时的警告卡片底色',
  ),
  themeUnassignedWarningContent(
    ThemeSchemeColor.onErrorContainer,
    '主题设置页：未配置颜色提示文字',
    '未分配 UI 元素数量警告的正文颜色',
  ),
  recommendFilterSaveBackground(
    ThemeSchemeColor.primary,
    '推荐历史过滤弹窗：“保存”按钮背景',
    '弹窗右下角保存过滤设置按钮底色',
  ),
  recommendFilterSaveContent(
    ThemeSchemeColor.onPrimary,
    '推荐历史过滤弹窗：“保存”按钮文字',
    '弹窗右下角保存过滤设置按钮内容',
  ),
  danmakuMergeConfirmBackground(
    ThemeSchemeColor.primary,
    '弹幕合并设置弹窗：“确定”按钮背景',
    '弹窗右下角确认保存按钮底色',
  ),
  danmakuMergeConfirmContent(
    ThemeSchemeColor.onPrimary,
    '弹幕合并设置弹窗：“确定”按钮文字',
    '弹窗右下角确认保存按钮内容',
  ),
  dynamicsVoteAddOptionBackground(
    ThemeSchemeColor.onInverseSurface,
    '动态投票编辑页：“添加选项”按钮背景',
    '投票选项列表下方添加按钮底色',
  ),
  dynamicsVoteAddOptionContent(
    ThemeSchemeColor.onSurfaceVariant,
    '动态投票编辑页：“添加选项”按钮内容',
    '投票选项列表下方添加按钮文字和图标',
  ),
  webdavSaveBackground(
    ThemeSchemeColor.primary,
    'WebDAV 设置页：“保存”按钮背景',
    '右下角保存设置悬浮按钮底色',
  ),
  webdavSaveContent(
    ThemeSchemeColor.onPrimary,
    'WebDAV 设置页：“保存”按钮图标',
    '右下角保存设置悬浮按钮中的图标',
  ),
  videoCommentBackground(
    ThemeSchemeColor.primary,
    '视频详情评论区：“发表评论”按钮背景',
    '评论区右下角回复悬浮按钮底色',
  ),
  videoCommentContent(
    ThemeSchemeColor.onPrimary,
    '视频详情评论区：“发表评论”按钮图标',
    '评论区右下角回复悬浮按钮中的图标',
  ),
  bubbleSortBackground(
    ThemeSchemeColor.primary,
    '小站页面：“排序”按钮背景',
    '右下角排序悬浮按钮底色',
  ),
  bubbleSortContent(
    ThemeSchemeColor.onPrimary,
    '小站页面：“排序”按钮内容',
    '右下角排序悬浮按钮的图标和文字',
  ),
  danmakuBlockAddBackground(
    ThemeSchemeColor.primary,
    '弹幕屏蔽页：“添加”按钮背景',
    '右下角添加屏蔽项悬浮按钮底色',
  ),
  danmakuBlockAddContent(
    ThemeSchemeColor.onPrimary,
    '弹幕屏蔽页：“添加”按钮图标',
    '右下角添加屏蔽项悬浮按钮中的加号',
  ),
  videoPostSubmitBackground(
    ThemeSchemeColor.primary,
    '视频笔记/发布面板：“提交”按钮背景',
    '右下角提交悬浮按钮底色',
  ),
  videoPostSubmitContent(
    ThemeSchemeColor.onPrimary,
    '视频笔记/发布面板：“提交”按钮图标',
    '右下角提交悬浮按钮中的图标',
  ),
  pgcReviewBackground(
    ThemeSchemeColor.primary,
    '番剧影视评价页：“写评价”按钮背景',
    '右下角写评价悬浮按钮底色',
  ),
  pgcReviewContent(
    ThemeSchemeColor.onPrimary,
    '番剧影视评价页：“写评价”按钮图标',
    '右下角写评价悬浮按钮中的图标',
  ),
  liveDmBlockAddBackground(
    ThemeSchemeColor.primary,
    '直播弹幕屏蔽页：“添加”按钮背景',
    '右下角添加关键词悬浮按钮底色',
  ),
  liveDmBlockAddContent(
    ThemeSchemeColor.onPrimary,
    '直播弹幕屏蔽页：“添加”按钮图标',
    '右下角添加关键词悬浮按钮中的加号',
  ),
  dynamicsReplyBackground(
    ThemeSchemeColor.primary,
    '动态详情页：“回复”按钮背景',
    '动态评论区右下角回复悬浮按钮底色',
  ),
  dynamicsReplyContent(
    ThemeSchemeColor.onPrimary,
    '动态详情页：“回复”按钮图标',
    '动态评论区右下角回复悬浮按钮中的图标',
  ),
  mainReplyBackground(
    ThemeSchemeColor.primary,
    '评论详情页：“回复”按钮背景',
    '评论详情右下角回复悬浮按钮底色',
  ),
  mainReplyContent(
    ThemeSchemeColor.onPrimary,
    '评论详情页：“回复”按钮图标',
    '评论详情右下角回复悬浮按钮中的图标',
  ),
  followSortBackground(
    ThemeSchemeColor.primary,
    '关注列表：“关注排序方式”按钮背景',
    '右下角排序方式悬浮按钮底色',
  ),
  followSortContent(
    ThemeSchemeColor.onPrimary,
    '关注列表：“关注排序方式”按钮内容',
    '右下角排序方式悬浮按钮的图标和文字',
  ),
  dynamicsMentionBackground(
    ThemeSchemeColor.primary,
    '动态提及用户页：“确定”按钮背景',
    '右下角确认选择悬浮按钮底色',
  ),
  dynamicsMentionContent(
    ThemeSchemeColor.onPrimary,
    '动态提及用户页：“确定”按钮图标',
    '右下角确认选择悬浮按钮中的图标',
  ),
  memberVideoLocateBackground(
    ThemeSchemeColor.primary,
    '用户空间视频页：“定位当前视频”按钮背景',
    '右下角定位悬浮按钮底色',
  ),
  memberVideoLocateContent(
    ThemeSchemeColor.onPrimary,
    '用户空间视频页：“定位当前视频”按钮内容',
    '右下角定位悬浮按钮的图标和文字',
  ),
  favPlayAllBackground(
    ThemeSchemeColor.primary,
    '收藏夹详情页：“播放全部”按钮背景',
    '右下角播放全部悬浮按钮底色',
  ),
  favPlayAllContent(
    ThemeSchemeColor.onPrimary,
    '收藏夹详情页：“播放全部”按钮内容',
    '右下角播放全部悬浮按钮的图标和文字',
  ),
  laterPlayAllBackground(
    ThemeSchemeColor.primary,
    '稍后再看页：“播放全部”按钮背景',
    '右下角播放全部悬浮按钮底色',
  ),
  laterPlayAllContent(
    ThemeSchemeColor.onPrimary,
    '稍后再看页：“播放全部”按钮内容',
    '右下角播放全部悬浮按钮的图标和文字',
  ),
  dynamicsTopicBackground(
    ThemeSchemeColor.primary,
    '动态话题页：“参与话题”按钮背景',
    '右下角参与话题悬浮按钮底色',
  ),
  dynamicsTopicContent(
    ThemeSchemeColor.onPrimary,
    '动态话题页：“参与话题”按钮内容',
    '右下角参与话题悬浮按钮的图标和文字',
  ),
  memberOpusSortBackground(
    ThemeSchemeColor.primary,
    '用户空间图文页：“分类/排序”按钮背景',
    '右下角分类排序悬浮按钮底色',
  ),
  memberOpusSortContent(
    ThemeSchemeColor.onPrimary,
    '用户空间图文页：“分类/排序”按钮内容',
    '右下角分类排序悬浮按钮的图标和文字',
  ),
  ;

  const ThemeUiElement(this.defaultColor, this.label, this.description);

  final ThemeSchemeColor defaultColor;
  final String label;
  final String description;
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
