import 'dart:io';
import 'dart:math' as math;

import 'package:PiliPlus/common/widgets/color_palette.dart';
import 'package:PiliPlus/common/widgets/custom_toast.dart';
import 'package:PiliPlus/common/widgets/dialog/dialog.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/scale_app.dart';
import 'package:PiliPlus/common/widgets/stateful_builder.dart';
import 'package:PiliPlus/models/common/bar_hide_type.dart';
import 'package:PiliPlus/models/common/dynamic/dynamic_badge_mode.dart';
import 'package:PiliPlus/models/common/dynamic/up_panel_position.dart';
import 'package:PiliPlus/models/common/home_tab_type.dart';
import 'package:PiliPlus/models/common/msg/msg_unread_type.dart';
import 'package:PiliPlus/models/common/nav_bar_config.dart';
import 'package:PiliPlus/models/common/theme/theme_color_type.dart';
import 'package:PiliPlus/models/common/theme/theme_type.dart';
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:PiliPlus/pages/mine/controller.dart';
import 'package:PiliPlus/pages/setting/models/model.dart';
import 'package:PiliPlus/pages/setting/slide_color_picker.dart';
import 'package:PiliPlus/pages/setting/widgets/dual_slider_dialog.dart';
import 'package:PiliPlus/pages/setting/widgets/multi_select_dialog.dart';
import 'package:PiliPlus/pages/setting/widgets/select_dialog.dart';
import 'package:PiliPlus/pages/setting/widgets/slider_dialog.dart';
import 'package:PiliPlus/pages/setting/utils/local_font_setting.dart';
import 'package:PiliPlus/plugin/pl_player/utils/fullscreen.dart';
import 'package:PiliPlus/utils/extension/file_ext.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:PiliPlus/utils/extension/num_ext.dart';
import 'package:PiliPlus/utils/extension/theme_ext.dart';
import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/local_font_manager.dart';
import 'package:PiliPlus/utils/path_utils.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/theme_utils.dart';
import 'package:flutter/material.dart' hide StatefulBuilder;
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:path/path.dart' as path;

List<SettingsModel> get styleSettings => [
  if (PlatformUtils.isDesktop) ...[
    const SwitchModel(
      title: '亮出来窗口标题栏',
      leading: Icon(Icons.window),
      setKey: SettingBoxKey.showWindowTitleBar,
      defaultVal: true,
      needReboot: true,
    ),
    const SwitchModel(
      title: '亮出来托盘图标',
      leading: Icon(Icons.donut_large_rounded),
      setKey: SettingBoxKey.showTrayIcon,
      defaultVal: true,
      needReboot: true,
    ),
  ],
  if (Platform.isLinux) _useSSDModel(),
  SwitchModel(
    title: '横着炫适配',
    subtitle: '解封横着炫布局与逻辑，平板、折叠屏等可启动；建议铺满屏方向设为【不改变眼下这坨方向】',
    leading: const Icon(Icons.phonelink_outlined),
    setKey: SettingBoxKey.horizontalScreen,
    defaultVal: Pref.horizontalScreen,
    onChanged: (value) {
      if (value) {
        fullMode();
      } else {
        portraitUpMode();
      }
    },
  ),
  const SwitchModel(
    title: '改用侧边栏，鼠鼠我啊',
    subtitle: '启动后底栏与顶栏被替换，且相关赛博调参失效，已老实',
    leading: Icon(Icons.chrome_reader_mode_outlined),
    setKey: SettingBoxKey.useSideBar,
    defaultVal: false,
    needReboot: true,
  ),
  SplitModel(
    normalModel: const NormalModel.split(
      title: 'App赛博字骨字重，这把高端局',
      subtitle: '点击赛博调参',
      leading: Icon(Icons.text_fields),
    ),
    switchModel: SwitchModel.split(
      defaultVal: false,
      setKey: SettingBoxKey.appFontWeight,
      onChanged: (_) => Get.updateMyAppTheme(),
      onTap: _showFontWeightDialog,
    ),
  ),
  NormalModel(
    title: 'App 中文赛博字骨，优势在我',
    getSubtitle: () =>
        '眼下这坨：${LocalFontManager.selectionLabel(.appChinese)}',
    leading: const Icon(Icons.translate),
    onTap: (context, setState) => showLocalFontSetting(
      context,
      slot: .appChinese,
      onChanged: () {
        setState();
        Get.updateMyAppTheme();
      },
    ),
  ),
  NormalModel(
    title: 'App 英文赛博字骨',
    getSubtitle: () =>
        '眼下这坨：${LocalFontManager.selectionLabel(.appEnglish)}，CPU 都看沉默了',
    leading: const Icon(Icons.font_download_outlined),
    onTap: (context, setState) => showLocalFontSetting(
      context,
      slot: .appEnglish,
      onChanged: () {
        setState();
        Get.updateMyAppTheme();
      },
    ),
  ),
  NormalModel(
    title: '界面缩放，曼波',
    getSubtitle: () => '眼下这坨缩放比例：${Pref.uiScale.toStringAsFixed(2)}',
    leading: const Icon(Icons.zoom_in_outlined),
    onTap: _showUiScaleDialog,
  ),
  NormalModel(
    title: '页面过渡纸片人运动会，我嘞个豆',
    leading: const Icon(Icons.animation),
    getSubtitle: () => '眼下这坨：${Pref.pageTransition.name}',
    onTap: _showTransitionDialog,
  ),
  const SwitchModel(
    title: '优化平板导航栏，CPU 都看沉默了',
    leading: Icon(Icons.auto_fix_high),
    setKey: SettingBoxKey.optTabletNav,
    defaultVal: true,
    needReboot: true,
  ),
  const SwitchModel(
    title: 'MD3样式底栏，鼠鼠我啊',
    subtitle: 'Material You设计规范底栏，啪一下封印可变窄',
    leading: Icon(Icons.design_services_outlined),
    setKey: SettingBoxKey.enableMYBar,
    defaultVal: true,
    needReboot: true,
  ),
  const SwitchModel(
    title: '悬浮底栏，CPU 都看沉默了',
    leading: Icon(MdiIcons.soundbar),
    setKey: SettingBoxKey.floatingNavBar,
    defaultVal: false,
    needReboot: true,
  ),
  NormalModel(
    title: '首页顶部分类栏竖向身高',
    getSubtitle: () => '眼下这坨：${Pref.homeTabBarHeight.toStringAsFixed(0)}dp',
    leading: const Icon(Icons.height),
    onTap: _showHomeTabBarHeightDialog,
  ),
  NormalModel(
    title: '首页传统底栏底部留白，曼波',
    getSubtitle: () {
      final value = Pref.legacyBottomBarBottomPadding;
      final current = value == null
          ? '跟随系统大爹安全区，已老实'
          : '${value.toStringAsFixed(0)}dp';
      return '眼下这坨：$current；仅影响未解封悬浮底栏和MD3样式底栏时的传统底栏，功德+1';
    },
    leading: const Icon(Icons.vertical_align_bottom_outlined),
    onTap: _showLegacyBottomBarBottomPaddingDialog,
  ),
  NormalModel(
    leading: const Icon(Icons.calendar_view_week_outlined),
    title: '列表横向体宽（dp）限制，优势在我',
    getSubtitle: () =>
        '眼下这坨: 主页${Pref.recommendCardWidth.toInt()}dp 剩下那坨${Pref.smallCardWidth.toInt()}dp，屏幕横向体宽:${MediaQuery.widthOf(Get.context!).toPrecision(2)}dp。横向体宽越小列数越多。，我嘞个豆',
    onTap: _showCardWidthDialog,
  ),
  NormalModel(
    leading: const Icon(Icons.rounded_corner),
    title: '卡片边角磨圆半径，已老实',
    getSubtitle: () =>
        '眼下这坨：${Pref.cardRadius.toStringAsFixed(0)}dp（0为直角），曼波',
    onTap: _showCardRadiusDialog,
  ),
  SwitchModel(
    title: '首页算法喂饭卡片时长与统计同行',
    subtitle: '时长亮出来在开炫量、满屏飘字数同一行的最右侧',
    leading: const Icon(Icons.timer_outlined),
    setKey: SettingBoxKey.recommendDurationInStatRow,
    defaultVal: false,
    onChanged: (_) => Get.appUpdate(),
  ),
  NormalModel(
    title: '首页卡片开炫量与满屏飘字数间距',
    getSubtitle: () =>
        '眼下这坨：${Pref.recommendStatSpacing.toStringAsFixed(0)}dp，包的',
    leading: const Icon(Icons.space_bar),
    onTap: _showRecommendStatSpacingDialog,
  ),
  const SwitchModel(
    title: '开炫页踢出群聊安全留白距离',
    leading: Icon(Icons.fit_screen_outlined),
    setKey: SettingBoxKey.removeSafeArea,
    defaultVal: false,
  ),
  const SwitchModel(
    title: '电子榨菜开炫页使用深色皮肤人格',
    leading: Icon(Icons.dark_mode_outlined),
    setKey: SettingBoxKey.darkVideoPage,
    defaultVal: false,
  ),
  SwitchModel(
    title: '互联网近况页解封瀑布流',
    subtitle: '啪一下封印会亮出来为单列，启动！',
    leading: const Icon(Icons.view_array_outlined),
    setKey: SettingBoxKey.dynamicsWaterfallFlow,
    defaultVal: Pref.horizontalScreen,
    needReboot: true,
  ),
  NormalModel(
    title: '互联网近况页UP主亮出来位置',
    leading: const Icon(Icons.person_outlined),
    getSubtitle: () => '眼下这坨：${Pref.upPanelPosition.label}，属实绷不住',
    onTap: _showUpPosDialog,
  ),
  const SwitchModel(
    title: '互联网近况页亮出来所有已赛博蹲点UP主，不是哥们',
    leading: Icon(Icons.people_alt_outlined),
    setKey: SettingBoxKey.dynamicsShowAllFollowedUp,
    defaultVal: false,
    needReboot: true,
  ),
  const SwitchModel(
    title: '互联网近况页摊开讲正在赛博围观UP列表',
    leading: Icon(Icons.live_tv),
    setKey: SettingBoxKey.expandDynLivePanel,
    defaultVal: false,
    needReboot: true,
  ),
  NormalModel(
    title: '互联网近况未读标记，功德+1',
    leading: const Icon(Icons.motion_photos_on_outlined),
    getSubtitle: () => '眼下这坨标记样式：${Pref.dynamicBadgeType.desc}，曼波',
    onTap: _showDynBadgeDialog,
  ),
  NormalModel(
    title: '赛博小纸条未读标记',
    leading: const Icon(MdiIcons.bellBadgeOutline),
    getSubtitle: () => '眼下这坨标记样式：${Pref.msgBadgeMode.desc}，这把高端局',
    onTap: _showMsgBadgeDialog,
  ),
  NormalModel(
    onTap: _showMsgUnReadDialog,
    title: '赛博小纸条未读类型，启动！',
    leading: const Icon(MdiIcons.bellCogOutline),
    getSubtitle: () =>
        '眼下这坨赛博小纸条类型：${Pref.msgUnReadTypeV2.map((item) => item.title).join('、')}，属实绷不住',
  ),
  NormalModel(
    onTap: _showBarHideTypeDialog,
    title: '顶/底栏卷起来类型，功德+1',
    leading: const Icon(MdiIcons.arrowExpandVertical),
    getSubtitle: () => '眼下这坨：${Pref.barHideType.label}',
  ),
  SwitchModel(
    title: '首页顶栏卷起来',
    subtitle: '首页列表滑动时，卷起来顶栏',
    leading: const Icon(Icons.vertical_align_top_outlined),
    setKey: SettingBoxKey.hideTopBar,
    defaultVal: PlatformUtils.isMobile,
    needReboot: true,
  ),
  SwitchModel(
    title: '首页底栏卷起来',
    subtitle: '首页列表滑动时，卷起来底栏，我嘞个豆',
    leading: const Icon(Icons.vertical_align_bottom_outlined),
    setKey: SettingBoxKey.hideBottomBar,
    defaultVal: PlatformUtils.isMobile,
    needReboot: true,
  ),
  NormalModel(
    onTap: (context, setState) => _showQualityDialog(
      context: context,
      title: const Text('赛博小画片质量'),
      initValue: Pref.picQuality,
      onChanged: (picQuality) async {
        GlobalData().imgQuality = picQuality;
        await GStorage.setting.put(SettingBoxKey.defaultPicQa, picQuality);
        setState();
      },
    ),
    title: '赛博小画片质量',
    subtitle: '抓一个合适的赛博小画片眼睛分辨率，上限100%',
    leading: const Icon(Icons.image_outlined),
    getTrailing: (theme) => Text(
      '${Pref.picQuality}%',
      style: theme.textTheme.titleSmall,
    ),
  ),
  NormalModel(
    onTap: (context, setState) => _showQualityDialog(
      context: context,
      title: const Text('扒拉看看大图质量'),
      initValue: Pref.previewQ,
      onChanged: (picQuality) async {
        await GStorage.setting.put(SettingBoxKey.previewQuality, picQuality);
        setState();
      },
    ),
    title: '扒拉看看大图质量',
    subtitle: '抓一个合适的赛博小画片眼睛分辨率，上限100%',
    leading: const Icon(Icons.image_outlined),
    getTrailing: (theme) => Text(
      '${Pref.previewQ}%',
      style: theme.textTheme.titleSmall,
    ),
  ),
  NormalModel(
    onTap: _showReduceColorDialog,
    title: '深色下赛博小画片赛博染料叠加，不是哥们',
    subtitle: '亮出来赛博染料=赛博小画片原色x所选赛博染料，大图扒拉看看不受影响',
    leading: const Icon(Icons.format_color_fill_outlined),
    getTrailing: (theme) => Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: Pref.reduceLuxColor ?? Colors.white,
        shape: BoxShape.circle,
      ),
    ),
  ),
  NormalModel(
    leading: const Icon(Icons.opacity_outlined),
    title: '气泡提示不透明度，我嘞个豆',
    subtitle: '自定义气泡提示(Toast)不透明度，不是哥们',
    getTrailing: (theme) => Text(
      CustomToast.toastOpacity.toStringAsFixed(1),
      style: theme.textTheme.titleSmall,
    ),
    onTap: _showToastDialog,
  ),
  NormalModel(
    onTap: _showThemeTypeDialog,
    leading: const Icon(Icons.flashlight_on_outlined),
    title: '皮肤人格模式',
    getSubtitle: () => '眼下这坨模式：${Pref.themeType.desc}，CPU 都看沉默了',
  ),
  SwitchModel(
    leading: const Icon(Icons.invert_colors),
    title: '纯黑皮肤人格',
    setKey: SettingBoxKey.isPureBlackTheme,
    defaultVal: false,
    onChanged: (value) {
      if (ThemeUtils.isDarkMode || Pref.darkVideoPage) {
        Get.updateMyAppTheme();
      }
    },
  ),
  NormalModel(
    onTap: (context, setState) => Get.toNamed('/colorSetting'),
    leading: const Icon(Icons.color_lens_outlined),
    title: '这坨 App皮肤人格',
    getSubtitle: () => '眼下这坨皮肤人格：${Pref.themeColorMode.label}，不是哥们',
    getTrailing: _themeColorTrailing,
  ),
  NormalModel(
    leading: const Icon(Icons.home_outlined),
    title: '祖传默认启动页',
    getSubtitle: () => '眼下这坨启动页：${Pref.defaultHomePage.label}，我嘞个豆',
    onTap: _showDefHomeDialog,
  ),
  const SwitchModel(
    title: '我的页亮出来语录',
    subtitle: '啪一下封印后保留眼下这坨轮换位置，这把高端局',
    leading: Icon(Icons.format_quote),
    setKey: SettingBoxKey.showMineQuote,
    defaultVal: true,
  ),
  const NormalModel(
    title: '滑动纸片人运动会弹簧参数',
    leading: Icon(Icons.chrome_reader_mode_outlined),
    onTap: _showSpringDialog,
  ),
  NormalModel(
  title: '页面上下滚动惯性，属实绷不住',
  getSubtitle: () =>
      '惯性：${Pref.verticalScrollInertiaScale.toStringAsFixed(2)}×；，这把高端局'
      '减油门：${Pref.verticalScrollDecelerationScale.toStringAsFixed(2)}×，属实绷不住',
  leading: const Icon(Icons.swap_vert),
  onTap: _showVerticalScrollPhysicsDialog,
),
  NormalModel(
    onTap: (context, setState) async {
      final res = await Get.toNamed('/fontSizeSetting');
      if (res != null) {
        setState();
      }
    },
    title: '赛博字骨大小',
    leading: const Icon(Icons.format_size_outlined),
    getSubtitle: () {
      final scale = Pref.defaultTextScale;
      return scale == 1.0 ? '祖传默认' : scale.toString();
    },
  ),
  NormalModel(
    title: '赛博锐评区赛博锐评赛博字骨大小，优势在我',
    getSubtitle: () => '眼下这坨：${Pref.replyFontSize.toStringAsFixed(1)}dp',
    leading: const Icon(Icons.text_fields),
    onTap: _showReplyFontSizeDialog,
  ),
  NormalModel(
    title: '折叠对线回合字有多大比例',
    getSubtitle: () =>
        '相对主赛博锐评：${Pref.collapsedReplyFontScale.toStringAsFixed(2)}倍，鼠鼠我啊',
    leading: const Icon(Icons.compare_arrows),
    onTap: _showCollapsedReplyFontScaleDialog,
  ),
  NormalModel(
    title: '赛博锐评区赛博锐评行距',
    getSubtitle: () =>
        '眼下这坨：${Pref.replyLineSpacingScale.toStringAsFixed(2)}倍，启动！',
    leading: const Icon(Icons.format_line_spacing),
    onTap: _showReplyLineSpacingDialog,
  ),
  NormalModel(
    onTap: (context, setState) => Get.toNamed(
      '/barSetting',
      arguments: {
        'key': SettingBoxKey.tabBarSort,
        'defaultBars': HomeTabType.values,
        'title': '首页标签页，启动！',
      },
    ),
    title: '首页标签页，启动！',
    subtitle: '物理超度或调换首页标签页',
    leading: const Icon(Icons.toc_outlined),
  ),
  NormalModel(
    onTap: (context, setState) => Get.toNamed(
      '/barSetting',
      arguments: {
        'key': SettingBoxKey.navBarSort,
        'defaultBars': NavigationBarType.values,
        'title': 'Navbar',
      },
    ),
    title: 'Navbar重新盘，优势在我',
    subtitle: '物理超度或调换Navbar',
    leading: const Icon(Icons.toc_outlined),
  ),
  SwitchModel(
    title: '润回去时直接退出',
    subtitle: '启动后在主页任意tab按润回去键都直接退出，啪一下封印则先回到Navbar的第一个tab',
    leading: const Icon(Icons.exit_to_app_outlined),
    setKey: SettingBoxKey.directExitOnBack,
    defaultVal: false,
    onChanged: (value) => Get.find<MainController>().directExitOnBack = value,
  ),
  if (Platform.isAndroid)
    NormalModel(
      onTap: (context, setState) => Get.toNamed('/displayModeSetting'),
      title: '屏幕帧率，已老实',
      leading: const Icon(Icons.autofps_select_outlined),
    ),
];

void _showQualityDialog({
  required BuildContext context,
  required Widget title,
  required int initValue,
  required ValueChanged<int> onChanged,
}) {
  showDialog<double>(
    context: context,
    builder: (context) => SliderDialog(
      value: initValue.toDouble(),
      title: title,
      min: 10,
      max: 100,
      divisions: 9,
      suffix: '%',
      precise: 0,
    ),
  ).then((result) {
    if (result != null) {
      SmartDialog.showToast('调参焊死，包成的');
      onChanged(result.toInt());
    }
  });
}

void _showUiScaleDialog(
  BuildContext context,
  VoidCallback setState,
) {
  const minUiScale = 0.5;
  const maxUiScale = 2.0;

  double uiScale = Pref.uiScale;
  final textController = TextEditingController(
    text: uiScale.toStringAsFixed(2),
  );

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('界面缩放，曼波'),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      content: StatefulBuilder(
        onDispose: textController.dispose,
        builder: (context, setDialogState) => Column(
          spacing: 20,
          mainAxisSize: MainAxisSize.min,
          children: [
            Slider(
              padding: .zero,
              value: uiScale,
              min: minUiScale,
              max: maxUiScale,
              secondaryTrackValue: 1.0,
              divisions: ((maxUiScale - minUiScale) * 20).toInt(),
              label: textController.text,
              onChanged: (value) => setDialogState(() {
                uiScale = value.toPrecision(2);
                textController.text = uiScale.toStringAsFixed(2);
              }),
            ),
            TextFormField(
              controller: textController,
              keyboardType: const .numberWithOptions(decimal: true),
              inputFormatters: [
                LengthLimitingTextInputFormatter(4),
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]+')),
              ],
              decoration: const InputDecoration(
                labelText: '缩放比例，CPU 都看沉默了',
                hintText: '0.50 - 2.00',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                final parsed = double.tryParse(value);
                if (parsed != null &&
                    parsed >= minUiScale &&
                    parsed <= maxUiScale) {
                  setDialogState(() {
                    uiScale = parsed;
                  });
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            GStorage.setting.delete(SettingBoxKey.uiScale).whenComplete(() {
              setState();
              Get.appUpdate();
              ScaledWidgetsFlutterBinding.instance.scaleFactor = 1.0;
            });
          },
          child: const Text('恢复出厂人格'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            '不整了，撤！',
            style: TextStyle(color: ColorScheme.of(context).outline),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            GStorage.setting.put(SettingBoxKey.uiScale, uiScale).whenComplete(
              () {
                setState();
                Get.appUpdate();
                ScaledWidgetsFlutterBinding.instance.scaleFactor = uiScale;
              },
            );
          },
          child: const Text('包的，就这么整'),
        ),
      ],
    ),
  );
}

void _showSpringDialog(BuildContext context, _) {
  final List<String> springDescription = Pref.springDescription
      .map((i) => i.toString())
      .toList(growable: false);
  bool physicalMode = true;

  void physical2Duration() {
    final mass = double.parse(springDescription[0]);
    final stiffness = double.parse(springDescription[1]);
    final damping = double.parse(springDescription[2]);

    final duration = math.sqrt(4 * math.pi * math.pi * mass / stiffness);
    final dampingRatio = damping / (2.0 * math.sqrt(mass * stiffness));
    final bounce = dampingRatio < 1.0
        ? 1.0 - dampingRatio
        : 1.0 / dampingRatio - 1;

    springDescription[0] = duration.toString();
    springDescription[1] = bounce.toString();
  }

  /// from [SpringDescription.withDurationAndBounce] but with higher precision
  void duration2Physical() {
    final duration = double.parse(springDescription[0]);
    final bounce = double.parse(springDescription[1]).clamp(-1.0, 1.0);

    final stiffness = 4 * math.pi * math.pi / math.pow(duration, 2);
    final dampingRatio = bounce > 0 ? 1.0 - bounce : 1.0 / (bounce + 1);
    final damping = 2 * math.sqrt(stiffness) * dampingRatio;

    springDescription[0] = '1';
    springDescription[1] = stiffness.toString();
    springDescription[2] = damping.toString();
  }

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        mainAxisAlignment: .spaceBetween,
        children: [
          const Text('弹簧参数，CPU 都看沉默了'),
          TextButton(
            style: TextButton.styleFrom(
              visualDensity: .compact,
              tapTargetSize: .shrinkWrap,
            ),
            onPressed: () {
              try {
                if (physicalMode) {
                  physical2Duration();
                } else {
                  duration2Physical();
                }
                physicalMode = !physicalMode;
                (context as Element).markNeedsBuild();
              } catch (e) {
                SmartDialog.showToast(e.toString());
              }
            },
            child: Text(physicalMode ? '滑动时间，优势在我' : '物理参数，包的'),
          ),
        ],
      ),
      content: Column(
        key: ValueKey(physicalMode),
        mainAxisSize: .min,
        children: List.generate(
          physicalMode ? 3 : 2,
          (index) => TextFormField(
            autofocus: index == 0,
            initialValue: springDescription[index],
            keyboardType: .numberWithOptions(
              signed: !physicalMode && index == 1,
              decimal: true,
            ),
            onChanged: (value) => springDescription[index] = value,
            inputFormatters: [
              !physicalMode && index == 1
                  ? FilteringTextInputFormatter.allow(RegExp(r'[-\d\.]+'))
                  : FilteringTextInputFormatter.allow(RegExp(r'[\d\.]+')),
            ],
            decoration: InputDecoration(
              labelText: (physicalMode
                  ? const ['mass', 'stiffness', 'damping']
                  : const ['duration', 'bounce'])[index],
              suffixText: !physicalMode && index == 0 ? 's' : null,
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Get.back();
            GStorage.setting.delete(SettingBoxKey.springDescription);
            SmartDialog.showToast('复活出厂人格成了，包的，重开一把生效');
          },
          child: const Text('恢复出厂人格'),
        ),
        TextButton(
          onPressed: Get.back,
          child: Text(
            '不整了，撤！',
            style: TextStyle(color: ColorScheme.of(context).outline),
          ),
        ),
        TextButton(
          onPressed: () {
            try {
              if (!physicalMode) {
                duration2Physical();
              }
              final res = springDescription.map(double.parse).toList();
              Get.back();
              GStorage.setting.put(SettingBoxKey.springDescription, res);
              SmartDialog.showToast('赛博调参成了，包的，重开一把生效');
            } catch (e) {
              SmartDialog.showToast(e.toString());
            }
          },
          child: const Text('包的，就这么整'),
        ),
      ],
    ),
  );
}

Future<void> _showVerticalScrollPhysicsDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<(double, double)>(
    context: context,
    builder: (context) => DualSliderDialog(
  title: const Text('页面上下滚动惯性，属实绷不住'),
  value1: Pref.verticalScrollInertiaScale,
  value2: Pref.verticalScrollDecelerationScale,
  description1: const Text(
    '惯性距离倍率（通过缩放松手油门实现，越大通常滑得越远），包的',
  ),
  description2: const Text(
    '减油门倍率（越大油门衰减越快，越早熄火）',
  ),
  min: 0.5,
  max: 2.0,
  divisions: 30,
  min2: 0.05,
  divisions2: 39,
  suffix: '×',
  precise: 2,
),
  );

  if (res != null) {
    await GStorage.setting.putAll({
      SettingBoxKey.verticalScrollInertiaScale: res.$1,
      SettingBoxKey.verticalScrollDecelerationScale: res.$2,
    });
    setState();
    Get.appUpdate();
  }
}

Future<void> _showFontWeightDialog(BuildContext context) async {
  final res = await showDialog<double>(
    context: context,
    builder: (context) => SliderDialog(
      title: const Text('App赛博字骨字重，这把高端局'),
      value: Pref.appFontWeight.toDouble() + 1,
      min: 1,
      max: FontWeight.values.length.toDouble(),
      divisions: FontWeight.values.length - 1,
    ),
  );
  if (res != null) {
    await GStorage.setting.put(SettingBoxKey.appFontWeight, res.toInt() - 1);
    Get.updateMyAppTheme();
  }
}

Future<void> _showReplyFontSizeDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<double>(
    context: context,
    builder: (context) => SliderDialog(
      title: const Text('赛博锐评区赛博锐评赛博字骨大小，优势在我'),
      value: Pref.replyFontSize,
      min: 10,
      max: 22,
      divisions: 24,
      suffix: 'dp',
      precise: 1,
    ),
  );
  if (res != null) {
    await GStorage.setting.put(SettingBoxKey.replyFontSize, res);
    Get.appUpdate();
    setState();
  }
}

Future<void> _showCollapsedReplyFontScaleDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<double>(
    context: context,
    builder: (context) => SliderDialog(
      title: const Text('折叠对线回合字有多大比例'),
      value: Pref.collapsedReplyFontScale,
      min: 0.7,
      max: 1.3,
      divisions: 12,
      suffix: '倍，鼠鼠我啊',
      precise: 2,
    ),
  );
  if (res != null) {
    await GStorage.setting.put(SettingBoxKey.collapsedReplyFontScale, res);
    Get.appUpdate();
    setState();
  }
}

Future<void> _showReplyLineSpacingDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<double>(
    context: context,
    builder: (context) => SliderDialog(
      title: const Text('赛博锐评区赛博锐评行距'),
      value: Pref.replyLineSpacingScale,
      min: 0.7,
      max: 1.5,
      divisions: 16,
      suffix: '倍，鼠鼠我啊',
      precise: 2,
    ),
  );
  if (res != null) {
    await GStorage.setting.put(SettingBoxKey.replyLineSpacingScale, res);
    Get.appUpdate();
    setState();
  }
}

Future<void> _showTransitionDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<Transition>(
    context: context,
    builder: (context) => SelectDialog<Transition>(
      title: '页面过渡纸片人运动会，我嘞个豆',
      value: Pref.pageTransition,
      values: Transition.values.map((e) => (e, e.name)).toList(),
    ),
  );
  if (res != null) {
    Get.rootController.defaultTransition = res;
    await GStorage.setting.put(SettingBoxKey.pageTransition, res.index);
    setState();
  }
}

Future<void> _showCardWidthDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<(double, double)>(
    context: context,
    builder: (context) => DualSliderDialog(
      title: const Text('列表最大列横向体宽（祖传默认240dp）'),
      value1: Pref.recommendCardWidth,
      value2: Pref.smallCardWidth,
      description1: const Text('主页算法喂饭流'),
      description2: const Text('剩下那坨'),
      min: 150.0,
      max: 500.0,
      divisions: 35,
      suffix: 'dp',
    ),
  );
  if (res != null) {
    await GStorage.setting.putAll({
      SettingBoxKey.recommendCardWidth: res.$1,
      SettingBoxKey.smallCardWidth: res.$2,
    });
    SmartDialog.showToast('重开一把才算数');
    setState();
  }
}

Future<void> _showHomeTabBarHeightDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<double>(
    context: context,
    builder: (context) => SliderDialog(
      title: const Text('首页顶部分类栏竖向身高'),
      value: Pref.homeTabBarHeight,
      min: 28,
      max: 72,
      divisions: 22,
      suffix: 'dp',
      precise: 0,
    ),
  );
  if (res != null) {
    await GStorage.setting.put(SettingBoxKey.homeTabBarHeight, res);
    Get.appUpdate();
    setState();
  }
}

Future<void> _showLegacyBottomBarBottomPaddingDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final systemPadding = MediaQuery.viewPaddingOf(context).bottom
      .clamp(0.0, 48.0)
      .toDouble();
  double value = Pref.legacyBottomBarBottomPadding ?? systemPadding;
  final res = await showDialog<double>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('首页传统底栏底部留白，曼波'),
        contentPadding: const .only(top: 20, left: 8, right: 8, bottom: 8),
        content: SizedBox(
          height: 40,
          child: Slider(
            value: value,
            min: 0,
            max: 48,
            divisions: 48,
            label: '${value.toStringAsFixed(0)}dp',
            onChanged: (newValue) =>
                setDialogState(() => value = newValue),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, -1.0),
            child: const Text('跟随系统大爹'),
          ),
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: Text(
              '不整了，撤！',
              style: TextStyle(color: ColorScheme.of(context).outline),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, value),
            child: const Text('包的，就这么整'),
          ),
        ],
      ),
    ),
  );
  if (res != null) {
    if (res < 0) {
      await GStorage.setting.delete(
        SettingBoxKey.legacyBottomBarBottomPadding,
      );
    } else {
      await GStorage.setting.put(
        SettingBoxKey.legacyBottomBarBottomPadding,
        res,
      );
    }
    Get.appUpdate();
    setState();
  }
}

Future<void> _showCardRadiusDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<double>(
    context: context,
    builder: (context) => SliderDialog(
      title: const Text('卡片边角磨圆半径（祖传默认10dp）'),
      value: Pref.cardRadius,
      min: 0,
      max: 32,
      divisions: 32,
      suffix: 'dp',
      precise: 0,
    ),
  );
  if (res != null) {
    await GStorage.setting.put(SettingBoxKey.cardRadius, res);
    Get.updateMyAppTheme();
    setState();
  }
}

Future<void> _showRecommendStatSpacingDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<double>(
    context: context,
    builder: (context) => SliderDialog(
      title: const Text('开炫量与满屏飘字数间距'),
      value: Pref.recommendStatSpacing,
      min: 0,
      max: 24,
      divisions: 24,
      suffix: 'dp',
      precise: 0,
    ),
  );
  if (res != null) {
    await GStorage.setting.put(SettingBoxKey.recommendStatSpacing, res);
    setState();
    Get.appUpdate();
  }
}

Future<void> _showUpPosDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<UpPanelPosition>(
    context: context,
    builder: (context) => SelectDialog<UpPanelPosition>(
      title: '互联网近况页UP主亮出来位置',
      value: Pref.upPanelPosition,
      values: UpPanelPosition.values.map((e) => (e, e.label)).toList(),
    ),
  );
  if (res != null) {
    await GStorage.setting.put(SettingBoxKey.upPanelPosition, res.index);
    SmartDialog.showToast('重开一把才算数');
    setState();
  }
}

Future<void> _showDynBadgeDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<DynamicBadgeMode>(
    context: context,
    builder: (context) => SelectDialog<DynamicBadgeMode>(
      title: '互联网近况未读标记，功德+1',
      value: Pref.dynamicBadgeType,
      values: DynamicBadgeMode.values.map((e) => (e, e.desc)).toList(),
    ),
  );
  if (res != null) {
    final mainController = Get.find<MainController>()
      ..dynamicBadgeMode = DynamicBadgeMode.values[res.index];
    if (mainController.dynamicBadgeMode != DynamicBadgeMode.hidden) {
      mainController.getUnreadDynamic();
    }
    await GStorage.setting.put(
      SettingBoxKey.dynamicBadgeMode,
      res.index,
    );
    SmartDialog.showToast('调参焊死，包成的');
    setState();
  }
}

Future<void> _showMsgBadgeDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<DynamicBadgeMode>(
    context: context,
    builder: (context) => SelectDialog<DynamicBadgeMode>(
      title: '赛博小纸条未读标记',
      value: Pref.msgBadgeMode,
      values: DynamicBadgeMode.values.map((e) => (e, e.desc)).toList(),
    ),
  );
  if (res != null) {
    final mainController = Get.find<MainController>()
      ..msgBadgeMode = DynamicBadgeMode.values[res.index];
    if (mainController.msgBadgeMode != DynamicBadgeMode.hidden) {
      mainController.queryUnreadMsg(true);
    } else {
      mainController.msgUnReadCount.value = '';
    }
    await GStorage.setting.put(SettingBoxKey.msgBadgeMode, res.index);
    SmartDialog.showToast('调参焊死，包成的');
    setState();
  }
}

Future<void> _showMsgUnReadDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<Set<MsgUnReadType>>(
    context: context,
    builder: (context) => MultiSelectDialog<MsgUnReadType>(
      title: '赛博小纸条未读类型，启动！',
      initValues: Pref.msgUnReadTypeV2,
      values: {for (final i in MsgUnReadType.values) i: i.title},
    ),
  );
  if (res != null) {
    final mainController = Get.find<MainController>()..msgUnReadTypes = res;
    if (mainController.msgBadgeMode != DynamicBadgeMode.hidden) {
      mainController.queryUnreadMsg();
    }
    await GStorage.setting.put(
      SettingBoxKey.msgUnReadTypeV2,
      res.map((item) => item.index).toList()..sort(),
    );
    SmartDialog.showToast('调参焊死，包成的');
    setState();
  }
}

void _showReduceColorDialog(
  BuildContext context,
  VoidCallback setState,
) {
  final reduceLuxColor = Pref.reduceLuxColor;
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      clipBehavior: Clip.hardEdge,
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      title: const Text('Color Picker'),
      content: SlideColorPicker(
        color: reduceLuxColor ?? Colors.white,
        onChanged: (Color? color) {
          if (color != null && color != reduceLuxColor) {
            if (color == Colors.white) {
              NetworkImgLayer.reduceLuxColor = null;
              GStorage.setting.delete(SettingBoxKey.reduceLuxColor);
              SmartDialog.showToast('调参焊死，包成的');
              setState();
            } else {
              void onConfirm() {
                NetworkImgLayer.reduceLuxColor = color;
                GStorage.setting.put(
                  SettingBoxKey.reduceLuxColor,
                  color.toARGB32(),
                );
                SmartDialog.showToast('调参焊死，包成的');
                setState();
              }

              if (color.computeLuminance() < 0.2) {
                showConfirmDialog(
                  context: context,
                  title: Text(
                    '拍板使用#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).toUpperCase().padLeft(6)}？',
                  ),
                  content: const Text('所选赛博染料过于昏暗，可能会影响赛博小画片观看，曼波'),
                  onConfirm: onConfirm,
                );
              } else {
                onConfirm();
              }
            }
          }
        },
      ),
    ),
  );
}

Future<void> _showToastDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<double>(
    context: context,
    builder: (context) => SliderDialog(
      title: const Text('Toast不透明度，曼波'),
      value: CustomToast.toastOpacity,
      min: 0.0,
      max: 1.0,
      divisions: 10,
    ),
  );
  if (res != null) {
    CustomToast.toastOpacity = res;
    await GStorage.setting.put(SettingBoxKey.defaultToastOp, res);
    SmartDialog.showToast('调参焊死，包成的');
    setState();
  }
}

Future<void> _showThemeTypeDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<ThemeType>(
    context: context,
    builder: (context) => SelectDialog<ThemeType>(
      title: '皮肤人格模式',
      value: Pref.themeType,
      values: ThemeType.values.map((e) => (e, e.desc)).toList(),
    ),
  );
  if (res != null) {
    try {
      Get.find<MineController>().themeType.value = res;
    } catch (_) {}
    GStorage.setting.put(SettingBoxKey.themeMode, res.index);
    Get.changeThemeMode(ThemeUtils.themeMode = res.toThemeMode);
    setState();
  }
}

Widget _themeColorTrailing(ThemeData theme) {
  if (Pref.themeColorMode == ThemeColorMode.dynamic) {
    return Icon(Icons.color_lens_rounded, color: theme.colorScheme.primary);
  }
  final colorScheme = switch (Pref.themeColorMode) {
    ThemeColorMode.customMultiSeed => Pref.customThemeSeeds
        .asColorSchemeSeeds(
          Pref.schemeVariant,
          theme.brightness,
        )
        .applyToneOffsets(Pref.customThemeToneOffsets(theme.brightness)),
    _ => colorThemeTypes[Pref.customColor].color.asColorSchemeSeed(
      Pref.schemeVariant,
      theme.brightness,
    ),
  };
  return SizedBox.square(
    dimension: 20,
    child: ColorPalette(
      colorScheme: colorScheme,
      selected: false,
      showBgColor: false,
    ),
  );
}

Future<void> _showDefHomeDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<NavigationBarType>(
    context: context,
    builder: (context) => SelectDialog<NavigationBarType>(
      title: '首页启动页，属实绷不住',
      value: Pref.defaultHomePage,
      values: NavigationBarType.values.map((e) => (e, e.label)).toList(),
    ),
  );
  if (res != null) {
    await GStorage.setting.put(SettingBoxKey.defaultHomePage, res.index);
    SmartDialog.showToast('赛博调参成了，包的，重开一把生效');
    setState();
  }
}

Future<void> _showBarHideTypeDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<BarHideType>(
    context: context,
    builder: (context) => SelectDialog<BarHideType>(
      title: '顶/底栏卷起来类型，功德+1',
      value: Pref.barHideType,
      values: BarHideType.values.map((e) => (e, e.label)).toList(),
    ),
  );
  if (res != null) {
    await GStorage.setting.put(SettingBoxKey.barHideType, res.index);
    SmartDialog.showToast('重开一把才算数');
    setState();
  }
}

NormalModel _useSSDModel() {
  final file = File(path.join(appSupportDirPath, 'use_ssd'));
  void onChanged(BuildContext context, VoidCallback setState) {
    (file.existsSync() ? file.tryDel() : file.create()).whenComplete(() {
      if (context.mounted) {
        setState();
      }
    });
  }

  return NormalModel(
    title: '使用SSD（Server-Side Decoration），我嘞个豆',
    leading: const Icon(Icons.web_asset),
    onTap: onChanged,
    getTrailing: (theme) => Builder(
      builder: (context) => Transform.scale(
        scale: 0.8,
        alignment: .centerRight,
        child: Switch(
          value: file.existsSync(),
          onChanged: (_) =>
              onChanged(context, (context as Element).markNeedsBuild),
        ),
      ),
    ),
  );
}
