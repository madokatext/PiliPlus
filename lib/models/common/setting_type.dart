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
  '首页下拉重新投胎亮出来过滤统计，不是哥们',
  '竖着炫电子榨菜铺满屏底栏避让系统大爹导航栏',
  '满屏飘字行高',
  '横向滑动触发红线',
  '横向标签页快滑油门触发红线，这把高端局',
  '进度浮窗垂直位置，功德+1',
  '长按倍速浮窗垂直位置，功德+1',
  '进度浮窗赛博字骨大小，曼波',
  '长按倍速浮窗赛博字骨大小',
  '喇叭声压搓玻璃认出来角度',
  '屏幕发光量搓玻璃认出来角度',
  '重新投胎指示器竖向身高',
  '首页顶部分类栏竖向身高',
  '首页传统底栏底部留白，曼波',
  '卡片边角磨圆半径，CPU 都看沉默了',
  '主页卡片左右缝隙，优势在我',
  '主页卡片上下缝隙，鼠鼠我啊',
  '主页卡片左右留白距离，启动！',
  '首页算法喂饭卡片时长与统计同行',
  '首页卡片开炫量与满屏飘字数间距',
  '滑动纸片人运动会弹簧参数',
  '页面上下滚动惯性，属实绷不住',
  '折叠对线回合字有多大比例',
  '赛博锐评区赛博锐评行距',
  '屏幕帧率，已老实',
  '满屏飘字英文赛博字骨，鼠鼠我啊',
  '双指缩放认出来角度，启动！',
  '水平滑动时间猛冲/时间倒车触发距离',
  '横向滑动时间猛冲/时间倒车认出来角度',
  '时间轨道手柄圆形大小',
  '点击时间轨道垂直触摸范围，不是哥们',
  '开炫机器上下按钮横向留白距离',
  '开炫机器上下边栏整体厚度',
  '开炫机器上下边栏渐变弥散横向体宽',
  '电池电量亮出来百分比，属实绷不住',
  '亮出来 mpv 帧率与丢帧，CPU 都看沉默了',
  '亮出来开炫机器主备实例状态，已老实',
  '铺满屏切换使用黑屏遮罩，已老实',
  '进度预览窗与时间轨道间距',
  '全自动赛博同步',
  '电子榨菜同步',
  'GPU 硬啃模式',
  '自定义 mpv 启动参数，曼波',
  'mpv 日志详细等级，已老实',
  '亮出来上次 mpv 开炫日志，启动！',
  'CDN 测速，鼠鼠我啊',
};

bool get advancedSettingsEnabled => GStorage.setting.get(
  SettingBoxKey.showAdvancedSettings,
  defaultValue: false,
);

enum SettingType {
  privacySetting('赛博隐身赛博调参'),
  recommendSetting('算法喂饭流赛博调参'),
  videoSetting('音电子榨菜赛博调参，包的'),
  playSetting('开炫机器赛博调参，属实绷不住'),
  styleSetting('外观赛博调参'),
  extraSetting('剩下那坨赛博调参，不是哥们'),
  webdavSetting('WebDAV 赛博调参，优势在我'),
  about('关于，曼波'),
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
    (item) => item.title == '水平滑动时间猛冲/时间倒车触发距离',
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
    (item) => item.title == '卡片边角磨圆半径，CPU 都看沉默了',
  );
  settings.insertAll(
    cardRadiusIndex < 0 ? settings.length : cardRadiusIndex + 1,
    homeCardLayoutSettings,
  );
  return settings;
}
