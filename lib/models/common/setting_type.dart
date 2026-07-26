import 'package:PiliPlus/pages/setting/models/extra_settings.dart';
import 'package:PiliPlus/pages/setting/models/home_card_layout_settings.dart';
import 'package:PiliPlus/pages/setting/models/horizontal_seek_gesture_settings.dart';
import 'package:PiliPlus/pages/setting/models/model.dart';
import 'package:PiliPlus/pages/setting/models/play_settings.dart';
import 'package:PiliPlus/pages/setting/models/privacy_settings.dart';
import 'package:PiliPlus/pages/setting/models/recommend_settings.dart';
import 'package:PiliPlus/pages/setting/models/style_settings.dart';
import 'package:PiliPlus/pages/setting/models/video_settings.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';

const Set<String> _advancedSettingTitles = {
  '竖屏视频全屏底栏避让系统导航栏',
  '弹幕行高',
  '横向滑动阈值',
  '横向标签页快滑速度阈值',
  '进度浮窗垂直位置',
  '长按倍速浮窗垂直位置',
  '进度浮窗字体大小',
  '长按倍速浮窗字体大小',
  '音量手势识别角度',
  '亮度手势识别角度',
  '刷新指示器高度',
  '首页顶部分类栏高度',
  '首页传统底栏底部留白',
  '卡片圆角半径',
  '主页卡片左右间隔',
  '主页卡片上下间隔',
  '主页卡片左右边距',
  '首页推荐卡片时长与统计同行',
  '首页卡片播放量与弹幕数间距',
  '滑动动画弹簧参数',
  '页面上下滚动惯性',
  '折叠回复字号比例',
  '评论区评论行距',
  '屏幕帧率',
  '弹幕英文字体',
  '双指缩放识别角度',
  '水平滑动快进/快退触发距离',
  '横向滑动快进/快退识别角度',
  '进度条手柄圆形大小',
  '点击进度条垂直触摸范围',
  '播放器上下按钮横向边距',
  '播放器上下边栏整体厚度',
  '播放器上下边栏渐变弥散宽度',
  '进度预览窗与进度条间距',
  '自动同步',
  '视频同步',
  '硬解模式',
  '自定义 mpv 启动参数',
  'mpv 日志详细等级',
  '显示上次 mpv 播放日志',
  'CDN 测速',
};

bool get advancedSettingsEnabled => GStorage.setting.get(
  SettingBoxKey.showAdvancedSettings,
  defaultValue: false,
);

enum SettingType {
  privacySetting('隐私设置'),
  recommendSetting('推荐流设置'),
  videoSetting('音视频设置'),
  playSetting('播放器设置'),
  styleSetting('外观设置'),
  extraSetting('其它设置'),
  webdavSetting('WebDAV 设置'),
  about('关于'),
  ;

  final String title;
  const SettingType(this.title);

  List<SettingsModel> get settings {
    final List<SettingsModel> settings = switch (this) {
      .privacySetting => privacySettings,
      .recommendSetting => recommendSettings,
      .videoSetting => videoSettings,
      .playSetting => _playSettingsWithHorizontalSeekAngle,
      .styleSetting => _styleSettingsWithHomeCardLayout,
      .extraSetting => extraSettings,
      _ => throw UnimplementedError(),
    };
    if (advancedSettingsEnabled) {
      return settings;
    }
    return settings
        .where(
          (item) => !_advancedSettingTitles.contains(item.effectiveTitle),
        )
        .toList(growable: false);
  }
}

List<SettingsModel> get _playSettingsWithHorizontalSeekAngle {
  final settings = <SettingsModel>[...playSettings];
  final triggerDistanceIndex = settings.indexWhere(
    (item) => item.title == '水平滑动快进/快退触发距离',
  );
  settings.insertAll(
    triggerDistanceIndex < 0 ? settings.length : triggerDistanceIndex + 1,
    horizontalSeekGestureSettings,
  );
  return settings;
}

List<SettingsModel> get _styleSettingsWithHomeCardLayout {
  final settings = <SettingsModel>[...styleSettings];
  final cardRadiusIndex = settings.indexWhere(
    (item) => item.title == '卡片圆角半径',
  );
  settings.insertAll(
    cardRadiusIndex < 0 ? settings.length : cardRadiusIndex + 1,
    homeCardLayoutSettings,
  );
  return settings;
}
