import 'package:PiliPlus/models_new/history/list.dart';
import 'package:PiliPlus/models_new/history/tab.dart';

class HistoryData {
  List<HistoryTab>? tab;
  List<HistoryItemModel>? list;
  int? cursorMax;
  int? cursorViewAt;

  HistoryData({this.tab, this.list, this.cursorMax, this.cursorViewAt});

  factory HistoryData.fromJson(Map<String, dynamic> json) => HistoryData(
    tab: (json['tab'] as List<dynamic>?)
        ?.map((e) => HistoryTab.fromJson(e as Map<String, dynamic>))
        .toList(),
    list: (json['list'] as List<dynamic>?)
        ?.map((e) => HistoryItemModel.fromJson(e as Map<String, dynamic>))
        .toList(),
    cursorMax: json['cursor'] is Map
        ? (json['cursor'] as Map)['max'] as int?
        : null,
    cursorViewAt: json['cursor'] is Map
        ? (json['cursor'] as Map)['view_at'] as int?
        : null,
  );
}
