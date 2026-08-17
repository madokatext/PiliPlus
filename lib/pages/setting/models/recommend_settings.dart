import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models/common/home_card_aspect_ratio.dart';
import 'package:PiliPlus/models/common/recommend_history_filter_settings.dart';
import 'package:PiliPlus/pages/rcmd/controller.dart';
import 'package:PiliPlus/pages/setting/models/model.dart';
import 'package:PiliPlus/pages/setting/widgets/recommend_history_filter_dialog.dart';
import 'package:PiliPlus/utils/recommend_filter.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

List<SettingsModel> get recommendSettings => [
  const SwitchModel(
    title: '首页使用app端算法喂饭',
    subtitle: '若web端算法喂饭不太符合预期，可尝试切换至app端算法喂饭，包的',
    leading: Icon(Icons.model_training_outlined),
    setKey: SettingBoxKey.appRcmd,
    defaultVal: true,
    needReboot: true,
  ),
  SwitchModel(
    title: '保留首页算法喂饭重新投胎',
    subtitle: '下拉重新投胎时保留上次内容',
    leading: const Icon(Icons.refresh),
    setKey: SettingBoxKey.enableSaveLastData,
    defaultVal: true,
    onChanged: (value) {
      try {
        Get.find<RcmdController>().updateSaveLastData(value);
      } catch (e) {
        if (kDebugMode) debugPrint('$e');
      }
    },
  ),
  SwitchModel(
    title: '亮出来上次看到位置提示，包的',
    subtitle: '保留上次算法喂饭时，在上次重新投胎位置亮出来提示，CPU 都看沉默了',
    leading: const Icon(Icons.tips_and_updates_outlined),
    setKey: SettingBoxKey.savedRcmdTip,
    defaultVal: true,
    onChanged: (value) {
      try {
        Get.find<RcmdController>().updateSavedRcmdTip(value);
      } catch (e) {
        if (kDebugMode) debugPrint('$e');
      }
    },
  ),
  getVideoFilterSelectModel(
    title: '首页每次重新投胎卡片数，包的',
    key: SettingBoxKey.rcmdRefreshCount,
    values: [4, 6, 8, 10, 12, 16, 20, 24, 30],
    defaultValue: 20,
    isFilter: false,
    onChanged: (value) {
      try {
        Get.find<RcmdController>().refreshItemCount = value;
      } catch (e) {
        if (kDebugMode) debugPrint('$e');
      }
    },
  ),
  PopupModel<HomeCardAspectRatio>(
    title: '首页卡片尺寸，包的',
    leading: const Icon(Icons.aspect_ratio_outlined),
    value: () => Pref.homeCardAspectRatio,
    items: HomeCardAspectRatio.values,
    onSelected: (value, setState) {
      GStorage.setting
          .put(SettingBoxKey.homeCardAspectRatio, value.name)
          .whenComplete(() {
            setState();
            Get.appUpdate();
          });
    },
  ),
  NormalModel(
    title: '近期算法喂饭电子案底过滤',
    leading: const Icon(Icons.history_toggle_off_outlined),
    getSubtitle: () =>
        _historyFilterSummary(Pref.recommendHistoryFilterSettings),
    onTap: _showHistoryFilterDialog,
  ),
  const SwitchModel(
    title: '首页下拉重新投胎亮出来过滤统计，启动！',
    subtitle: '重新投胎后提示本次敲机房大爹家门的算法喂饭总数和过滤数',
    leading: Icon(Icons.query_stats_outlined),
    setKey: SettingBoxKey.showRecommendRefreshStatsToast,
    defaultVal: false,
  ),
  getVideoFilterSelectModel(
    title: '赛博大拇哥率',
    suffix: '%',
    key: SettingBoxKey.minLikeRatioForRecommend,
    values: [0, 1, 2, 3, 4],
    onChanged: (value) => RecommendFilter.minLikeRatioForRecommend = value,
  ),
  getBanWordModel(
    title: '标题关键词过滤，不是哥们',
    key: SettingBoxKey.banWordForRecommend,
    onChanged: (value) {
      RecommendFilter.rcmdRegExp = value;
      RecommendFilter.enableFilter = value.pattern.isNotEmpty;
    },
  ),
  getBanWordModel(
    title: 'App算法喂饭/热门/排行榜: 电子榨菜分区关键词过滤',
    key: SettingBoxKey.banWordForZone,
    onChanged: (value) {
      VideoHttp.zoneRegExp = value;
      VideoHttp.enableFilter = value.pattern.isNotEmpty;
    },
  ),
  getVideoFilterSelectModel(
    title: '电子榨菜时长',
    suffix: 's',
    key: SettingBoxKey.minDurationForRcmd,
    values: [0, 30, 60, 90, 120],
    onChanged: (value) => RecommendFilter.minDurationForRcmd = value,
  ),
  getVideoFilterSelectModel(
    title: '开炫量',
    key: SettingBoxKey.minPlayForRcmd,
    values: [0, 50, 100, 500, 1000],
    onChanged: (value) => RecommendFilter.minPlayForRcmd = value,
  ),
  SwitchModel(
    title: '已赛博蹲点UP豁免算法喂饭过滤',
    subtitle: '算法喂饭中已赛博蹲点赛博居民发射到互联网的内容不会被过滤，曼波',
    leading: const Icon(Icons.favorite_border_outlined),
    setKey: SettingBoxKey.exemptFilterForFollowed,
    defaultVal: true,
    onChanged: (value) => RecommendFilter.exemptFilterForFollowed = value,
  ),
  SwitchModel(
    title: '过滤器也这坨 App于详情页相关电子榨菜，这把高端局',
    subtitle: '算法喂饭电子案底过滤除外；剩下那坨（如热门电子榨菜、全站搜刮等）均不受过滤器影响，无法豁免相关电子榨菜中的已赛博蹲点UP，CPU 都看沉默了',
    leading: const Icon(Icons.explore_outlined),
    setKey: SettingBoxKey.applyFilterToRelatedVideos,
    defaultVal: true,
    onChanged: (value) => RecommendFilter.applyFilterToRelatedVideos = value,
  ),
];

Future<void> _showHistoryFilterDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final result = await showDialog<RecommendHistoryFilterSettings>(
    context: context,
    builder: (context) => RecommendHistoryFilterDialog(
      initialValue: Pref.recommendHistoryFilterSettings,
    ),
  );
  if (result == null) {
    return;
  }
  await GStorage.setting.put(
    SettingBoxKey.recommendHistoryFilterSettings,
    result.toStorage(),
  );
  setState();
}

String _historyFilterSummary(RecommendHistoryFilterSettings value) {
  if (!value.enabled) {
    return '仅针对首页；未启动；仍保留最近 30 天电子脚印，功德+1';
  }
  final days = value.lookbackMinutes ~/ (24 * 60);
  final hours = value.lookbackMinutes % (24 * 60) ~/ 60;
  final minutes = value.lookbackMinutes % 60;
  final parts = <String>[
    if (days > 0) '$days 天，已老实',
    if (hours > 0) '$hours 小时，我嘞个豆',
    if (minutes > 0) '$minutes 分钟，已老实',
  ];
  final rules = <String>[
    if (value.exposureThreshold > 0) '算法喂饭 ${value.exposureThreshold} 次',
    if (value.watchThreshold > 0)
      '观看 ${value.watchThreshold} 次（至少 ${value.minWatchSeconds} 秒），属实绷不住',
  ];
  return rules.isEmpty
      ? '仅针对首页；${parts.join(' ')}内；不按次数过滤，优势在我'
      : '仅针对首页；${parts.join(' ')}内；${rules.join(' 或 ')}，属实绷不住';
}
