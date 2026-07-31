import 'dart:async';
import 'dart:math' show max;

import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models/common/account_type.dart';
import 'package:PiliPlus/models/home/rcmd/cache.dart';
import 'package:PiliPlus/models/common/recommend_history_filter_settings.dart';
import 'package:PiliPlus/models/model_rec_video_item.dart';
import 'package:PiliPlus/pages/common/common_list_controller.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/playback_history_tracker.dart';
import 'package:PiliPlus/utils/recommend_history.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';

class RcmdController
    extends
        CommonListController<
          List<BaseRcmdVideoItemModel>,
          BaseRcmdVideoItemModel
        > {
  late bool enableSaveLastData = Pref.enableSaveLastData;
  final bool appRcmd = Pref.appRcmd;

  late int refreshItemCount = Pref.rcmdRefreshCount;

  int? lastRefreshAt;
  late bool savedRcmdTip = Pref.savedRcmdTip;

  /// 仅在手动刷新时为 true。
  bool _manualRefreshing = false;
  bool _showRefreshFilterStats = false;
  int _refreshRecommendationCount = 0;
  int _refreshFilteredCount = 0;

  /// App 推荐接口自己的 freshIdx。
  ///
  /// 不能直接完全依赖 CommonListController.page，因为一次手动刷新
  /// 可能需要连续请求多个 App 推荐批次。
  int _appFreshIdx = 0;

  bool _lastRequestSucceeded = false;
  bool _allowLoadMore = true;
  Future<void>? _activeQuery;
  bool _historyFillFailed = false;
  double _historyPassRate = 1.0;
  int _responseSerial = 0;

  @override
  bool get isEnd => false;

  @override
  void onInit() {
    super.onInit();
    page = 0;
    _appFreshIdx = 0;
    if (!Pref.refreshHomeOnRestart && _restoreCachedState()) {
      return;
    }
    queryData();
  }

  @override
  Future<LoadingState<List<BaseRcmdVideoItemModel>>> customGetData() async {
    _historyFillFailed = false;
    final historySettings = Pref.recommendHistoryFilterSettings;
    final LoadingState<List<BaseRcmdVideoItemModel>> result;
    if (historySettings.enabled) {
      await PlaybackHistoryTracker.instance.flush();
      result = await _getHistoryFilteredData(historySettings);
    } else if (!appRcmd) {
      result = await VideoHttp.rcmdVideoList(
        freshIdx: page,
        // 首次加载和触底加载仍保持原来的 20 项。
        ps: _manualRefreshing ? refreshItemCount : 20,
        onFilterStats: _recordFilterStats,
      );
      if (result case Success(:final response)) {
        _stampOccurrences(response, _nextResponseId());
      }
    } else if (_manualRefreshing) {
      result = await _getAppRefreshData();
    } else {
      result = await _getSingleAppData();
    }

    _lastRequestSucceeded = result is Success;
    return result;
  }

  /// App 模式普通加载：只请求一个批次。
  Future<LoadingState<List<BaseRcmdVideoItemModel>>> _getSingleAppData() async {
    final result = await VideoHttp.rcmdVideoListApp(
      freshIdx: _appFreshIdx,
      onFilterStats: _recordFilterStats,
    );

    if (result case Success(:final response)) {
      _stampOccurrences(response, _nextResponseId());
      _appFreshIdx++;
    }

    return result;
  }

  /// App 模式手动刷新：合并多个批次，直到达到设置数量。
  Future<LoadingState<List<BaseRcmdVideoItemModel>>>
  _getAppRefreshData() async {
    final List<BaseRcmdVideoItemModel> data = [];

    // 防止过滤条件过强时不断发起请求。
    const maxRequestCount = 4;
    var requestCount = 0;

    while (data.length < refreshItemCount && requestCount < maxRequestCount) {
      final result = await VideoHttp.rcmdVideoListApp(
        freshIdx: _appFreshIdx,
        onFilterStats: _recordFilterStats,
      );

      if (result case Success(:final response)) {
        requestCount++;
        _appFreshIdx++;

        if (response.isEmpty) {
          break;
        }

        _stampOccurrences(response, _nextResponseId());
        data.addAll(response);
      } else {
        // 第一次请求就失败时保留原始错误。
        if (data.isEmpty) {
          return result;
        }

        // 已经取得部分数据时，使用现有数据完成刷新。
        break;
      }
    }

    return Success(data.take(refreshItemCount).toList());
  }

  Future<LoadingState<List<BaseRcmdVideoItemModel>>> _getHistoryFilteredData(
    RecommendHistoryFilterSettings settings,
  ) async {
    final targetCount = _manualRefreshing ? refreshItemCount : 20;
    final oldItems = switch (loadingState.value) {
      Success(:final response?) when response.isNotEmpty => response,
      _ => null,
    };
    final preserveOldFeed = oldItems != null;
    final data = <BaseRcmdVideoItemModel>[];
    final existingIdentities = page > 0 && oldItems != null
        ? oldItems.map(_itemIdentity).toSet()
        : <Object>{};
    final responseSignatures = <String>{};
    var webCursor = page;
    var appCursor = _appFreshIdx;
    var requestCount = 0;

    const maxRequestCount = 6;
    while (data.length < targetCount && requestCount < maxRequestCount) {
      final remaining = targetCount - data.length;
      final LoadingState<List<BaseRcmdVideoItemModel>> result;
      if (appRcmd) {
        result = await VideoHttp.rcmdVideoListApp(
          freshIdx: appCursor,
          onFilterStats: _recordFilterStats,
        );
      } else {
        result = await VideoHttp.rcmdVideoList(
          freshIdx: webCursor,
          ps: _adaptiveRequestCount(remaining),
          onFilterStats: _recordFilterStats,
        );
      }

      if (result case Success(:final response)) {
        requestCount++;
        if (appRcmd) {
          appCursor++;
        } else {
          webCursor++;
        }
        if (response.isEmpty) {
          break;
        }

        final responseId = _nextResponseId();
        _stampOccurrences(response, responseId);
        final signature = response.map(_itemIdentity).join('|');
        if (!responseSignatures.add(signature)) {
          break;
        }

        final candidateKeys = response
            .map(recommendVideoKey)
            .whereType<String>()
            .toSet();
        Set<String> blocked;
        try {
          blocked = await RecommendHistoryRepository.instance.findBlockedVideos(
            scopeId: currentRecommendHistoryScope(),
            candidateVideoKeys: candidateKeys,
            settings: settings,
          );
        } catch (_) {
          // History failures must not blank or shorten the recommendation feed.
          blocked = const <String>{};
        }

        if (_showRefreshFilterStats && blocked.isNotEmpty) {
          _refreshFilteredCount += response.where((item) {
            final videoKey = recommendVideoKey(item);
            return videoKey != null && blocked.contains(videoKey);
          }).length;
        }

        for (final item in response) {
          final videoKey = recommendVideoKey(item);
          if (videoKey != null && blocked.contains(videoKey)) {
            continue;
          }
          if (page > 0 && !existingIdentities.add(_itemIdentity(item))) {
            continue;
          }
          data.add(item);
          if (data.length == targetCount) {
            break;
          }
        }

        if (candidateKeys.isNotEmpty) {
          final passRate =
              candidateKeys.difference(blocked).length / candidateKeys.length;
          _historyPassRate = _historyPassRate * 0.7 + passRate * 0.3;
        }
      } else {
        if (data.isEmpty) {
          return result;
        }
        break;
      }
    }

    if (data.length < targetCount && preserveOldFeed) {
      _historyFillFailed = true;
      return const Error('暂时没有足够的新推荐，请重试');
    }

    if (appRcmd) {
      _appFreshIdx = appCursor;
    } else {
      // CommonListController increments page after a successful response.
      page = max(0, webCursor - 1);
    }
    return Success(data.take(targetCount).toList());
  }

  int _adaptiveRequestCount(int remaining) {
    final passRate = max(_historyPassRate, 0.2);
    return ((remaining / passRate) * 1.1).ceil().clamp(remaining, 50);
  }

  String _nextResponseId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_responseSerial++}';

  void _stampOccurrences(
    List<BaseRcmdVideoItemModel> items,
    String responseId,
  ) {
    for (var index = 0; index < items.length; index++) {
      final videoKey = recommendVideoKey(items[index]);
      if (videoKey != null) {
        items[index].historyOccurrenceId = '$responseId:$index:$videoKey';
      }
    }
  }

  void recordExposure(BaseRcmdVideoItemModel item) {
    final occurrenceId = item.historyOccurrenceId;
    final videoKey = recommendVideoKey(item);
    if (occurrenceId == null || videoKey == null) {
      return;
    }
    unawaited(_recordExposure(occurrenceId, videoKey));
  }

  Future<void> _recordExposure(String occurrenceId, String videoKey) async {
    try {
      await RecommendHistoryRepository.instance.recordExposure(
        scopeId: currentRecommendHistoryScope(),
        occurrenceId: occurrenceId,
        videoKey: videoKey,
      );
    } catch (_) {
      // Exposure persistence is best-effort and must not interrupt scrolling.
    }
  }

  @override
  bool handleError(String? errMsg) {
    if (_historyFillFailed) {
      SmartDialog.showToast(errMsg ?? '暂时没有足够的新推荐，请重试');
      return true;
    }
    return enableSaveLastData;
  }

  @override
  Future<void> queryData([bool isRefresh = true]) {
    return _activeQuery ??= _queryData(isRefresh).whenComplete(() {
      _activeQuery = null;
    });
  }

  Future<void> _queryData(bool isRefresh) async {
    _lastRequestSucceeded = false;
    try {
      await super.queryData(isRefresh);
      if (_lastRequestSucceeded) {
        await _persistState();
      }
    } finally {
      // CommonListController 在 customGetData 抛出异常时不会复位此标记。
      isLoading = false;
    }
  }

  @override
  void handleListResponse(List<BaseRcmdVideoItemModel> dataList) {
    if (page > 0) {
      if (loadingState.value case Success(:final response?)) {
        final existingItems = response.map(_itemIdentity).toSet();
        dataList.removeWhere((item) => !existingItems.add(_itemIdentity(item)));
      }
    }

    if (enableSaveLastData && page == 0) {
      if (loadingState.value case Success(:final response)) {
        if (response != null && response.isNotEmpty) {
          if (savedRcmdTip) {
            // 标记被插入到本次新卡片之后。
            lastRefreshAt = dataList.length;
          }

          if (response.length > 200) {
            dataList.addAll(response.take(50));
          } else {
            dataList.addAll(response);
          }
        }
      }
    }
  }

  Object _itemIdentity(BaseRcmdVideoItemModel item) {
    if (item.bvid?.isNotEmpty == true) {
      return ('bvid', item.bvid);
    }
    final aid = item.aid;
    if (aid != null && aid > 0) {
      return ('aid', aid);
    }
    if (item.uri?.isNotEmpty == true) {
      return ('uri', item.uri);
    }
    return (item.goto, item.param, item.title, item.cover);
  }

  @override
  Future<void> onRefresh() => _refresh(showFilterStats: false);

  Future<void> onPullDownRefresh() => _refresh(showFilterStats: true);

  Future<void> refreshFromHistoryMarker() =>
      _refresh(showFilterStats: false);

  Future<void> _refresh({required bool showFilterStats}) async {
    if (_activeQuery case final activeQuery?) {
      try {
        await activeQuery;
      } catch (_) {}
    }

    final previousPage = page;
    final previousAppFreshIdx = _appFreshIdx;
    _showRefreshFilterStats =
        showFilterStats && Pref.showRecommendRefreshStatsToast;
    _refreshRecommendationCount = 0;
    _refreshFilteredCount = 0;
    _manualRefreshing = true;
    page = 0;
    _appFreshIdx = 0;
    isEnd = false;

    try {
      await queryData();
    } finally {
      final shouldShowStats =
          _lastRequestSucceeded && _showRefreshFilterStats;
      final recommendationCount = _refreshRecommendationCount;
      final filteredCount = _refreshFilteredCount;
      if (!_lastRequestSucceeded) {
        page = previousPage;
        _appFreshIdx = previousAppFreshIdx;
      }
      _manualRefreshing = false;
      _showRefreshFilterStats = false;
      if (shouldShowStats) {
        SmartDialog.showToast(
          '本次推荐：共 $recommendationCount 条，过滤 $filteredCount 条',
        );
      }
    }
  }

  void _recordFilterStats(int total, int filtered) {
    if (!_manualRefreshing || !_showRefreshFilterStats) {
      return;
    }
    _refreshRecommendationCount += total;
    _refreshFilteredCount += filtered;
  }

  void requestLoadMore(int index, int length) {
    if (_allowLoadMore && index == length - 1) {
      onLoadMore();
    }
  }

  void onUserScrollTowardEnd({required bool atEnd}) {
    _allowLoadMore = true;
    if (atEnd) {
      onLoadMore();
    }
  }

  void removeItemAt(int index) {
    if (loadingState.value case Success(:final response?)) {
      if (index < 0 || index >= response.length) {
        return;
      }
      if (lastRefreshAt != null && index < lastRefreshAt!) {
        lastRefreshAt = lastRefreshAt! - 1;
      }
      response.removeAt(index);
      loadingState.refresh();
      unawaited(_persistState());
    }
  }

  void updateSaveLastData(bool value) {
    enableSaveLastData = value;
    lastRefreshAt = null;
    unawaited(_persistState());
  }

  void updateSavedRcmdTip(bool value) {
    savedRcmdTip = value;
    lastRefreshAt = null;
    unawaited(_persistState());
  }

  bool _restoreCachedState() {
    final cached = GStorage.localCache.get(LocalCacheKey.rcmdHomeSnapshot);
    if (cached == null) {
      return false;
    }
    if (cached is! String) {
      unawaited(GStorage.localCache.delete(LocalCacheKey.rcmdHomeSnapshot));
      return false;
    }

    try {
      final snapshot = RcmdCacheSnapshot.decode(
        cached,
        expectedAppRcmd: appRcmd,
        expectedAccountMid: Accounts.get(AccountType.recommend).mid,
      );
      page = snapshot.webFreshIdx;
      _appFreshIdx = snapshot.appFreshIdx;
      lastRefreshAt = savedRcmdTip ? snapshot.lastRefreshAt : null;
      loadingState.value = Success(snapshot.items);
      for (var index = 0; index < snapshot.items.length; index++) {
        final item = snapshot.items[index];
        final videoKey = recommendVideoKey(item);
        if (item.historyOccurrenceId == null && videoKey != null) {
          item.historyOccurrenceId =
              'cache-${snapshot.lastRefreshAt ?? 0}:$index:$videoKey';
        }
      }
      _allowLoadMore = false;
      return true;
    } catch (_) {
      unawaited(GStorage.localCache.delete(LocalCacheKey.rcmdHomeSnapshot));
      return false;
    }
  }

  Future<void> _persistState() async {
    if (loadingState.value case Success(:final response?)) {
      try {
        final snapshot = RcmdCacheSnapshot(
          appRcmd: appRcmd,
          accountMid: Accounts.get(AccountType.recommend).mid,
          items: response,
          webFreshIdx: page,
          appFreshIdx: _appFreshIdx,
          lastRefreshAt: lastRefreshAt,
        );
        await GStorage.localCache.put(
          LocalCacheKey.rcmdHomeSnapshot,
          snapshot.encode(),
        );
      } catch (_) {
        // 缓存失败不应影响首页当前的联网、刷新与翻页逻辑。
      }
    }
  }
}
