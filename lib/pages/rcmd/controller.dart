import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/pages/common/common_list_controller.dart';
import 'package:PiliPlus/utils/storage_pref.dart';

class RcmdController extends CommonListController {
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

  @override
  bool get isEnd => false;

  @override
  void onInit() {
    super.onInit();
    page = 0;
    _appFreshIdx = 0;
    queryData();
  }

  @override
  Future<LoadingState> customGetData() {
    if (!appRcmd) {
      return VideoHttp.rcmdVideoList(
        freshIdx: page,
        // 首次加载和触底加载仍保持原来的 20 项。
        ps: _manualRefreshing ? refreshItemCount : 20,
      );
    }

    if (_manualRefreshing) {
      return _getAppRefreshData();
    }

    return _getSingleAppData();
  }

  /// App 模式普通加载：只请求一个批次。
  Future<LoadingState> _getSingleAppData() async {
    final result = await VideoHttp.rcmdVideoListApp(
      freshIdx: _appFreshIdx,
    );

    if (result is Success) {
      _appFreshIdx++;
    }

    return result;
  }

  /// App 模式手动刷新：合并多个批次，直到达到设置数量。
  Future<LoadingState> _getAppRefreshData() async {
    final List data = [];

    // 防止过滤条件过强时不断发起请求。
    const maxRequestCount = 4;
    var requestCount = 0;

    while (data.length < refreshItemCount &&
        requestCount < maxRequestCount) {
      final result = await VideoHttp.rcmdVideoListApp(
        freshIdx: _appFreshIdx,
      );

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

    return Success(
      data.take(refreshItemCount).toList(),
    );
  }

  @override
  bool handleError(String? errMsg) {
    return enableSaveLastData;
  }

  @override
  void handleListResponse(List dataList) {
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

  @override
  Future<void> onRefresh() async {
    _manualRefreshing = true;
    page = 0;
    _appFreshIdx = 0;
    isEnd = false;

    try {
      await queryData();
    } finally {
      _manualRefreshing = false;
    }
  }
}
