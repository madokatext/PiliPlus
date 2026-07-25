import 'package:PiliPlus/http/video.dart';
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
    title: '首页使用app端推荐',
    subtitle: '若web端推荐不太符合预期，可尝试切换至app端推荐',
    leading: Icon(Icons.model_training_outlined),
    setKey: SettingBoxKey.appRcmd,
    defaultVal: true,
    needReboot: true,
  ),
  SwitchModel(
    title: '保留首页推荐刷新',
    subtitle: '下拉刷新时保留上次内容',
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
    title: '显示上次看到位置提示',
    subtitle: '保留上次推荐时，在上次刷新位置显示提示',
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
  title: '首页每次刷新卡片数',
  key: SettingBoxKey.rcmdRefreshCount,
  values: [4, 6, 8, 10, 12, 16, 20, 24, 30],
  defaultValue: 20,
  isFilter: false,
  onChanged: (value) {
    try {
      Get.find<RcmdController>().refreshItemCount = value;
    } catch (e) {
      if (kDebugMode) debugPrint('$e');
    },
  },
),
  NormalModel(
    title: '近期推荐历史过滤',
    leading: const Icon(Icons.history_toggle_off_outlined),
    getSubtitle: () =>
        _historyFilterSummary(Pref.recommendHistoryFilterSettings),
    onTap: _showHistoryFilterDialog,
  ),
  getVideoFilterSelectModel(
    title: '点赞率',
    suffix: '%',
    key: SettingBoxKey.minLikeRatioForRecommend,
    values: [0, 1, 2, 3, 4],
    onChanged: (value) => RecommendFilter.minLikeRatioForRecommend = value,
  ),
  getBanWordModel(
    title: '标题关键词过滤',
    key: SettingBoxKey.banWordForRecommend,
    onChanged: (value) {
      RecommendFilter.rcmdRegExp = value;
      RecommendFilter.enableFilter = value.pattern.isNotEmpty;
    },
  ),
  getBanWordModel(
    title: 'App推荐/热门/排行榜: 视频分区关键词过滤',
    key: SettingBoxKey.banWordForZone,
    onChanged: (value) {
      VideoHttp.zoneRegExp = value;
      VideoHttp.enableFilter = value.pattern.isNotEmpty;
    },
  ),
  getVideoFilterSelectModel(
    title: '视频时长',
    suffix: 's',
    key: SettingBoxKey.minDurationForRcmd,
    values: [0, 30, 60, 90, 120],
    onChanged: (value) => RecommendFilter.minDurationForRcmd = value,
  ),
  getVideoFilterSelectModel(
    title: '播放量',
    key: SettingBoxKey.minPlayForRcmd,
    values: [0, 50, 100, 500, 1000],
    onChanged: (value) => RecommendFilter.minPlayForRcmd = value,
  ),
  SwitchModel(
    title: '已关注UP豁免推荐过滤',
    subtitle: '推荐中已关注用户发布的内容不会被过滤',
    leading: const Icon(Icons.favorite_border_outlined),
    setKey: SettingBoxKey.exemptFilterForFollowed,
    defaultVal: true,
    onChanged: (value) => RecommendFilter.exemptFilterForFollowed = value,
  ),
  SwitchModel(
    title: '过滤器也应用于详情页相关视频',
    subtitle: '其它（如热门视频、搜索等）均不受过滤器影响，无法豁免相关视频中的已关注UP',
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
    return '未开启；仍保留最近 30 天记录';
  }
  final days = value.lookbackMinutes ~/ (24 * 60);
  final hours = value.lookbackMinutes % (24 * 60) ~/ 60;
  final minutes = value.lookbackMinutes % 60;
  final parts = <String>[
    if (days > 0) '$days 天',
    if (hours > 0) '$hours 小时',
    if (minutes > 0) '$minutes 分钟',
  ];
  return '${parts.join(' ')}内；推荐 ${value.exposureThreshold} 次或观看 '
      '${value.watchThreshold} 次（至少 ${value.minWatchSeconds} 秒）';
}
