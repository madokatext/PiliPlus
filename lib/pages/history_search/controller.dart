import 'package:PiliPlus/common/widgets/dialog/dialog.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/user.dart';
import 'package:PiliPlus/models_new/history/data.dart';
import 'package:PiliPlus/models_new/history/list.dart';
import 'package:PiliPlus/pages/common/multi_select/base.dart';
import 'package:PiliPlus/pages/common/search/common_search_controller.dart';
import 'package:PiliPlus/services/history_archive_repository.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:flutter/widgets.dart' show Text;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

class HistorySearchController
    extends CommonSearchController<HistoryData, HistoryItemModel>
    with CommonMultiSelectMixin<HistoryItemModel>, DeleteItemMixin {
  final _repository = HistoryArchiveRepository.instance;
  final Set<String> _cloudKeys = {};
  List<HistoryItemModel>? _localItems;
  bool _usingLocal = false;
  bool _lastResponseWasLocal = false;

  @override
  Future<LoadingState<HistoryData>> customGetData() async {
    if (_usingLocal) return Success(HistoryData(list: const []));

    final result = await UserHttp.searchHistory(
      pn: page,
      keyword: editController.value.text,
      account: account,
    );
    if (result case Success(:final response)) {
      final cloudItems = response.list ?? const <HistoryItemModel>[];
      if (cloudItems.isNotEmpty) {
        _lastResponseWasLocal = false;
        _repository.markCloudItems(cloudItems);
        _cloudKeys.addAll(cloudItems.map(_repository.recordKeyForItem));
        return Success(response);
      }
      return Success(HistoryData(list: _beginLocalSupplement()));
    }

    final localItems = _beginLocalSupplement();
    if (localItems.isNotEmpty) return Success(HistoryData(list: localItems));
    _usingLocal = false;
    _lastResponseWasLocal = false;
    return result;
  }

  @override
  Future<void> onRefresh() {
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
    if (_lastResponseWasLocal) {
      isEnd = true;
      final localItems = response.response.list;
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
    }
    return false;
  }

  final account = Accounts.history;

  Future<void> onDelHistory(int index, HistoryItemModel item) async {
    LoadingState<void>? cloudResult;
    if (!item.localOnly) {
      cloudResult = await UserHttp.delHistory(
        '${item.history.business}_${item.kid}',
        account: account,
      );
    }
    if (cloudResult == null || cloudResult.isSuccess) {
      if (item.localOnly || item.hasLocalCopy) {
        await _repository.deleteItems([item]);
        _localItems?.remove(item);
      }
      loadingState
        ..value.data!.removeAt(index)
        ..refresh();
      SmartDialog.showToast('已删除');
    } else {
      cloudResult.toast();
    }
  }

  @override
  void onRemove() {
    showConfirmDialog(
      context: Get.context!,
      title: const Text('提示'),
      content: const Text('确认删除所选历史记录吗？'),
      onConfirm: () async {
        SmartDialog.showLoading(msg: '请求中');
        final removeList = allChecked.toSet();
        final cloudItems = removeList.where((item) => !item.localOnly).toSet();
        LoadingState<void>? cloudResult;
        if (cloudItems.isNotEmpty) {
          cloudResult = await UserHttp.delHistory(
            cloudItems
                .map((item) => '${item.history.business!}_${item.kid!}')
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
      },
    );
  }

  List<HistoryItemModel> _beginLocalSupplement() {
    _usingLocal = true;
    _lastResponseWasLocal = true;
    _localItems = _repository.localItems(
      keyword: editController.value.text,
      excludeKeys: _cloudKeys,
    );
    return _localItems!;
  }

  int _compareByViewAt(HistoryItemModel a, HistoryItemModel b) =>
      (b.viewAt ?? 0).compareTo(a.viewAt ?? 0);
}
