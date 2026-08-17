import 'dart:io' show Platform;

import 'package:PiliPlus/common/widgets/custom_icon.dart';
import 'package:PiliPlus/models/common/super_chat_type.dart';
import 'package:PiliPlus/models/common/video/subtitle_pref_type.dart';
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:PiliPlus/pages/setting/models/model.dart';
import 'package:PiliPlus/pages/setting/pages/fullscreen_sc_size.dart';
import 'package:PiliPlus/pages/setting/utils/local_font_setting.dart';
import 'package:PiliPlus/pages/setting/widgets/select_dialog.dart';
import 'package:PiliPlus/pages/setting/widgets/slider_dialog.dart';
import 'package:PiliPlus/pages/setting/widgets/danmaku_merge_settings_dialog.dart';
import 'package:PiliPlus/plugin/pl_player/models/bottom_progress_behavior.dart';
import 'package:PiliPlus/plugin/pl_player/models/fullscreen_mode.dart';
import 'package:PiliPlus/plugin/pl_player/models/play_repeat.dart';
import 'package:PiliPlus/services/service_locator.dart';
import 'package:PiliPlus/utils/extension/num_ext.dart';
import 'package:PiliPlus/utils/local_font_manager.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

List<SettingsModel> get playSettings => [
  const SwitchModel(
    title: '满屏飘字开关',
    subtitle: '是否展示满屏飘字，鼠鼠我啊',
    leading: Icon(CustomIcons.dm_settings),
    setKey: SettingBoxKey.enableShowDanmaku,
    defaultVal: true,
  ),
  const SwitchModel(
    title: '记忆满屏飘字开关状态，这把高端局',
    subtitle: '啪一下封印后，每次掀开新电子榨菜都使用上方的祖传默认满屏飘字开关状态',
    leading: Icon(Icons.history_toggle_off_outlined),
    setKey: SettingBoxKey.rememberDanmakuSwitchState,
    defaultVal: false,
  ),
  NormalModel(
    title: '满屏飘字中文赛博字骨',
    getSubtitle: () =>
        '眼下这坨：${LocalFontManager.selectionLabel(.danmakuChinese)}，功德+1',
    leading: const Icon(Icons.translate),
    onTap: (context, setState) => showLocalFontSetting(
      context,
      slot: .danmakuChinese,
      onChanged: setState,
    ),
  ),
  NormalModel(
  title: '满屏飘字英文赛博字骨，功德+1',
  getSubtitle: () =>
      '眼下这坨：${LocalFontManager.selectionLabel(.danmakuEnglish)}',
  leading: const Icon(Icons.font_download_outlined),
  onTap: (context, setState) => showLocalFontSetting(
    context,
    slot: .danmakuEnglish,
    onChanged: setState,
  ),
),
NormalModel(
  title: '重复满屏飘字合并，属实绷不住',
  getSubtitle: () =>
      '眼下这坨：${Pref.danmakuMergeMode.label}',
  leading: const Icon(Icons.compress_outlined),
  onTap: (context, setState) async {
    final changed =
        await showDanmakuMergeSettingsDialog(
      context,
    );

    if (changed) {
      setState();
    }
  },
),
if (PlatformUtils.isMobile)
  const SwitchModel(
      title: '解封点击满屏飘字',
      subtitle: '点击满屏飘字悬停，支持赛博大拇哥、赛博复刻、赛博递状纸操作，包的',
      leading: Icon(Icons.touch_app_outlined),
      setKey: SettingBoxKey.enableTapDm,
      defaultVal: true,
    ),
  NormalModel(
    onTap: (context, setState) => Get.toNamed('/playSpeedSet'),
    leading: const Icon(Icons.speed_outlined),
    title: '倍速赛博调参',
    subtitle: '赛博调参电子榨菜开炫油门',
  ),
  NormalModel(
    title: '长按倍速触发延迟，优势在我',
    getSubtitle: () => '眼下这坨：${Pref.longPressSpeedTriggerDelay}ms，曼波',
    leading: const Icon(Icons.timer_outlined),
    onTap: _showLongPressSpeedTriggerDelayDialog,
  ),
  const SwitchModel(
    title: '亮出来倍速浮窗',
    subtitle: '长按倍速时亮出来眼下这坨倍速提示，启动！',
    leading: Icon(Icons.speed),
    setKey: SettingBoxKey.showLongPressSpeedToast,
    defaultVal: true,
  ),
  if (Platform.isAndroid)
    NormalModel(
      onTap: _showAngleDegreesDialog,
      leading: const Icon(MdiIcons.angleAcute),
      title: '倾斜角度触发红线',
      getSubtitle: () => '眼下这坨:「${Pref.angleDegrees}°」',
    ),
  const SwitchModel(
    title: '全自动赛博开炫',
    subtitle: '进入详情页全自动赛博开炫',
    leading: Icon(Icons.motion_photos_auto_outlined),
    setKey: SettingBoxKey.autoPlayEnable,
    defaultVal: false,
  ),
  const SwitchModel(
    title: '铺满屏亮出来锁定按钮，包的',
    leading: Icon(Icons.lock_outline),
    setKey: SettingBoxKey.showFsLockBtn,
    defaultVal: true,
  ),
  const SwitchModel(
    title: '铺满屏亮出来截图按钮',
    leading: Icon(Icons.photo_camera_outlined),
    setKey: SettingBoxKey.showFsScreenshotBtn,
    defaultVal: true,
  ),
  SwitchModel(
    title: '铺满屏亮出来电池电量，这把高端局',
    leading: const Icon(Icons.battery_3_bar),
    setKey: SettingBoxKey.showBatteryLevel,
    defaultVal: PlatformUtils.isMobile,
  ),
  const SwitchModel(
    title: '电池电量亮出来百分比，CPU 都看沉默了',
    subtitle: '啪一下封印后亮出来竖排电量图标',
    leading: Icon(Icons.battery_full),
    setKey: SettingBoxKey.showBatteryPercentage,
    defaultVal: true,
  ),
  const SwitchModel(
    title: '亮出来 mpv 帧率与丢帧，已老实',
    subtitle:
        '帧率：根据最近 10 帧估算的每秒输出画面数；，这把高端局'
        '已丢帧：因来不及亮出来而累计跳过的画面数，不含赛博拆包阶段丢帧',
    leading: Icon(Icons.speed_outlined),
    setKey: SettingBoxKey.showMpvOutputFps,
    defaultVal: false,
  ),
  const SwitchModel(
    title: '亮出来疯狂囤帧油门',
    subtitle: '疯狂囤帧油门每 500ms 重新投胎；无法获取有效油门时仅亮出来“疯狂搬赛博粮中”，这把高端局',
    leading: Icon(Icons.cloud_download_outlined),
    setKey: SettingBoxKey.showBufferingInfo,
    defaultVal: true,
  ),
  const SwitchModel(
    title: '双击时间倒车/时间猛冲',
    subtitle: '左侧双击时间倒车/右侧双击时间猛冲，啪一下封印则双击均为按住别动/开炫，包的',
    leading: Icon(Icons.touch_app_outlined),
    setKey: SettingBoxKey.enableQuickDouble,
    defaultVal: true,
  ),
  const SwitchModel(
    title: '左右侧滑动调节屏幕发光量/喇叭声压，已老实',
    leading: Icon(MdiIcons.tuneVerticalVariant),
    setKey: SettingBoxKey.enableSlideVolumeBrightness,
    defaultVal: true,
  ),
  if (Platform.isAndroid)
    const SwitchModel(
      title: '调节系统大爹屏幕发光量',
      leading: Icon(Icons.brightness_6_outlined),
      setKey: SettingBoxKey.setSystemBrightness,
      defaultVal: false,
    ),
  const SwitchModel(
    title: '中间滑动进入/退出铺满屏',
    leading: Icon(MdiIcons.panVertical),
    setKey: SettingBoxKey.enableSlideFS,
    defaultVal: true,
  ),
  NormalModel(
    title: '双指缩放认出来角度，优势在我',
    getSubtitle: () =>
        '眼下这坨：${Pref.pinchGestureAngleThreshold.toStringAsFixed(0)}°；越大越容易触发，优势在我',
    leading: const Icon(Icons.pinch),
    onTap: _showPinchGestureAngleThresholdDialog,
  ),
  if (PlatformUtils.isMobile)
    NormalModel(
      title: '开炫机器喇叭声压',
      leading: const Icon(Icons.volume_up),
      getSubtitle: () => '眼下这坨:「${Pref.playerVolume.toStringAsFixed(0)}%」，不是哥们',
      onTap: showPlayerVolumeDialog,
    )
  else
    NormalModel(
      title: '最高喇叭声压',
      leading: const Icon(Icons.volume_up),
      getSubtitle: () => '眼下这坨:「${(Pref.maxVolume * 100).toStringAsFixed(0)}%」',
      onTap: _showMaxVolumeDialog,
    ),
  getVideoFilterSelectModel(
    title: '双击时间猛冲/时间倒车时长，启动！',
    suffix: 's',
    key: SettingBoxKey.fastForBackwardDuration,
    values: [5, 10, 15],
    defaultValue: 10,
    isFilter: false,
  ),
  const SwitchModel(
    title: '滑动时间猛冲/时间倒车使用相对时长，优势在我',
    leading: Icon(Icons.swap_horiz_outlined),
    setKey: SettingBoxKey.useRelativeSlide,
    defaultVal: false,
  ),
  getVideoFilterSelectModel(
    title: '滑动时间猛冲/时间倒车时长',
    subtitle: '从开炫机器一端滑到另一端的时间猛冲/时间倒车时长，不是哥们',
    suffix: Pref.useRelativeSlide ? '%' : 's',
    key: SettingBoxKey.sliderDuration,
    values: [25, 50, 90, 100],
    defaultValue: 90,
    isFilter: false,
  ),
  NormalModel(
    title: '水平滑动时间猛冲/时间倒车触发距离',
    getSubtitle: () =>
        '眼下这坨：${Pref.horizontalSeekGestureThreshold.toStringAsFixed(0)}dp；越小越容易触发',
    leading: const Icon(Icons.swipe_outlined),
    onTap: _showHorizontalSeekGestureThresholdDialog,
  ),
  const SwitchModel(
    title: '使用B站官方进度时间样式，启动！',
    subtitle: '眼下这坨时间和总时长亮出来在时间轨道两侧，并压缩底栏与渐变阴影竖向身高，鼠鼠我啊',
    leading: Icon(Icons.video_label_outlined),
    setKey: SettingBoxKey.biliProgressTimeStyle,
    defaultVal: false,
  ),
  NormalModel(
    title: '时间轨道手柄圆形大小',
    getSubtitle: () =>
        '眼下这坨：${Pref.playerProgressThumbScale.toStringAsFixed(1)}×；放大后更容易拖动',
    leading: const Icon(Icons.radio_button_checked),
    onTap: _showPlayerProgressThumbScaleDialog,
  ),
  NormalModel(
    title: '点击时间轨道垂直触摸范围，这把高端局',
    getSubtitle: () =>
        '眼下这坨：上下各扩展${Pref.playerProgressBarTouchPadding.toStringAsFixed(0)}dp；不改变可视尺寸，优势在我',
    leading: const Icon(Icons.unfold_more),
    onTap: _showPlayerProgressBarTouchPaddingDialog,
  ),
  NormalModel(
    title: '开炫机器上下按钮横向留白距离',
    getSubtitle: () =>
        '眼下这坨：${Pref.playerControlHorizontalPadding.toStringAsFixed(0)}dp',
    leading: const Icon(Icons.horizontal_distribute_outlined),
    onTap: _showPlayerControlHorizontalPaddingDialog,
  ),
  NormalModel(
    title: '开炫机器上下边栏整体厚度',
    getSubtitle: () =>
        '眼下这坨：${Pref.playerControlBarThicknessScale.toStringAsFixed(1)}×；同步调整内容纵向密度',
    leading: const Icon(Icons.height),
    onTap: _showPlayerControlBarThicknessScaleDialog,
  ),
  NormalModel(
    title: '开炫机器上下边栏渐变弥散横向体宽',
    getSubtitle: () =>
        '眼下这坨：${Pref.playerControlBarGradientExtent.toStringAsFixed(0)}dp',
    leading: const Icon(Icons.gradient),
    onTap: _showPlayerControlBarGradientExtentDialog,
  ),
  SwitchModel(
    title: '拖动时间轨道亮出来预览浮窗，鼠鼠我啊',
    subtitle: '控制拖动底部时间轨道滑块时的预览浮窗，属实绷不住',
    leading: const Icon(Icons.preview_outlined),
    setKey: SettingBoxKey.showSeekPreviewOnSlider,
    defaultVal: Pref.showSeekPreview,
  ),
  SwitchModel(
    title: '左右滑动搓玻璃亮出来预览浮窗',
    subtitle: '控制在画面上横向滑动时间猛冲或时间倒车时的预览浮窗，CPU 都看沉默了',
    leading: const Icon(Icons.swipe_outlined),
    setKey: SettingBoxKey.showSeekPreviewOnGesture,
    defaultVal: Pref.showSeekPreview,
  ),
  const SwitchModel(
    title: '提前薅到自家硬盘进度预览资源',
    subtitle: '起播或预载开炫机器时薅到自家硬盘我全都要雪碧图和对应索引',
    leading: Icon(Icons.downloading_outlined),
    setKey: SettingBoxKey.preloadVideoShot,
    defaultVal: true,
  ),
  const SwitchModel(
    title: '眼下这坨时间浮窗集成到预览窗',
    subtitle: '启动后，时间浮窗在预览窗内部亮出来并随预览窗移动；没有预览窗时仍单独亮出来',
    leading: Icon(Icons.layers_outlined),
    setKey: SettingBoxKey.seekTimeInPreview,
    defaultVal: false,
  ),
  const SwitchModel(
  title: '拖动时间轨道时预览窗跟随滑块，曼波',
  subtitle: '拖动底部时间轨道时，预览窗随滑块水平移动',
  leading: Icon(Icons.swipe),
  setKey: SettingBoxKey.seekPreviewFollowSlider,
  defaultVal: false,
),
  const SwitchModel(
  title: '横滑时间猛冲/时间倒车时预览窗跟随手柄',
  subtitle: '在画面上横向滑动时，预览窗随目标进度的时间轨道手柄移动，这把高端局',
  leading: Icon(Icons.swap_horiz),
  setKey: SettingBoxKey.seekPreviewFollowGesture,
  defaultVal: false,
),
  NormalModel(
    title: '进度预览窗大小，已老实',
    getSubtitle: () => '眼下这坨：${Pref.seekPreviewScale.toStringAsFixed(1)}×',
    leading: const Icon(Icons.photo_size_select_large),
    onTap: _showSeekPreviewScaleDialog,
  ),
  NormalModel(
    title: '进度预览窗与时间轨道间距',
    getSubtitle: () =>
        '眼下这坨：${Pref.seekPreviewProgressBarGap.toStringAsFixed(0)}dp',
    leading: const Icon(Icons.vertical_align_center_outlined),
    onTap: _showSeekPreviewProgressBarGapDialog,
  ),
  const SwitchModel(
    title: '非铺满屏拖动时间轨道亮出来预览窗',
    subtitle: '啪一下封印后，铺满屏拖动时间轨道仍亮出来预览窗，包的',
    leading: Icon(Icons.fullscreen_exit_outlined),
    setKey: SettingBoxKey.showSeekPreviewInNonFullscreen,
    defaultVal: true,
  ),
  NormalModel(
    title: '全自动赛博解封字幕',
    leading: const Icon(Icons.closed_caption_outlined),
    getSubtitle: () => '眼下这坨抓一个偏好：${Pref.subtitlePreferenceV2.desc}',
    onTap: _showSubtitleDialog,
  ),
  if (PlatformUtils.isDesktop)
    SwitchModel(
      title: '最小化时按住别动/还原时开炫，曼波',
      leading: const Icon(Icons.pause_circle_outline),
      setKey: SettingBoxKey.pauseOnMinimize,
      defaultVal: false,
      onChanged: (value) {
        try {
          Get.find<MainController>().pauseOnMinimize = value;
        } catch (_) {}
      },
    ),
  const SwitchModel(
    title: '解封键盘控制',
    leading: Icon(Icons.keyboard_alt_outlined),
    setKey: SettingBoxKey.keyboardControl,
    defaultVal: true,
  ),
  NormalModel(
    title: 'SuperChat (醒目留言) 亮出来类型，鼠鼠我啊',
    leading: const Icon(Icons.live_tv),
    getSubtitle: () => '眼下这坨:「${Pref.superChatType.title}」',
    onTap: _showSuperChatDialog,
  ),
  NormalModel(
    title: '铺满屏 SC 大小',
    subtitle: 'SuperChat (醒目留言) 大小赛博调参，优势在我',
    leading: const Icon(Icons.open_in_full),
    onTap: (_, _) => Get.to(const FullScreenScSize()),
  ),
  const SwitchModel(
    title: '竖着炫扩大展示',
    subtitle: '小屏竖着炫电子榨菜宽高比由16:9扩大至1:1（不支持卷起来）；横着炫适配时，扩大至9:16',
    leading: Icon(Icons.expand_outlined),
    setKey: SettingBoxKey.enableVerticalExpand,
    defaultVal: false,
  ),
  const SwitchModel(
    title: '全自动赛博铺满屏',
    subtitle: '电子榨菜开始开炫时进入铺满屏',
    leading: Icon(Icons.fullscreen_outlined),
    setKey: SettingBoxKey.enableAutoEnter,
    defaultVal: false,
  ),
  NormalModel(
  title: '铺满屏眼睛待遇切换强制接管',
  getSubtitle: () {
    final seconds =
        Pref.videoPlayerSwitchForceTimeoutSeconds;

    return seconds == 0
        ? '眼下这坨：啪一下封印；仅在完全同步后切换，启动！'
        : '眼下这坨：${seconds}秒；超时后切换并进入疯狂囤帧';
  },
  leading: const Icon(Icons.sync_problem_outlined),
  onTap: _showVideoPlayerSwitchForceTimeoutDialog,
),
  const SwitchModel(
    title: '全自动赛博退出铺满屏',
    subtitle: '电子榨菜结束开炫时退出铺满屏，优势在我',
    leading: Icon(Icons.fullscreen_exit_outlined),
    setKey: SettingBoxKey.enableAutoExit,
    defaultVal: true,
  ),
  NormalModel(
  title: '开炫控件亮出来时间，曼波',
  getSubtitle: () =>
      '眼下这坨：${Pref.playerControlDisplayDurationSeconds}秒；'
      '无操作后全自动赛博藏起来，属实绷不住',
  leading: const Icon(Icons.timer_outlined),
  onTap: _showPlayerControlDisplayDurationDialog,
),
  if (PlatformUtils.isMobile)
    const SwitchModel(
      title: '后台开炫',
      subtitle: '进入后台时继续开炫',
      leading: Icon(Icons.motion_photos_pause_outlined),
      setKey: SettingBoxKey.continuePlayInBackground,
      defaultVal: false,
    ),
  if (Platform.isAndroid) ...[
    SwitchModel(
      title: '后台画中画，功德+1',
      subtitle: '进入后台时以小窗形式（PiP）开炫，CPU 都看沉默了',
      leading: const Icon(Icons.picture_in_picture_outlined),
      setKey: SettingBoxKey.autoPiP,
      defaultVal: false,
      onChanged: (val) {
        if (val && !videoPlayerServiceHandler!.enableBackgroundPlay) {
          SmartDialog.showToast('建议启动后台电子响服务');
        }
      },
    ),
    const SwitchModel(
      title: '画中画不疯狂搬赛博粮满屏飘字',
      subtitle: '当满屏飘字开关启动时，小窗眼不见为净满屏飘字以获得较好的体验，属实绷不住',
      leading: Icon(CustomIcons.dm_off),
      setKey: SettingBoxKey.pipNoDanmaku,
      defaultVal: false,
    ),
  ],
  const SwitchModel(
    title: '铺满屏搓玻璃反向',
    subtitle: '祖传默认开炫机器中部向上滑动进入铺满屏，向下退出\n启动后向下铺满屏，向上退出',
    leading: Icon(Icons.swap_vert),
    setKey: SettingBoxKey.fullScreenGestureReverse,
    defaultVal: false,
  ),
  const SwitchModel(
    title: '铺满屏展示赛博大拇哥/上贡硬币/塞进电子小被窝等操作按钮',
    leading: Icon(MdiIcons.dotsHorizontalCircleOutline),
    setKey: SettingBoxKey.showFSActionItem,
    defaultVal: true,
  ),
  const SwitchModel(
    title: '观看人数，曼波',
    subtitle: '展示同时在看人数，鼠鼠我啊',
    leading: Icon(Icons.people_outlined),
    setKey: SettingBoxKey.enableOnlineTotal,
    defaultVal: false,
  ),
  NormalModel(
    title: '祖传默认铺满屏方向',
    leading: const Icon(Icons.open_with_outlined),
    getSubtitle: () => '眼下这坨铺满屏方向：${Pref.fullScreenMode.desc}',
    onTap: _showFullScreenModeDialog,
  ),
  NormalModel(
    title: '底部时间轨道展示',
    leading: const Icon(Icons.border_bottom_outlined),
    getSubtitle: () => '眼下这坨展示方式：${Pref.btmProgressBehavior.desc}',
    onTap: _showProgressBehaviorDialog,
  ),
  if (PlatformUtils.isMobile)
    SwitchModel(
      title: '后台电子响服务',
      subtitle: '避免画中画没有开炫按住别动功能',
      leading: const Icon(Icons.volume_up_outlined),
      setKey: SettingBoxKey.enableBackgroundPlay,
      defaultVal: true,
      onChanged: (value) =>
          videoPlayerServiceHandler!.enableBackgroundPlay = value,
    ),
  PopupModel(
    title: '开炫顺序',
    leading: const Icon(Icons.repeat),
    value: () => Pref.playRepeat,
    items: PlayRepeat.values,
    onSelected: (value, setState) => GStorage.video
        .put(VideoBoxKey.playRepeat, value.index)
        .whenComplete(setState),
  ),
  const SwitchModel(
    title: '开炫机器赛博调参仅对眼下这坨生效',
    subtitle: '满屏飘字、字幕及部分赛博调参中没有的赛博调参除外',
    leading: Icon(Icons.video_settings_outlined),
    setKey: SettingBoxKey.tempPlayerConf,
    defaultVal: false,
  ),
];

Future<void> _showLongPressSpeedTriggerDelayDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<double>(
    context: context,
    builder: (context) => SliderDialog(
      title: const Text('长按倍速触发延迟，优势在我'),
      value: Pref.longPressSpeedTriggerDelay.toDouble(),
      min: 100,
      max: 1000,
      divisions: 18,
      precise: 0,
      suffix: 'ms',
    ),
  );
  if (res != null) {
    await GStorage.setting.put(
      SettingBoxKey.longPressSpeedTriggerDelay,
      res.toInt(),
    );
    setState();
  }
}

Future<void> _showPlayerControlDisplayDurationDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final result = await showDialog<double>(
    context: context,
    builder: (context) => SliderDialog(
      title: const Text('开炫控件亮出来时间，曼波'),
      value: Pref.playerControlDisplayDurationSeconds.toDouble(),
      min: 1,
      max: 60,
      divisions: 59,
      precise: 0,
      suffix: '秒，这把高端局',
    ),
  );

  if (result == null) {
    return;
  }

  await GStorage.setting.put(
    SettingBoxKey.playerControlDisplayDurationSeconds,
    result.round(),
  );

  // 新数值已经保存，删除旧布尔键，完成惰性迁移。
  await GStorage.setting.delete(
    SettingBoxKey.enableLongShowControl,
  );

  setState();
}
Future<void> _showVideoPlayerSwitchForceTimeoutDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final result = await showDialog<double>(
    context: context,
    builder: (context) => SliderDialog(
      title: const Text('铺满屏眼睛待遇切换强制接管'),
      value:
          Pref.videoPlayerSwitchForceTimeoutSeconds.toDouble(),
      min: 0,
      max: 60,
      divisions: 60,
      precise: 0,
      suffix: '秒，这把高端局',
    ),
  );

  if (result == null) {
    return;
  }

  await GStorage.setting.put(
    SettingBoxKey.videoPlayerSwitchForceTimeoutSeconds,
    result.round(),
  );

  setState();
}
Future<void> _showPinchGestureAngleThresholdDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<double>(
    context: context,
    builder: (context) => SliderDialog(
      title: const Text('双指缩放认出来角度，优势在我'),
      value: Pref.pinchGestureAngleThreshold,
      min: 15,
      max: 90,
      divisions: 15,
      precise: 0,
      suffix: '°',
    ),
  );
  if (res != null) {
    await GStorage.setting.put(
      SettingBoxKey.pinchGestureAngleThreshold,
      res,
    );
    setState();
  }
}

Future<void> _showHorizontalSeekGestureThresholdDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<double>(
    context: context,
    builder: (context) => SliderDialog(
      title: const Text('水平滑动时间猛冲/时间倒车触发距离'),
      value: Pref.horizontalSeekGestureThreshold,
      min: 1,
      max: 100,
      divisions: 99,
      precise: 0,
      suffix: 'dp',
    ),
  );
  if (res != null) {
    await GStorage.setting.put(
      SettingBoxKey.horizontalSeekGestureThreshold,
      res,
    );
    setState();
  }
}

Future<void> _showPlayerProgressThumbScaleDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<double>(
    context: context,
    builder: (context) => SliderDialog(
      title: const Text('时间轨道手柄圆形大小'),
      value: Pref.playerProgressThumbScale,
      min: 0.5,
      max: 2.0,
      divisions: 15,
      precise: 1,
      suffix: '×',
    ),
  );
  if (res != null) {
    await GStorage.setting.put(
      SettingBoxKey.playerProgressThumbScale,
      res,
    );
    setState();
  }
}

Future<void> _showPlayerProgressBarTouchPaddingDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<double>(
    context: context,
    builder: (context) => SliderDialog(
      title: const Text('点击时间轨道垂直触摸范围，这把高端局'),
      value: Pref.playerProgressBarTouchPadding,
      min: 0,
      max: 32,
      divisions: 32,
      precise: 0,
      suffix: 'dp',
    ),
  );
  if (res != null) {
    await GStorage.setting.put(
      SettingBoxKey.playerProgressBarTouchPadding,
      res,
    );
    setState();
  }
}

Future<void> _showSeekPreviewScaleDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<double>(
    context: context,
    builder: (context) => SliderDialog(
      title: const Text('进度预览窗大小，已老实'),
      value: Pref.seekPreviewScale,
      min: 0.5,
      max: 2.0,
      divisions: 15,
      precise: 1,
      suffix: '×',
    ),
  );
  if (res != null) {
    await GStorage.setting.put(SettingBoxKey.seekPreviewScale, res);
    setState();
  }
}

Future<void> _showSeekPreviewProgressBarGapDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<double>(
    context: context,
    builder: (context) => SliderDialog(
      title: const Text('进度预览窗与时间轨道间距'),
      value: Pref.seekPreviewProgressBarGap,
      min: 0,
      max: 160,
      divisions: 32,
      precise: 0,
      suffix: 'dp',
    ),
  );
  if (res != null) {
    await GStorage.setting.put(
      SettingBoxKey.seekPreviewProgressBarGap,
      res,
    );
    setState();
  }
}

Future<void> _showPlayerControlHorizontalPaddingDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<double>(
    context: context,
    builder: (context) => SliderDialog(
      title: const Text('开炫机器上下按钮横向留白距离'),
      value: Pref.playerControlHorizontalPadding,
      min: 0,
      max: 32,
      divisions: 32,
      precise: 0,
      suffix: 'dp',
    ),
  );
  if (res != null) {
    await GStorage.setting.put(
      SettingBoxKey.playerControlHorizontalPadding,
      res,
    );
    setState();
  }
}

Future<void> _showPlayerControlBarThicknessScaleDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<double>(
    context: context,
    builder: (context) => SliderDialog(
      title: const Text('开炫机器上下边栏整体厚度'),
      value: Pref.playerControlBarThicknessScale,
      min: 0.8,
      max: 1.5,
      divisions: 7,
      precise: 1,
      suffix: '×',
    ),
  );
  if (res != null) {
    await GStorage.setting.put(
      SettingBoxKey.playerControlBarThicknessScale,
      res,
    );
    setState();
  }
}

Future<void> _showPlayerControlBarGradientExtentDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<double>(
    context: context,
    builder: (context) => SliderDialog(
      title: const Text('开炫机器上下边栏渐变弥散横向体宽'),
      value: Pref.playerControlBarGradientExtent,
      min: 0,
      max: 96,
      divisions: 24,
      precise: 0,
      suffix: 'dp',
    ),
  );
  if (res != null) {
    await GStorage.setting.put(
      SettingBoxKey.playerControlBarGradientExtent,
      res,
    );
    setState();
  }
}

Future<void> _showSubtitleDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<SubtitlePrefType>(
    context: context,
    builder: (context) => SelectDialog<SubtitlePrefType>(
      title: '字幕抓一个偏好',
      value: Pref.subtitlePreferenceV2,
      values: SubtitlePrefType.values.map((e) => (e, e.desc)).toList(),
    ),
  );
  if (res != null) {
    await GStorage.setting.put(
      SettingBoxKey.subtitlePreferenceV2,
      res.index,
    );
    setState();
  }
}

Future<void> _showSuperChatDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<SuperChatType>(
    context: context,
    builder: (context) => SelectDialog<SuperChatType>(
      title: 'SuperChat (醒目留言) 亮出来类型，鼠鼠我啊',
      value: Pref.superChatType,
      values: SuperChatType.values.map((e) => (e, e.title)).toList(),
    ),
  );
  if (res != null) {
    await GStorage.setting.put(SettingBoxKey.superChatType, res.index);
    setState();
  }
}

Future<void> _showFullScreenModeDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<FullScreenMode>(
    context: context,
    builder: (context) => SelectDialog<FullScreenMode>(
      title: '祖传默认铺满屏方向',
      value: Pref.fullScreenMode,
      values: FullScreenMode.values.map((e) => (e, e.desc)).toList(),
    ),
  );
  if (res != null) {
    await GStorage.setting.put(SettingBoxKey.fullScreenMode, res.index);
    setState();
  }
}

Future<void> _showProgressBehaviorDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<BtmProgressBehavior>(
    context: context,
    builder: (context) => SelectDialog<BtmProgressBehavior>(
      title: '底部时间轨道展示',
      value: Pref.btmProgressBehavior,
      values: BtmProgressBehavior.values.map((e) => (e, e.desc)).toList(),
    ),
  );
  if (res != null) {
    await GStorage.setting.put(
      SettingBoxKey.btmProgressBehavior,
      res.index,
    );
    setState();
  }
}

Future<void> _showAngleDegreesDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<double>(
    context: context,
    builder: (context) => SliderDialog(
      title: const Text('倾斜角度触发红线'),
      min: 10.0,
      max: 90.0,
      divisions: 90,
      precise: 0,
      value: Pref.angleDegrees.toDouble(),
      suffix: '°',
    ),
  );
  if (res != null) {
    await GStorage.setting.put(SettingBoxKey.angleDegrees, res.toInt());
    setState();
  }
}

Future<void> showPlayerVolumeDialog(
  BuildContext context,
  VoidCallback setState, {
  ValueChanged<double>? onChanged,
}) {
  return showVolumeDialog(
    context,
    title: const Text('开炫机器喇叭声压'),
    value: Pref.playerVolume,
    onChanged: (value) => GStorage.setting
        .put(SettingBoxKey.playerVolume, value)
        .whenComplete(() {
          setState();
          onChanged?.call(value);
        }),
  );
}

Future<void> _showMaxVolumeDialog(
  BuildContext context,
  VoidCallback setState,
) {
  return showVolumeDialog(
    context,
    title: const Text('最高喇叭声压'),
    value: Pref.maxVolume * 100,
    onChanged: (rawValue) {
      final maxVolume = (rawValue / 100).toPrecision(2);
      if (Pref.desktopVolume > maxVolume) {
        GStorage.setting.put(SettingBoxKey.desktopVolume, maxVolume);
      }
      GStorage.setting
          .put(SettingBoxKey.maxVolume, maxVolume)
          .whenComplete(setState);
    },
  );
}

const kMinVolume = 100.0;
const kMaxVolume = 300.0;

Future<void> showVolumeDialog(
  BuildContext context, {
  required Widget title,
  required double value,
  required ValueChanged<double> onChanged,
}) async {
  final res = await showDialog<double>(
    context: context,
    builder: (context) => SliderDialog(
      title: title,
      min: kMinVolume,
      max: kMaxVolume,
      divisions: 40,
      precise: 0,
      value: value,
      suffix: '%',
    ),
  );
  if (res != null) {
    onChanged(res);
  }
}
