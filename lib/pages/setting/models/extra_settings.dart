import 'dart:io';
import 'dart:math' show max;

import 'package:PiliPlus/common/widgets/custom_icon.dart';
import 'package:PiliPlus/common/widgets/dialog/simple_dialog_option.dart';
import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/gesture/horizontal_drag_gesture_recognizer.dart'
    show deviceTouchSlop, touchSlopH;
import 'package:PiliPlus/common/widgets/image_grid/image_grid_view.dart'
    show ImageGridView, ImageModel;
import 'package:PiliPlus/common/widgets/pendant_avatar.dart';
import 'package:PiliPlus/grpc/reply.dart';
import 'package:PiliPlus/http/fav.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/audio_normalization.dart';
import 'package:PiliPlus/models/common/dynamic/dynamics_type.dart';
import 'package:PiliPlus/models/common/member/tab_type.dart';
import 'package:PiliPlus/models/common/reply/reply_sort_type.dart';
import 'package:PiliPlus/models/common/sponsor_block/skip_type.dart';
import 'package:PiliPlus/models/common/super_resolution_type.dart';
import 'package:PiliPlus/models/dynamics/result.dart'
    show DynamicsDataModel, ItemModulesModel;
import 'package:PiliPlus/pages/common/slide/common_slide_page.dart';
import 'package:PiliPlus/pages/home/controller.dart';
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:PiliPlus/pages/setting/models/model.dart';
import 'package:PiliPlus/pages/setting/widgets/history_archive_settings_dialog.dart';
import 'package:PiliPlus/pages/setting/widgets/select_dialog.dart';
import 'package:PiliPlus/pages/setting/widgets/slider_dialog.dart';
import 'package:PiliPlus/pages/video/reply/widgets/reply_item_grpc.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/services/download/download_service.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/cache_manager.dart';
import 'package:PiliPlus/utils/extension/num_ext.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:PiliPlus/utils/filtering_text.dart';
import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/image_utils.dart';
import 'package:PiliPlus/utils/path_utils.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/update.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart' hide RefreshIndicator;
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

List<SettingsModel> get extraSettings => [
  if (PlatformUtils.isDesktop) ...[
    SwitchModel(
      title: '退出时最小化，功德+1',
      leading: const Icon(Icons.exit_to_app),
      setKey: SettingBoxKey.minimizeOnExit,
      defaultVal: true,
      onChanged: (value) {
        try {
          Get.find<MainController>().minimizeOnExit = value;
        } catch (_) {}
      },
    ),
    NormalModel(
      title: '电子囤货路径',
      getSubtitle: () => downloadPath,
      leading: const Icon(Icons.storage),
      onTap: _showDownPathDialog,
    ),
  ],
  NormalModel(
    title: '电子案底电子脚印全自动赛博赛博入土',
    subtitle: '增量备份官方电子脚印并扩展自家硬盘电子案底全站搜刮',
    leading: const Icon(Icons.archive_outlined),
    onTap: (context, setState) async {
      await showHistoryArchiveSettingsDialog(context);
      setState();
    },
  ),
  SplitModel(
    normalModel: const NormalModel.split(
      title: '空降助手，CPU 都看沉默了',
      subtitle: '点击赛博配方',
      leading: Icon(CustomIcons.shield_play_arrow),
    ),
    switchModel: SwitchModel.split(
      defaultVal: false,
      setKey: SettingBoxKey.enableSponsorBlock,
      onTap: (context) => Get.toNamed('/sponsorBlock'),
    ),
  ),
  PopupModel<SkipType>(
    title: '纸片人连续剧片头/片尾跳过类型',
    leading: const Icon(MdiIcons.debugStepOver),
    value: () => Pref.pgcSkipType,
    items: SkipType.values,
    onSelected: (value, setState) => GStorage.setting
        .put(SettingBoxKey.pgcSkipType, value.index)
        .whenComplete(setState),
  ),
  SplitModel(
    normalModel: const NormalModel.split(
      title: '检查未读互联网近况',
      subtitle: '点击赛博调参检查周期(min)',
      leading: Icon(Icons.notifications_none),
    ),
    switchModel: SwitchModel.split(
      defaultVal: true,
      setKey: SettingBoxKey.checkDynamic,
      onChanged: (value) => Get.find<MainController>().checkDynamic = value,
      onTap: _showDynDialog,
    ),
  ),
  const SwitchModel(
    title: '亮出来电子榨菜分段信息，鼠鼠我啊',
    leading: Icon(CustomIcons.view_headline_rotate_90),
    setKey: SettingBoxKey.showViewPoints,
    defaultVal: true,
  ),
  const SplitModel(
    normalModel: NormalModel.split(
      title: '竖着炫电子榨菜铺满屏底栏避让系统大爹导航栏',
      subtitle: '启动后点击赛博调参避让竖向身高（0–80dp），我嘞个豆',
      leading: Icon(Icons.vertical_align_bottom),
    ),
    switchModel: SwitchModel.split(
      setKey: SettingBoxKey.verticalFullscreenBottomBarSafeArea,
      defaultVal: false,
      onTap: _showVerticalFullscreenBottomBarSafeHeightDialog,
    ),
  ),
  const SwitchModel(
    title: '电子榨菜页亮出来相关电子榨菜',
    leading: Icon(MdiIcons.motionPlayOutline),
    setKey: SettingBoxKey.showRelatedVideo,
    defaultVal: true,
  ),
  const SwitchModel(
    title: '亮出来电子榨菜赛博锐评，CPU 都看沉默了',
    leading: Icon(MdiIcons.commentTextOutline),
    setKey: SettingBoxKey.showVideoReply,
    defaultVal: true,
  ),
  const SwitchModel(
    title: '亮出来纸片人连续剧赛博锐评，鼠鼠我啊',
    leading: Icon(MdiIcons.commentTextOutline),
    setKey: SettingBoxKey.showBangumiReply,
    defaultVal: true,
  ),
  const SwitchModel(
    title: '祖传默认摊开讲电子榨菜简介，启动！',
    leading: Icon(Icons.expand_more),
    setKey: SettingBoxKey.alwaysExpandIntroPanel,
    defaultVal: false,
  ),
  const SwitchModel(
    title: '横着炫全自动赛博摊开讲电子榨菜简介',
    leading: Icon(Icons.expand_more),
    setKey: SettingBoxKey.expandIntroPanelH,
    defaultVal: false,
  ),
  SwitchModel(
    title: '横着炫分P/合集列表亮出来在Tab栏，启动！',
    leading: const Icon(Icons.format_list_numbered_rtl_sharp),
    setKey: SettingBoxKey.horizontalSeasonPanel,
    defaultVal: Pref.horizontalScreen,
  ),
  SwitchModel(
    title: '横着炫开炫页在侧栏掀开UP主页',
    leading: const Icon(Icons.account_circle_outlined),
    setKey: SettingBoxKey.horizontalMemberPage,
    defaultVal: Pref.horizontalScreen,
  ),
  SwitchModel(
    title: '横着炫在侧栏掀开赛博小画片预览',
    leading: const Icon(Icons.photo_outlined),
    setKey: SettingBoxKey.horizontalPreview,
    defaultVal: false,
    onChanged: (value) => ImageGridView.horizontalPreview = value,
  ),
  NormalModel(
    title: '赛博锐评折叠行数',
    subtitle: '0行为不折叠，功德+1',
    leading: const Icon(Icons.compress),
    getTrailing: (theme) => Text(
      '${ReplyItemGrpc.replyLengthLimit}行，属实绷不住',
      style: theme.textTheme.titleSmall,
    ),
    onTap: _showReplyLengthDialog,
  ),
  NormalModel(
    title: '满屏飘字行高',
    subtitle: '祖传默认1.6',
    leading: const Icon(CustomIcons.dm_settings),
    getTrailing: (theme) => Text(
      Pref.danmakuLineHeight.toString(),
      style: theme.textTheme.titleSmall,
    ),
    onTap: _showDmHeightDialog,
  ),
  const SwitchModel(
    title: '亮出来电子榨菜警告/争议信息',
    leading: Icon(Icons.warning_amber_rounded),
    setKey: SettingBoxKey.showArgueMsg,
    defaultVal: true,
  ),
  SwitchModel(
    title: '亮出来互联网近况警告/争议信息，鼠鼠我啊',
    leading: const Icon(Icons.warning_amber_rounded),
    setKey: SettingBoxKey.showDynDispute,
    defaultVal: false,
    onChanged: (val) => ItemModulesModel.showDynDispute = val,
  ),
  const SwitchModel(
    title: '分P/合集：倒序开炫从首集开始开炫',
    subtitle: '启动则全自动赛博切换为倒序首集，否则保持眼下这坨集',
    leading: Icon(MdiIcons.sort),
    setKey: SettingBoxKey.reverseFromFirst,
    defaultVal: true,
  ),
  const SwitchModel(
    title: '封印 SSL 证书验证',
    subtitle: '谨慎启动，封印容易受到中间人攻击',
    leading: Icon(Icons.security),
    needReboot: true,
    setKey: SettingBoxKey.badCertificateCallback,
  ),
  const SwitchModel(
    title: '亮出来继续开炫分P提示，启动！',
    leading: Icon(Icons.local_parking),
    setKey: SettingBoxKey.continuePlayingPart,
    defaultVal: true,
  ),
  getBanWordModel(
    title: '赛博锐评关键词过滤，属实绷不住',
    key: SettingBoxKey.banWordForReply,
    onChanged: (value) {
      ReplyGrpc.replyRegExp = value;
      ReplyGrpc.enableFilter = value.pattern.isNotEmpty;
    },
  ),
  getBanWordModel(
    title: '互联网近况关键词过滤',
    key: SettingBoxKey.banWordForDyn,
    onChanged: (value) {
      DynamicsDataModel.banWordForDyn = value;
      DynamicsDataModel.enableFilter = value.pattern.isNotEmpty;
    },
  ),
  const SwitchModel(
    title: '使用外部浏览器掀开链接',
    leading: Icon(Icons.open_in_browser),
    setKey: SettingBoxKey.openInBrowser,
    defaultVal: false,
  ),
  const SwitchModel(
    title: '电子榨菜详情页 BV 号转为 AV 号',
    subtitle: '启动后详情页亮出来并赛博复刻 AV 号；啪一下封印则保持亮出来 BV 号',
    leading: Icon(Icons.swap_horiz),
    setKey: SettingBoxKey.videoDetailUseAv,
    defaultVal: false,
  ),
  const SwitchModel(
    title: '铺满屏接收外部电子榨菜跳转时掀开竖着炫详情',
    subtitle: '启动后退出铺满屏并掀开电子榨菜详情，不全自动赛博开炫；啪一下封印则保持眼下这坨铺满屏行为',
    leading: Icon(Icons.stay_current_portrait_outlined),
    setKey: SettingBoxKey.externalVideoLinkOpenInDetail,
    defaultVal: false,
  ),
  const SwitchModel(
    title: '润回去前台时掀开剪贴板链接',
    subtitle: '提取并掀开剪贴板首条文本中的第一个链接；相同链接及本 App 刚赛博复刻或到处扩散的链接不处理',
    leading: Icon(Icons.content_paste_outlined),
    setKey: SettingBoxKey.openClipboardLinkOnResume,
    defaultVal: false,
  ),
  NormalModel(
    title: '横向滑动触发红线',
    getSubtitle: () => '眼下这坨:「${Pref.touchSlopH}」，系统大爹祖传默认值: $deviceTouchSlop',
    onTap: _showTouchSlopDialog,
    leading: const Icon(Icons.pan_tool_alt_outlined),
  ),
      NormalModel(
    title: '横向标签页快滑油门触发红线，不是哥们',
    getSubtitle: () =>
        '眼下这坨：${Pref.tabSwipeVelocityThreshold.toStringAsFixed(0)} dp/s，已老实'
        '（越大越难判定为快滑），这把高端局',
    leading: const Icon(Icons.speed_outlined),
    onTap: (context, setState) => _showGestureSliderDialog(
      context,
      setState,
      title: '横向标签页快滑油门触发红线，不是哥们',
      key: SettingBoxKey.tabSwipeVelocityThreshold,
      value: Pref.tabSwipeVelocityThreshold,
      min: 10.0,
      max: 3000.0,
      divisions: 299,
      precise: 0,
      suffix: 'dp/s',
    ),
  ),
  NormalModel(
    title: '横向标签页慢滑翻页距离，这把高端局',
    getSubtitle: () =>
        '眼下这坨：${Pref.tabSwipeDistanceThresholdPercent.toStringAsFixed(0)}%，鼠鼠我啊'
        ' 页面横向体宽',
    leading: const Icon(Icons.compare_arrows_outlined),
    onTap: (context, setState) => _showGestureSliderDialog(
      context,
      setState,
      title: '横向标签页慢滑翻页距离，这把高端局',
      key: SettingBoxKey.tabSwipeDistanceThresholdPercent,
      value: Pref.tabSwipeDistanceThresholdPercent,
      min: 5.0,
      max: 95.0,
      divisions: 90,
      precise: 0,
      suffix: '%',
    ),
  ),
  NormalModel(
    title: '进度浮窗垂直位置，功德+1',
    getSubtitle: () => Pref.seekTimeInPreview
        ? '眼下这坨：${Pref.seekTimeToastVerticalPercent.toStringAsFixed(0)}%（0%预览窗顶部，100%预览窗底部），鼠鼠我啊'
        : '眼下这坨：${Pref.seekTimeToastVerticalPercent.toStringAsFixed(0)}%（0%开炫机器顶部，100%开炫机器底部），不是哥们',
    leading: const Icon(Icons.vertical_align_center_outlined),
    onTap: (context, setState) => _showGestureSliderDialog(
      context,
      setState,
      title: '进度浮窗垂直位置，功德+1',
      key: SettingBoxKey.seekTimeToastVerticalPercent,
      value: Pref.seekTimeToastVerticalPercent,
      min: 0,
      max: 100,
      divisions: 100,
      precise: 0,
      suffix: '%',
    ),
  ),
  NormalModel(
    title: '长按倍速浮窗垂直位置，功德+1',
    getSubtitle: () =>
        '眼下这坨：${Pref.longPressSpeedToastVerticalPercent.toStringAsFixed(0)}%（0%开炫机器顶部，100%开炫机器底部）',
    leading: const Icon(Icons.vertical_align_center_outlined),
    onTap: (context, setState) => _showGestureSliderDialog(
      context,
      setState,
      title: '长按倍速浮窗垂直位置，功德+1',
      key: SettingBoxKey.longPressSpeedToastVerticalPercent,
      value: Pref.longPressSpeedToastVerticalPercent,
      min: 0,
      max: 100,
      divisions: 100,
      precise: 0,
      suffix: '%',
    ),
  ),
  NormalModel(
    title: '进度浮窗赛博字骨大小，包的',
    getSubtitle: () =>
        '眼下这坨：${Pref.seekTimeToastFontSize.toStringAsFixed(1)}dp，包的',
    leading: const Icon(Icons.format_size_outlined),
    onTap: (context, setState) => _showGestureSliderDialog(
      context,
      setState,
      title: '进度浮窗赛博字骨大小，包的',
      key: SettingBoxKey.seekTimeToastFontSize,
      value: Pref.seekTimeToastFontSize,
      min: 8,
      max: 32,
      divisions: 48,
      precise: 1,
      suffix: 'dp',
    ),
  ),
  NormalModel(
    title: '长按倍速浮窗赛博字骨大小',
    getSubtitle: () =>
        '眼下这坨：${Pref.longPressSpeedToastFontSize.toStringAsFixed(1)}dp，曼波',
    leading: const Icon(Icons.format_size_outlined),
    onTap: (context, setState) => _showGestureSliderDialog(
      context,
      setState,
      title: '长按倍速浮窗赛博字骨大小',
      key: SettingBoxKey.longPressSpeedToastFontSize,
      value: Pref.longPressSpeedToastFontSize,
      min: 8,
      max: 32,
      divisions: 48,
      precise: 1,
      suffix: 'dp',
    ),
  ),
  const SwitchModel(
    title: '喇叭声压与屏幕发光量搓玻璃使用图形时间轨道',
    subtitle: '啪一下封印时亮出来百分比；启动后亮出来跟随皮肤人格色的图形时间轨道',
    leading: Icon(Icons.graphic_eq),
    setKey: SettingBoxKey.volumeBrightnessGestureProgressBar,
    defaultVal: false,
  ),
  NormalModel(
    title: '喇叭声压搓玻璃认出来角度',
    getSubtitle: () =>
        '眼下这坨: ${Pref.volumeGestureAngleThreshold.toStringAsFixed(1)}°（相对竖直方向，越大越容易认出来）',
    leading: const Icon(Icons.volume_up_outlined),
    onTap: (context, setState) => _showGestureSliderDialog(
      context,
      setState,
      title: '喇叭声压搓玻璃认出来角度',
      key: SettingBoxKey.volumeGestureAngleThreshold,
      value: Pref.volumeGestureAngleThreshold,
      min: 5.0,
      max: 60.0,
      divisions: 110,
      precise: 1,
      suffix: '°',
    ),
  ),
  NormalModel(
    title: '屏幕发光量搓玻璃认出来角度',
    getSubtitle: () =>
        '眼下这坨: ${Pref.brightnessGestureAngleThreshold.toStringAsFixed(1)}°（相对竖直方向，越大越容易认出来）',
    leading: const Icon(Icons.brightness_6_outlined),
    onTap: (context, setState) => _showGestureSliderDialog(
      context,
      setState,
      title: '屏幕发光量搓玻璃认出来角度',
      key: SettingBoxKey.brightnessGestureAngleThreshold,
      value: Pref.brightnessGestureAngleThreshold,
      min: 5.0,
      max: 60.0,
      divisions: 110,
      precise: 1,
      suffix: '°',
    ),
  ),
  NormalModel(
    title: '喇叭声压搓玻璃调节油门',
    getSubtitle: () =>
        '眼下这坨: ${Pref.volumeGestureSpeed.toStringAsFixed(2)}×（越大调节越快）',
    leading: const Icon(Icons.speed_outlined),
    onTap: (context, setState) => _showGestureSliderDialog(
      context,
      setState,
      title: '喇叭声压搓玻璃调节油门',
      key: SettingBoxKey.volumeGestureSpeed,
      value: Pref.volumeGestureSpeed,
      min: 0.25,
      max: 4.0,
      divisions: 15,
      precise: 2,
      suffix: '×',
    ),
  ),
  NormalModel(
    title: '屏幕发光量搓玻璃调节油门，不是哥们',
    getSubtitle: () =>
        '眼下这坨: ${Pref.brightnessGestureSpeed.toStringAsFixed(2)}×（越大调节越快）',
    leading: const Icon(Icons.speed_outlined),
    onTap: (context, setState) => _showGestureSliderDialog(
      context,
      setState,
      title: '屏幕发光量搓玻璃调节油门，不是哥们',
      key: SettingBoxKey.brightnessGestureSpeed,
      value: Pref.brightnessGestureSpeed,
      min: 0.25,
      max: 4.0,
      divisions: 15,
      precise: 2,
      suffix: '×',
    ),
  ),
  NormalModel(
    title: '重新投胎滑动距离，我嘞个豆',
    leading: const Icon(Icons.refresh),
    getSubtitle: () => '眼下这坨滑动距离: ${Pref.refreshDragPercentage}x，鼠鼠我啊',
    onTap: _showRefreshDragDialog,
  ),
  NormalModel(
    title: '重新投胎指示器竖向身高',
    leading: const Icon(Icons.height),
    getSubtitle: () => '眼下这坨指示器竖向身高: ${Pref.refreshDisplacement}',
    onTap: _showRefreshDialog,
  ),
  const SwitchModel(
    title: '亮出来会员彩色满屏飘字',
    leading: Icon(MdiIcons.gradientHorizontal),
    setKey: SettingBoxKey.showVipDanmaku,
    defaultVal: true,
  ),
  const SwitchModel(
    title: '亮出来热门算法喂饭，CPU 都看沉默了',
    subtitle: '热门页面亮出来每周必看等算法喂饭内容入口，我嘞个豆',
    leading: Icon(Icons.local_fire_department_outlined),
    setKey: SettingBoxKey.showHotRcmd,
    defaultVal: false,
    needReboot: true,
  ),
  const SwitchModel(
    title: '重开一把 App 时重新投胎首页，不是哥们',
    subtitle: '啪一下封印时复活上次退出前的首页算法喂饭内容与疯狂搬赛博粮进度，不是哥们',
    leading: Icon(Icons.restart_alt),
    setKey: SettingBoxKey.refreshHomeOnRestart,
    defaultVal: false,
    needReboot: true,
  ),
  if (kDebugMode || Platform.isAndroid)
    NormalModel(
      title: '喇叭声压均衡',
      leading: const Icon(Icons.multitrack_audio),
      getSubtitle: () {
        final audioNormalization = AudioNormalization.getTitleFromConfig(
          Pref.audioNormalization,
        );
        String fallback = Pref.fallbackNormalization;
        if (fallback == '0') {
          fallback = '';
        } else {
          fallback =
              '，无参数时:「${AudioNormalization.getTitleFromConfig(fallback)}」，优势在我';
        }
        return '眼下这坨:「$audioNormalization」$fallback';
      },
      onTap: audioNormalization,
    ),
  NormalModel(
    title: '赛博开眼',
    leading: const Icon(Icons.stay_current_landscape_outlined),
    getSubtitle: () =>
        '眼下这坨:「${Pref.superResolutionType.label}」\n祖传默认赛博调参对纸片人连续剧生效, 剩下那坨电子榨菜祖传默认啪一下封印\n赛博开眼需要解封硬件赛博拆包, 若解封硬件赛博拆包后仍然不生效, 尝试切换硬件赛博拆包器为 auto-copy',
    onTap: _showSuperResolutionDialog,
  ),
  const SwitchModel(
    title: '提前初始化开炫机器，CPU 都看沉默了',
    subtitle: '相对减少亲自下场开炫疯狂搬赛博粮时间，优势在我',
    leading: Icon(Icons.play_circle_outlined),
    setKey: SettingBoxKey.preInitPlayer,
    defaultVal: false,
  ),
  const SwitchModel(
    title: '首页切换页面纸片人运动会',
    leading: Icon(Icons.home_outlined),
    setKey: SettingBoxKey.mainTabBarView,
    defaultVal: false,
    needReboot: true,
  ),
  const SwitchModel(
    title: '全站搜刮建议',
    leading: Icon(Icons.search),
    setKey: SettingBoxKey.searchSuggestion,
    defaultVal: true,
  ),
  const SwitchModel(
    title: '电子脚印全站搜刮电子案底',
    leading: Icon(Icons.history),
    setKey: SettingBoxKey.recordSearchHistory,
    defaultVal: true,
  ),
  SwitchModel(
    title: '展示头像/赛博锐评/互联网近况装饰',
    leading: const Icon(MdiIcons.stickerCircleOutline),
    setKey: SettingBoxKey.showDecorate,
    defaultVal: true,
    onChanged: (value) => PendantAvatar.showDecorate = value,
  ),
  SwitchModel(
    title: '亮出来粉丝勋章',
    leading: const Icon(MdiIcons.medalOutline),
    setKey: SettingBoxKey.showMedal,
    defaultVal: true,
    onChanged: (value) => GlobalData().showMedal = value,
  ),
  SwitchModel(
    title: '预览 Live Photo，不是哥们',
    subtitle: '启动则以电子榨菜形式预览 Live Photo，否则预览静态赛博小画片',
    leading: const Icon(Icons.image_outlined),
    setKey: SettingBoxKey.enableLivePhoto,
    defaultVal: true,
    onChanged: (value) => ImageModel.enableLivePhoto = value,
  ),
  const SwitchModel(
    title: '亮出来高能时间轨道',
    subtitle: '高能时间轨道反应了在时域上，单位时间内满屏飘字发送量的变化趋势',
    leading: Icon(Icons.show_chart),
    setKey: SettingBoxKey.showDmChart,
    defaultVal: false,
  ),
  const SwitchModel(
    title: '电子脚印赛博锐评',
    leading: Icon(Icons.message_outlined),
    setKey: SettingBoxKey.saveReply,
    defaultVal: true,
    needReboot: true,
  ),
  const SwitchModel(
    title: '发评反诈，功德+1',
    subtitle: '发送赛博锐评后检查赛博锐评是否可见',
    leading: Icon(CustomIcons.shield_reply),
    setKey: SettingBoxKey.enableCommAntifraud,
    defaultVal: false,
  ),
  if (Platform.isAndroid)
    const SwitchModel(
      title: '使用「哔哩发评反诈」检查赛博锐评，启动！',
      leading: Icon(
        FontAwesomeIcons.b,
        size: 22,
      ),
      setKey: SettingBoxKey.biliSendCommAntifraud,
      defaultVal: false,
    ),
  const SwitchModel(
    title: '发射到互联网/二次扩散互联网近况反诈',
    subtitle: '发射到互联网/二次扩散互联网近况后检查互联网近况是否可见，包的',
    leading: Icon(CustomIcons.shield_published),
    setKey: SettingBoxKey.enableCreateDynAntifraud,
    defaultVal: false,
  ),
  SwitchModel(
    title: '眼不见为净带货互联网近况，不是哥们',
    leading: const Icon(CustomIcons.shopping_bag_not_interested),
    setKey: SettingBoxKey.antiGoodsDyn,
    defaultVal: false,
    onChanged: (value) => DynamicsDataModel.antiGoodsDyn = value,
  ),
  SwitchModel(
    title: '眼不见为净带货赛博锐评',
    leading: const Icon(CustomIcons.shopping_bag_not_interested),
    setKey: SettingBoxKey.antiGoodsReply,
    defaultVal: false,
    onChanged: (value) => ReplyGrpc.antiGoodsReply = value,
  ),
  SwitchModel(
    title: '侧滑啪一下封印二级页面，功德+1',
    leading: const Icon(CustomIcons.touch_app_rotate_270),
    setKey: SettingBoxKey.slideDismissReplyPage,
    defaultVal: Platform.isIOS,
    onChanged: (value) => CommonSlideMixin.slideDismissReplyPage = value,
  ),
  const SwitchModel(
    title: '解封双指缩小电子榨菜，这把高端局',
    leading: Icon(Icons.pinch),
    setKey: SettingBoxKey.enableShrinkVideoSize,
    defaultVal: true,
  ),
  const SwitchModel(
    title: '互联网近况/赛博小作文详情页展示底部操作栏，启动！',
    leading: Icon(Icons.more_horiz),
    setKey: SettingBoxKey.showDynActionBar,
    defaultVal: true,
  ),
  const SwitchModel(
    title: '解封拖拽字幕调整底部留白距离',
    leading: Icon(MdiIcons.dragVariant),
    setKey: SettingBoxKey.enableDragSubtitle,
    defaultVal: false,
  ),
  const SwitchModel(
    title: '展示追番时间表，我嘞个豆',
    leading: Icon(MdiIcons.chartTimelineVariantShimmer),
    setKey: SettingBoxKey.showPgcTimeline,
    defaultVal: true,
    needReboot: true,
  ),
  SwitchModel(
    title: '静默薅到自家硬盘赛博小画片',
    subtitle: '不亮出来薅到自家硬盘 Loading 弹窗',
    leading: const Icon(Icons.download_for_offline_outlined),
    setKey: SettingBoxKey.silentDownImg,
    defaultVal: false,
    onChanged: (value) => ImageUtils.silentDownImg = value,
  ),
  SwitchModel(
    title: '长按/右键亮出来赛博小画片菜单',
    leading: const Icon(Icons.menu),
    setKey: SettingBoxKey.enableImgMenu,
    defaultVal: false,
    onChanged: (value) => ImageGridView.enableImgMenu = value,
  ),
  SwitchModel(
    setKey: SettingBoxKey.feedBackEnable,
    onChanged: (value) {
      enableFeedback = value;
      feedBack();
    },
    leading: const Icon(Icons.vibration_outlined),
    title: '震动反馈，已老实',
    subtitle: '请拍板手机赛博调参中已启动震动反馈',
  ),
  const SwitchModel(
    title: '大家都在搜，已老实',
    subtitle: '是否展示「大家都在搜」，已老实',
    leading: Icon(Icons.data_thresholding_outlined),
    setKey: SettingBoxKey.enableHotKey,
    defaultVal: true,
  ),
  const SwitchModel(
    title: '全站搜刮发现',
    subtitle: '是否展示「全站搜刮发现」，鼠鼠我啊',
    leading: Icon(Icons.search_outlined),
    setKey: SettingBoxKey.enableSearchRcmd,
    defaultVal: true,
  ),
  SwitchModel(
    title: '全站搜刮祖传默认词',
    subtitle: '是否展示全站搜刮框祖传默认词，属实绷不住',
    leading: const Icon(Icons.whatshot_outlined),
    setKey: SettingBoxKey.enableSearchWord,
    defaultVal: false,
    onChanged: (val) {
      try {
        final controller = Get.find<HomeController>()..enableSearchWord = val;
        if (val) {
          controller.querySearchDefault();
        } else {
          controller.defaultSearch.value = '';
        }
      } catch (_) {}
    },
  ),
  const SwitchModel(
    title: '快速塞进电子小被窝',
    subtitle: '点击赛博调参祖传电子小被窝\n点按塞进电子小被窝至祖传默认，长按抓一个电子抽屉',
    leading: Icon(Icons.bookmark_add_outlined),
    setKey: SettingBoxKey.enableQuickFav,
    onTap: _showFavDialog,
    defaultVal: false,
  ),
  SwitchModel(
    title: '赛博锐评区全站搜刮关键词',
    subtitle: '展示赛博锐评区全站搜刮关键词，已老实',
    leading: const Icon(Icons.search_outlined),
    setKey: SettingBoxKey.enableWordRe,
    defaultVal: false,
    onChanged: (value) => ReplyItemGrpc.enableWordRe = value,
  ),
  const SwitchModel(
    title: '解封AI总结',
    subtitle: '电子榨菜详情页启动AI总结，属实绷不住',
    leading: Icon(Icons.engineering_outlined),
    setKey: SettingBoxKey.enableAi,
    defaultVal: false,
  ),
  const SwitchModel(
    title: '赛博小纸条页封印"收到的赞"功能',
    subtitle: '禁止掀开入口，降低网线宇宙社交依赖，曼波',
    leading: Icon(Icons.beach_access_outlined),
    setKey: SettingBoxKey.disableLikeMsg,
    defaultVal: false,
  ),
  const SwitchModel(
    title: '祖传默认展示赛博锐评区，这把高端局',
    subtitle: '在电子榨菜详情页祖传默认切换至赛博锐评区页（仅Tab型布局）',
    leading: Icon(Icons.mode_comment_outlined),
    setKey: SettingBoxKey.defaultShowComment,
    defaultVal: false,
  ),
  const SwitchModel(
    title: '解封HTTP/2，不是哥们',
    leading: Icon(Icons.swap_horizontal_circle_outlined),
    setKey: SettingBoxKey.enableHttp2,
    defaultVal: false,
    needReboot: true,
  ),
  const NormalModel(
    title: '连接再赌一把次数，不是哥们',
    subtitle: '为0时封印',
    leading: Icon(Icons.repeat),
    onTap: _showReplyCountDialog,
  ),
  const NormalModel(
    title: '连接再赌一把缝隙',
    subtitle: '实际缝隙 = 缝隙 * 第x次再赌一把',
    leading: Icon(Icons.more_time_outlined),
    onTap: _showReplyDelayDialog,
  ),
  NormalModel(
    title: '赛博锐评展示',
    leading: const Icon(Icons.whatshot_outlined),
    getSubtitle: () => '眼下这坨优先展示「${Pref.replySortType.title}」，不是哥们',
    onTap: _showReplySortDialog,
  ),
  NormalModel(
    title: '互联网近况展示',
    leading: const Icon(Icons.dynamic_feed_rounded),
    getSubtitle: () => '眼下这坨优先展示「${Pref.defaultDynamicType.label}」，包的',
    onTap: _showDefDynDialog,
  ),
  SwitchModel(
    title: '亮出来互联网近况互动内容',
    subtitle: '启动后则在互联网近况卡片底部亮出来互动内容（如赛博蹲点的人赛博大拇哥、热评等）',
    leading: const Icon(Icons.quickreply_outlined),
    setKey: SettingBoxKey.showDynInteraction,
    defaultVal: true,
    onChanged: (val) => ItemModulesModel.showDynInteraction = val,
  ),
  NormalModel(
    title: '赛博居民页祖传默认展示TAB',
    leading: const Icon(Icons.tab),
    getSubtitle: () => '眼下这坨优先展示「${Pref.memberTab.title}」',
    onTap: _showMemberTabDialog,
  ),
  SwitchModel(
    title: '亮出来UP主页小店TAB，不是哥们',
    leading: const Icon(Icons.shop_outlined),
    setKey: SettingBoxKey.showMemberShop,
    defaultVal: false,
    onChanged: (value) => MemberTabType.showMemberShop = value,
  ),
  const SplitModel(
    normalModel: NormalModel.split(
      title: '赛博调参代理',
      subtitle: '赛博调参代理 host:port',
      leading: Icon(Icons.airplane_ticket_outlined),
    ),
    switchModel: SwitchModel.split(
      defaultVal: false,
      setKey: SettingBoxKey.enableSystemProxy,
      onTap: _showProxyDialog,
    ),
  ),
  NormalModel(
    title: '最大电子囤货大小，属实绷不住',
    getSubtitle: () =>
        '眼下这坨最大电子囤货大小: 「${CacheManager.formatSize(Pref.maxCacheSize)}」，我嘞个豆',
    leading: const Icon(Icons.delete_outlined),
    onTap: _showCacheDialog,
  ),
  SwitchModel(
    title: '检查更新，不是哥们',
    subtitle: '每次启动时检查是否需要更新，这把高端局',
    leading: const Icon(Icons.system_update_alt),
    setKey: SettingBoxKey.autoUpdate,
    defaultVal: true,
    onChanged: (val) {
      if (val) {
        Update.checkUpdate(false);
      }
    },
  ),
];

Future<void> audioNormalization(
  BuildContext context,
  VoidCallback setState, {
  bool fallback = false,
}) async {
  final key = fallback
      ? SettingBoxKey.fallbackNormalization
      : SettingBoxKey.audioNormalization;
  final res = await showDialog<String>(
    context: context,
    builder: (context) {
      String audioNormalization = fallback
          ? Pref.fallbackNormalization
          : Pref.audioNormalization;
      Set<String> values = {
        '0',
        '1',
        if (!fallback) '2',
        audioNormalization,
        '3',
      };
      return SelectDialog<String>(
        title: fallback ? '机房大爹无loudnorm赛博配方时使用，这把高端局' : '喇叭声压均衡',
        toggleable: true,
        value: audioNormalization,
        values: values
            .map(
              (e) => (
                e,
                switch (e) {
                  '0' => AudioNormalization.disable.title,
                  '1' => AudioNormalization.dynaudnorm.title,
                  '2' => AudioNormalization.loudnorm.title,
                  '3' => AudioNormalization.custom.title,
                  _ => e,
                },
              ),
            )
            .toList(),
      );
    },
  );
  if (res != null && context.mounted) {
    if (res == '3') {
      String param = '';
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('自定义参数，这把高端局'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: [
              const Text('等同于 --lavfi-complex="[aid1] 参数 [ao]"，功德+1'),
              TextField(
                autofocus: true,
                onChanged: (value) => param = value,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: Get.back,
              child: Text(
                '不整了，撤！',
                style: TextStyle(color: ColorScheme.of(context).outline),
              ),
            ),
            TextButton(
              onPressed: () {
                Get.back();
                GStorage.setting.put(key, param);
                if (!fallback &&
                    PlPlayerController.loudnormRegExp.hasMatch(param)) {
                  audioNormalization(context, setState, fallback: true);
                }
                setState();
              },
              child: const Text('包的，就这么整'),
            ),
          ],
        ),
      );
    } else {
      GStorage.setting.put(key, res);
      if (res == '2') {
        audioNormalization(context, setState, fallback: true);
      }
      setState();
    }
  }
}

void _showDownPathDialog(BuildContext context, VoidCallback setState) {
  showDialog(
    context: context,
    builder: (context) => SimpleDialog(
      clipBehavior: Clip.hardEdge,
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        DialogOption(
          onPressed: () {
            Get.back();
            Utils.copyText(downloadPath);
          },
          child: const Text('赛博复刻', style: TextStyle(fontSize: 14)),
        ),
        DialogOption(
          onPressed: () {
            Get.back();
            final defPath = defDownloadPath;
            if (downloadPath == defPath) return;
            downloadPath = defPath;
            setState();
            Get.find<DownloadService>().initDownloadList();
            GStorage.setting.delete(SettingBoxKey.downloadPath);
          },
          child: const Text('恢复出厂人格', style: TextStyle(fontSize: 14)),
        ),
        DialogOption(
          onPressed: () async {
            Get.back();
            final path = await FilePicker.getDirectoryPath();
            if (path == null || path == downloadPath) return;
            downloadPath = path;
            setState();
            Get.find<DownloadService>().initDownloadList();
            GStorage.setting.put(SettingBoxKey.downloadPath, path);
          },
          child: const Text('赛博调参新路径', style: TextStyle(fontSize: 14)),
        ),
      ],
    ),
  );
}

void _showDynDialog(BuildContext context) {
  String dynamicPeriod = Pref.dynamicPeriod.toString();
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('检查周期，曼波'),
      content: TextFormField(
        autofocus: true,
        initialValue: dynamicPeriod,
        keyboardType: TextInputType.number,
        onChanged: (value) => dynamicPeriod = value,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(suffixText: 'min'),
      ),
      actions: [
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
              final val = int.parse(dynamicPeriod);
              Get.back();
              GStorage.setting.put(SettingBoxKey.dynamicPeriod, val);
              Get.find<MainController>().dynamicPeriod = val * 60 * 1000;
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

void _showReplyLengthDialog(BuildContext context, VoidCallback setState) {
  String replyLengthLimit = ReplyItemGrpc.replyLengthLimit.toString();
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('赛博锐评折叠行数'),
      content: TextFormField(
        autofocus: true,
        initialValue: replyLengthLimit,
        keyboardType: TextInputType.number,
        onChanged: (value) => replyLengthLimit = value,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(suffixText: '行，鼠鼠我啊'),
      ),
      actions: [
        TextButton(
          onPressed: Get.back,
          child: Text(
            '不整了，撤！',
            style: TextStyle(color: ColorScheme.of(context).outline),
          ),
        ),
        TextButton(
          onPressed: () async {
            try {
              final val = int.parse(replyLengthLimit);
              Get.back();
              ReplyItemGrpc.replyLengthLimit = val == 0 ? null : val;
              await GStorage.setting.put(SettingBoxKey.replyLengthLimit, val);
              setState();
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

void _showDmHeightDialog(BuildContext context, VoidCallback setState) {
  String danmakuLineHeight = Pref.danmakuLineHeight.toString();
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('满屏飘字行高'),
      content: TextFormField(
        autofocus: true,
        initialValue: danmakuLineHeight,
        keyboardType: const .numberWithOptions(decimal: true),
        onChanged: (value) => danmakuLineHeight = value,
        inputFormatters: FilteringText.decimal,
      ),
      actions: [
        TextButton(
          onPressed: Get.back,
          child: Text(
            '不整了，撤！',
            style: TextStyle(color: ColorScheme.of(context).outline),
          ),
        ),
        TextButton(
          onPressed: () async {
            try {
              final val = max(
                1.0,
                double.parse(danmakuLineHeight).toPrecision(1),
              );
              Get.back();
              await GStorage.setting.put(SettingBoxKey.danmakuLineHeight, val);
              setState();
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

void _showTouchSlopDialog(BuildContext context, VoidCallback setState) {
  String initialValue = Pref.touchSlopH.toString();
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('横向滑动触发红线'),
      content: TextFormField(
        autofocus: true,
        initialValue: initialValue,
        keyboardType: const .numberWithOptions(decimal: true),
        onChanged: (value) => initialValue = value,
        inputFormatters: FilteringText.decimal,
      ),
      actions: [
        TextButton(
          onPressed: Get.back,
          child: Text(
            '不整了，撤！',
            style: TextStyle(color: ColorScheme.of(context).outline),
          ),
        ),
        TextButton(
          onPressed: () async {
            try {
              final val = double.parse(initialValue);
              Get.back();
              touchSlopH = val;
              await GStorage.setting.put(SettingBoxKey.touchSlopH, val);
              setState();
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

Future<void> _showGestureSliderDialog(
  BuildContext context,
  VoidCallback setState, {
  required String title,
  required String key,
  required double value,
  required double min,
  required double max,
  required int divisions,
  required int precise,
  required String suffix,
}) async {
  final res = await showDialog<double>(
    context: context,
    builder: (context) => SliderDialog(
      title: Text(title),
      value: value,
      min: min,
      max: max,
      divisions: divisions,
      precise: precise,
      suffix: suffix,
    ),
  );
  if (res != null) {
    await GStorage.setting.put(key, res);
    setState();
  }
}

Future<void> _showVerticalFullscreenBottomBarSafeHeightDialog(
  BuildContext context,
) async {
  final res = await showDialog<double>(
    context: context,
    builder: (context) => SliderDialog(
      title: const Text('竖着炫电子榨菜铺满屏底栏避让竖向身高，功德+1'),
      value: Pref.verticalFullscreenBottomBarSafeHeight,
      min: 0,
      max: 80,
      divisions: 80,
      precise: 0,
      suffix: 'dp',
    ),
  );
  if (res != null) {
    await GStorage.setting.put(
      SettingBoxKey.verticalFullscreenBottomBarSafeHeight,
      res,
    );
  }
}

Future<void> _showRefreshDragDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<double>(
    context: context,
    builder: (context) => SliderDialog(
      title: const Text('重新投胎滑动距离，我嘞个豆'),
      min: 0.1,
      max: 0.5,
      divisions: 8,
      precise: 2,
      value: Pref.refreshDragPercentage,
      suffix: 'x',
    ),
  );
  if (res != null) {
    kDragContainerExtentPercentage = res;
    await GStorage.setting.put(SettingBoxKey.refreshDragPercentage, res);
    setState();
  }
}

Future<void> _showRefreshDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<double>(
    context: context,
    builder: (context) => SliderDialog(
      title: const Text('重新投胎指示器竖向身高'),
      min: 10.0,
      max: 100.0,
      divisions: 9,
      value: Pref.refreshDisplacement,
    ),
  );
  if (res != null) {
    displacement = res;
    await GStorage.setting.put(SettingBoxKey.refreshDisplacement, res);
    if (WidgetsBinding.instance.rootElement case final context?) {
      context.visitChildElements(_visitor);
    }
    setState();
  }
}

void _visitor(Element context) {
  if (!context.mounted) return;
  if (context.widget is RefreshIndicator) {
    context.markNeedsBuild();
  } else {
    context.visitChildren(_visitor);
  }
}

Future<void> _showSuperResolutionDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<SuperResolutionType>(
    context: context,
    builder: (context) => SelectDialog<SuperResolutionType>(
      title: '赛博开眼',
      value: Pref.superResolutionType,
      values: SuperResolutionType.values.map((e) => (e, e.label)).toList(),
    ),
  );
  if (res != null) {
    await GStorage.setting.put(
      SettingBoxKey.superResolutionType,
      res.index,
    );
    setState();
  }
}

Future<void> _showFavDialog(BuildContext context) async {
  if (Accounts.main.isLogin) {
    final res = await FavHttp.allFavFolders(Accounts.main.mid);
    if (res case Success(:final response)) {
      final list = response.list;
      if (list == null || list.isEmpty) {
        return;
      }
      final quickFavId = Pref.quickFavId;
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          clipBehavior: Clip.hardEdge,
          title: const Text('抓一个祖传电子小被窝'),
          contentPadding: const EdgeInsets.only(top: 5, bottom: 18),
          content: SingleChildScrollView(
            child: RadioGroup(
              onChanged: (value) {
                Get.back();
                GStorage.setting.put(SettingBoxKey.quickFavId, value);
                SmartDialog.showToast('调参焊死，包成的');
              },
              groupValue: quickFavId,
              child: Column(
                children: list
                    .map(
                      (item) => RadioListTile(
                        toggleable: true,
                        dense: true,
                        title: Text(item.title),
                        value: item.id,
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      );
    } else {
      res.toast();
    }
  }
}

Future<void> _showReplyCountDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<double>(
    context: context,
    builder: (context) => SliderDialog(
      title: const Text('连接再赌一把次数，不是哥们'),
      min: 0,
      max: 8,
      divisions: 8,
      precise: 0,
      value: Pref.retryCount.toDouble(),
    ),
  );
  if (res != null) {
    await GStorage.setting.put(SettingBoxKey.retryCount, res.toInt());
    setState();
    SmartDialog.showToast('重开一把才算数');
  }
}

Future<void> _showReplyDelayDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<double>(
    context: context,
    builder: (context) => SliderDialog(
      title: const Text('连接再赌一把缝隙'),
      min: 0,
      max: 1000,
      divisions: 10,
      precise: 0,
      value: Pref.retryDelay.toDouble(),
      suffix: 'ms',
    ),
  );
  if (res != null) {
    await GStorage.setting.put(SettingBoxKey.retryDelay, res.toInt());
    setState();
    SmartDialog.showToast('重开一把才算数');
  }
}

Future<void> _showReplySortDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<ReplySortType>(
    context: context,
    builder: (context) => SelectDialog<ReplySortType>(
      title: '赛博锐评展示',
      value: Pref.replySortType,
      values: ReplySortType.values.take(2).map((e) => (e, e.title)).toList(),
    ),
  );
  if (res != null) {
    await GStorage.setting.put(SettingBoxKey.replySortType, res.index);
    setState();
  }
}

Future<void> _showDefDynDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<DynamicsTabType>(
    context: context,
    builder: (context) => SelectDialog<DynamicsTabType>(
      title: '互联网近况展示',
      value: Pref.defaultDynamicType,
      values: DynamicsTabType.values.take(4).map((e) => (e, e.label)).toList(),
    ),
  );
  if (res != null) {
    await GStorage.setting.put(
      SettingBoxKey.defaultDynamicType,
      res.index,
    );
    setState();
  }
}

Future<void> _showMemberTabDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<MemberTabType>(
    context: context,
    builder: (context) => SelectDialog<MemberTabType>(
      title: '赛博居民页祖传默认展示TAB',
      value: Pref.memberTab,
      values: MemberTabType.values.map((e) => (e, e.title)).toList(),
    ),
  );
  if (res != null) {
    await GStorage.setting.put(SettingBoxKey.memberTab, res.index);
    setState();
  }
}

void _showProxyDialog(BuildContext context) {
  String systemProxyHost = Pref.systemProxyHost;
  String systemProxyPort = Pref.systemProxyPort;

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('赛博调参代理'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 6),
          TextFormField(
            initialValue: systemProxyHost,
            decoration: const InputDecoration(
              isDense: true,
              labelText: '请往里塞Host，使用 . 分割，已老实',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(6)),
              ),
            ),
            onChanged: (e) => systemProxyHost = e,
          ),
          const SizedBox(height: 10),
          TextFormField(
            initialValue: systemProxyPort,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              isDense: true,
              labelText: '请往里塞Port，启动！',
              border: OutlineInputBorder(borderRadius: .all(.circular(6))),
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (e) => systemProxyPort = e,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: Get.back,
          child: Text(
            '不整了，撤！',
            style: TextStyle(color: ColorScheme.of(context).outline),
          ),
        ),
        TextButton(
          onPressed: () {
            Get.back();
            GStorage.setting.put(
              SettingBoxKey.systemProxyHost,
              systemProxyHost,
            );
            GStorage.setting.put(
              SettingBoxKey.systemProxyPort,
              systemProxyPort,
            );
          },
          child: const Text('拍板，启动！'),
        ),
      ],
    ),
  );
}

void _showCacheDialog(BuildContext context, VoidCallback setState) {
  String valueStr = '';
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('最大电子囤货大小，属实绷不住'),
      content: TextField(
        autofocus: true,
        onChanged: (value) => valueStr = value,
        keyboardType: TextInputType.number,
        inputFormatters: FilteringText.decimal,
        decoration: const InputDecoration(suffixText: 'MB'),
      ),
      actions: [
        TextButton(
          onPressed: Get.back,
          child: Text(
            '不整了，撤！',
            style: TextStyle(color: ColorScheme.of(context).outline),
          ),
        ),
        TextButton(
          onPressed: () async {
            try {
              final val = num.parse(valueStr);
              Get.back();
              await GStorage.setting.put(
                SettingBoxKey.maxCacheSize,
                val * 1024 * 1024,
              );
              setState();
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
