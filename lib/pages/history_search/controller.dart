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
  static const _localPageSize = 20;
  final _repository = HistoryArchiveRepository.instance;
  final Set<String> _cloudKeys = {};
  List<HistoryItemModel>? _localItems;
  int _localOffset = 0;
  bool _usingLocal = false;

  @override
  Future<LoadingState<HistoryData>> customGetData() async {
    if (_usingLocal) return Success(HistoryData(list: _nextLocalPage()));

    final result = await UserHttp.searchHistory(
      pn: page,
      keyword: editController.value.text,
      account: account,
    );
    if (result case Success(:final response)) {
      final cloudItems = response.list ?? const <HistoryItemModel>[];
      if (cloudItems.isNotEmpty) {
        _repository.markCloudItems(cloudItems);
        _cloudKeys.addAll(cloudItems.map(_repository.recordKeyForItem));
        return Success(response);
      }
      return Success(HistoryData(list: _beginLocalSupplement()));
    }

    final localPage = _beginLocalSupplement();
    if (localPage.isNotEmpty) return Success(HistoryData(list: localPage));
    _usingLocal = false;
    return result;
  }

  @override
  Future<void> onRefresh() {
    _cloudKeys.clear();
    _localItems = null;
    _localOffset = 0;
    _usingLocal = false;
    return super.onRefresh();
  }

  @override
  List<HistoryItemModel>? getDataList(HistoryData response) {
    return response.list;
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
    _localItems = _repository.localItems(
      keyword: editController.value.text,
      excludeKeys: _cloudKeys,
    );
    _localOffset = 0;
    return _nextLocalPage();
  }

  List<HistoryItemModel> _nextLocalPage() {
    final items = _localItems ?? const <HistoryItemModel>[];
    if (_localOffset >= items.length) return const [];
    final end = (_localOffset + _localPageSize)
        .clamp(0, items.length)
        .toInt();
    final localPage = items.sublist(_localOffset, end);
    _localOffset = end;
    isEnd = end >= items.length;
    return localPage;
  }
}
