import 'package:PiliPlus/common/widgets/dialog/dialog.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/view_sliver_safe_area.dart';
import 'package:PiliPlus/models/common/setting_type.dart';
import 'package:PiliPlus/pages/search/controller.dart' show DebounceStreamState;
import 'package:PiliPlus/pages/setting/models/model.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/waterfall.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waterfall_flow/waterfall_flow.dart'
    hide SliverWaterfallFlowDelegateWithMaxCrossAxisExtent;

class SettingsSearchPage extends StatefulWidget {
  const SettingsSearchPage({super.key});

  @override
  State<SettingsSearchPage> createState() => _SettingsSearchPageState();
}

class _SettingsSearchPageState
    extends DebounceStreamState<SettingsSearchPage, String> {
  static const _historyKey = 'settingsSearchHistory';
  static const _maxHistoryLength = 20;

  final _textEditingController = TextEditingController();
  final RxList<SettingsModel> _list = <SettingsModel>[].obs;
  final RxString _query = ''.obs;
  late final RxList<String> _history = List<String>.from(
    GStorage.historyWord.get(_historyKey) ?? const <String>[],
  ).obs;
  late final List<SettingsModel> _settings = [
    for (final type in const [
      SettingType.privacySetting,
      SettingType.recommendSetting,
      SettingType.videoSetting,
      SettingType.playSetting,
      SettingType.styleSetting,
      SettingType.extraSetting,
    ])
      ...type.settings,
  ];

  @override
  void onValueChanged(String value) {
    value = value.trim();
    _query.value = value;
    if (value.isEmpty) {
      _list.clear();
    } else {
      value = value.toLowerCase();
      _list.value = _settings
          .where(
            (item) =>
                item.effectiveTitle.toLowerCase().contains(value) ||
                item.effectiveSubtitle?.toLowerCase().contains(value) == true,
          )
          .toList();
    }
  }

  void _recordSearch([String? value]) {
    final keyword = (value ?? _textEditingController.text).trim();
    if (keyword.isEmpty) {
      return;
    }
    _history
      ..removeWhere((item) => item == keyword)
      ..insert(0, keyword);
    if (_history.length > _maxHistoryLength) {
      _history.removeRange(_maxHistoryLength, _history.length);
    }
    GStorage.historyWord.put(_historyKey, _history.toList());
  }

  void _searchHistory(String keyword) {
    _recordSearch(keyword);
    _textEditingController
      ..text = keyword
      ..selection = TextSelection.collapsed(offset: keyword.length);
    onValueChanged(keyword);
    ctr!.add(keyword);
  }

  void _removeHistory(String keyword) {
    _history.remove(keyword);
    if (_history.isEmpty) {
      GStorage.historyWord.delete(_historyKey);
    } else {
      GStorage.historyWord.put(_historyKey, _history.toList());
    }
  }

  void _clearHistory() {
    showConfirmDialog(
      context: context,
      title: const Text('确定清空设置搜索历史？'),
      onConfirm: () {
        _history.clear();
        GStorage.historyWord.delete(_historyKey);
      },
    );
  }

  void _clearQueryOrPop() {
    if (_textEditingController.text.isNotEmpty) {
      _textEditingController.clear();
      onValueChanged('');
      ctr!.add('');
    } else {
      Get.back();
    }
  }

  @override
  void dispose() {
    _textEditingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: _clearQueryOrPop,
            icon: const Icon(Icons.clear),
          ),
          const SizedBox(width: 10),
        ],
        title: TextField(
          autofocus: true,
          controller: _textEditingController,
          textAlignVertical: TextAlignVertical.center,
          onChanged: (value) {
            _recordSearch(value);
            ctr!.add(value);
          },
          decoration: const InputDecoration(
            isDense: true,
            hintText: '搜索',
            visualDensity: .standard,
            border: InputBorder.none,
          ),
        ),
      ),
      body: Obx(
        () => CustomScrollView(
          slivers: [
            ViewSliverSafeArea(
              sliver: _query.isEmpty
                  ? _buildHistory()
                  : _list.isEmpty
                  ? const HttpError(errMsg: '未找到相关设置')
                  : SliverWaterfallFlow(
                      gridDelegate:
                          SliverWaterfallFlowDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: Grid.smallCardWidth * 2,
                          ),
                      delegate: SliverChildBuilderDelegate(
                        (_, index) => _list[index].widget,
                        childCount: _list.length,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistory() {
    if (_history.isEmpty) {
      return const HttpError(errMsg: '暂无设置搜索历史');
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('搜索历史', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton.icon(
                  onPressed: _clearHistory,
                  icon: const Icon(Icons.clear_all_outlined, size: 18),
                  label: const Text('清空'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final keyword in _history)
                  InputChip(
                    label: Text(keyword),
                    onPressed: () => _searchHistory(keyword),
                    onDeleted: () => _removeHistory(keyword),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
