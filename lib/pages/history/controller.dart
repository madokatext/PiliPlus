import 'package:PiliPlus/common/widgets/dialog/dialog.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/user.dart';
import 'package:PiliPlus/models_new/history/data.dart';
import 'package:PiliPlus/models_new/history/list.dart';
import 'package:PiliPlus/models_new/history/tab.dart';
import 'package:PiliPlus/pages/common/multi_select/multi_select_controller.dart';
import 'package:PiliPlus/pages/history/base_controller.dart';
import 'package:PiliPlus/services/history_archive_repository.dart';
import 'package:PiliPlus/utils/accounts/account.dart';
import 'package:PiliPlus/utils/extension/iterable_ext.dart';
import 'package:PiliPlus/utils/extension/scroll_controller_ext.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

class HistoryController
    extends MultiSelectController<HistoryData, HistoryItemModel>
    with GetSingleTickerProviderStateMixin {
  HistoryController(this.type);

  late final baseCtr = Get.put(HistoryBaseController());

  Account get account => baseCtr.account;

  final String? type;
  TabController? tabController;
  late RxList<HistoryTab> tabs = <HistoryTab>[].obs;

  int? max;
  int? viewAt;
  final _repository = HistoryArchiveRepository.instance;
  final Set<String> _cloudKeys = {};
  List<HistoryItemModel>? _localItems;
  bool _usingLocal = false;
  bool _lastResponseWasLocal = false;

  @override
  RxInt get rxCount => baseCtr.checkedCount;

  @override
  RxBool get enableMultiSelect => baseCtr.enableMultiSelect;

  @override
  void onInit() {
    super.onInit();
    historyStatus();
    queryData();
  }

  @override
  Future<void> onRefresh() {
    max = null;
    viewAt = null;
    _cloudKeys.clear();
    _localItems = null;
    _usingLocal = false;
    _lastResponseWasLocal = false;
    return super.onRefresh();
  }

  @override
  List<HistoryItemModel>? getDataList(HistoryData response) {
    return response.list;
  }

  @override
  bool customHandleResponse(bool isRefresh, Success<HistoryData> response) {
    HistoryData data = response.response;
    if (_lastResponseWasLocal) {
      isEnd = true;
      final localItems = data.list;
      final currentItems = loadingState.value.dataOrNull;
      if (!isRefresh &&
          localItems?.isNotEmpty == true &&
          currentItems != null) {
        currentItems
          ..addAll(localItems!)
          ..sort(_compareByViewAt);
        loadingState.refresh();
        return true;
      }
      return false;
    }
    isEnd = data.list.isNullOrEmpty;
    max = (data.cursorMax ?? 0) > 0
        ? data.cursorMax
        : data.list?.lastOrNull?.history.oid;
    viewAt = (data.cursorViewAt ?? 0) > 0
        ? data.cursorViewAt
        : data.list?.lastOrNull?.viewAt;

    if (isRefresh && type == null) {
      if (tabs.isEmpty && data.tab?.isNotEmpty == true) {
        tabs.value = data.tab!;
        tabController = TabController(
          length: data.tab!.length + 1,
          vsync: this,
        );
      }
    }

    return false;
  }

  // 观看历史暂停状态
  Future<void> historyStatus() async {
    final res = await UserHttp.historyStatus(account: account);
    if (res case Success(:final response)) {
      baseCtr.pauseStatus.value = response;
      await GStorage.localCache.putAll({
        LocalCacheKey.historyPause: response,
        LocalCacheKey.historyPauseAccountMid: account.mid,
      });
    } else {
      res.toast();
    }
  }

  // 删除某条历史记录
  void delHistory(HistoryItemModel item) {
    _onDelete({item});
  }

  // 删除已看历史记录
  void onDelViewedHistory() {
    final viewedList = loadingState.value.dataOrNull
        ?.where((e) => e.progress == -1)
        .toSet();
    if (viewedList != null && viewedList.isNotEmpty) {
      _onDelete(viewedList);
    } else {
      SmartDialog.showToast('无已看记录');
    }
  }

  Future<void> _onDelete(Set<HistoryItemModel> removeList) async {
    SmartDialog.showLoading(msg: '请求中');
    final cloudItems = removeList.where((item) => !item.localOnly).toSet();
    LoadingState<void>? cloudResult;
    if (cloudItems.isNotEmpty) {
      cloudResult = await UserHttp.delHistory(
        cloudItems
            .map((item) => '${item.history.business}_${item.kid}')
            .join(','),
        account: account,
      );
    }
    if (cloudResult == null || cloudResult.isSuccess) {
      await _repository.deleteItems(
        removeList.where((item) => item.localOnly || item.hasLocalCopy),
      );
      _localItems?.removeWhere(removeList.contains);
      await afterDelete(removeList);
      SmartDialog.dismiss();
      SmartDialog.showToast('已删除');
    } else {
      SmartDialog.dismiss();
      cloudResult.toast();
    }
  }

  // 删除选中的记录
  @override
  void onRemove() {
    showConfirmDialog(
      context: Get.context!,
      title: const Text('提示'),
      content: const Text('确认删除所选历史记录吗？'),
      onConfirm: () => _onDelete(allChecked.toSet()),
    );
  }

  @override
  Future<LoadingState<HistoryData>> customGetData() async {
    if (_usingLocal) return Success(HistoryData(list: const []));

    final cloudResult = await UserHttp.historyList(
      type: type ?? 'all',
      max: max,
      viewAt: viewAt,
      account: account,
    );
    if (cloudResult case Success(:final response)) {
      final cloudItems = response.list ?? const <HistoryItemModel>[];
      if (cloudItems.isNotEmpty) {
        _lastResponseWasLocal = false;
        _repository.markCloudItems(cloudItems);
        _cloudKeys.addAll(cloudItems.map(_repository.recordKeyForItem));
        return Success(response);
      }
      return Success(
        HistoryData(tab: response.tab, list: _beginLocalSupplement()),
      );
    }

    final localItems = _beginLocalSupplement();
    if (localItems.isNotEmpty) return Success(HistoryData(list: localItems));
    _usingLocal = false;
    _lastResponseWasLocal = false;
    return cloudResult;
  }

  List<HistoryItemModel> _beginLocalSupplement() {
    _usingLocal = true;
    _lastResponseWasLocal = true;
    _localItems = _repository.localItems(
      type: type,
      excludeKeys: _cloudKeys,
    );
    return _localItems!;
  }

  int _compareByViewAt(HistoryItemModel a, HistoryItemModel b) =>
      (b.viewAt ?? 0).compareTo(a.viewAt ?? 0);

  @override
  void onClose() {
    tabController?.dispose();
    super.onClose();
  }

  @override
  Future<void> onReload() {
    scrollController.jumpToTop();
    return super.onReload();
  }
}
