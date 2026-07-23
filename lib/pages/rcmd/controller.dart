import 'dart:async';

import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models/common/account_type.dart';
import 'package:PiliPlus/models/home/rcmd/cache.dart';
import 'package:PiliPlus/models/model_rec_video_item.dart';
import 'package:PiliPlus/pages/common/common_list_controller.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';

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

  /// 仅在下拉刷新或点击“上次看到这里”时为 true。
  bool _manualRefreshing = false;

  /// App 推荐接口自己的 freshIdx。
  ///
  /// 不能直接完全依赖 CommonListController.page，因为一次手动刷新
  /// 可能需要连续请求多个 App 推荐批次。
  int _appFreshIdx = 0;

  bool _lastRequestSucceeded = false;
  bool _allowLoadMore = true;
  Future<void>? _activeQuery;

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
    final LoadingState<List<BaseRcmdVideoItemModel>> result;
    if (!appRcmd) {
      result = await VideoHttp.rcmdVideoList(
        freshIdx: page,
        // 首次加载和触底加载仍保持原来的 20 项。
        ps: _manualRefreshing ? refreshItemCount : 20,
      );
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
    final result = await VideoHttp.rcmdVideoListApp(freshIdx: _appFreshIdx);

    if (result is Success) {
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
      final result = await VideoHttp.rcmdVideoListApp(freshIdx: _appFreshIdx);

      if (result case Success(:final response)) {
        requestCount++;
        _appFreshIdx++;

        if (response.isEmpty) {
          break;
        }

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

  @override
  bool handleError(String? errMsg) {
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
  Future<void> onRefresh() async {
    if (_activeQuery case final activeQuery?) {
      try {
        await activeQuery;
      } catch (_) {}
    }

    final previousPage = page;
    final previousAppFreshIdx = _appFreshIdx;
    _manualRefreshing = true;
    page = 0;
    _appFreshIdx = 0;
    isEnd = false;

    try {
      await queryData();
    } finally {
      if (!_lastRequestSucceeded) {
        page = previousPage;
        _appFreshIdx = previousAppFreshIdx;
      }
      _manualRefreshing = false;
    }
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
