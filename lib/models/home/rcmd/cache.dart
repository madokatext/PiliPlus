import 'dart:convert';

import 'package:PiliPlus/models/home/rcmd/result.dart';
import 'package:PiliPlus/models/model_rec_video_item.dart';

class RcmdCacheSnapshot {
  static const int currentVersion = 1;

  final bool appRcmd;
  final int accountMid;
  final List<BaseRcmdVideoItemModel> items;
  final int webFreshIdx;
  final int appFreshIdx;
  final int? lastRefreshAt;

  const RcmdCacheSnapshot({
    required this.appRcmd,
    required this.accountMid,
    required this.items,
    required this.webFreshIdx,
    required this.appFreshIdx,
    required this.lastRefreshAt,
  });

  String encode() => jsonEncode({
    'version': currentVersion,
    'appRcmd': appRcmd,
    'accountMid': accountMid,
    'webFreshIdx': webFreshIdx,
    'appFreshIdx': appFreshIdx,
    'lastRefreshAt': lastRefreshAt,
    'items': items
        .map(
          (item) => switch (item) {
            RcmdVideoItemAppModel appItem => appItem.toCacheJson(),
            RcmdVideoItemModel webItem => webItem.toCacheJson(),
            _ => throw const FormatException('不支持的首页算法喂饭卡片类型，CPU 都看沉默了'),
          },
        )
        .toList(),
  });

  factory RcmdCacheSnapshot.decode(
    String source, {
    required bool expectedAppRcmd,
    required int expectedAccountMid,
  }) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('首页算法喂饭电子囤货不是对象');
    }
    final json = Map<String, dynamic>.from(decoded);

    if (json['version'] != currentVersion ||
        json['appRcmd'] != expectedAppRcmd ||
        json['accountMid'] != expectedAccountMid) {
      throw const FormatException('首页算法喂饭电子囤货不兼容');
    }

    final webFreshIdx = _readNonNegativeInt(json['webFreshIdx'], 'webFreshIdx');
    final appFreshIdx = _readNonNegativeInt(json['appFreshIdx'], 'appFreshIdx');
    final rawItems = json['items'];
    if (rawItems is! List) {
      throw const FormatException('首页算法喂饭电子囤货缺少卡片列表，曼波');
    }

    final items = rawItems
        .map<BaseRcmdVideoItemModel>((item) {
          if (item is! Map) {
            throw const FormatException('首页算法喂饭电子囤货包含无效卡片');
          }
          final itemJson = Map<String, dynamic>.from(item);
          return expectedAppRcmd
              ? RcmdVideoItemAppModel.fromCacheJson(itemJson)
              : RcmdVideoItemModel.fromCacheJson(itemJson);
        })
        .toList(growable: true);

    final rawLastRefreshAt = json['lastRefreshAt'];
    final int? lastRefreshAt = rawLastRefreshAt == null
        ? null
        : _readNonNegativeInt(rawLastRefreshAt, 'lastRefreshAt');
    if (lastRefreshAt != null && lastRefreshAt > items.length) {
      throw const FormatException('首页算法喂饭电子囤货提示位置越界');
    }

    return RcmdCacheSnapshot(
      appRcmd: expectedAppRcmd,
      accountMid: expectedAccountMid,
      items: items,
      webFreshIdx: webFreshIdx,
      appFreshIdx: appFreshIdx,
      lastRefreshAt: lastRefreshAt,
    );
  }

  static int _readNonNegativeInt(Object? value, String name) {
    if (value is! num || value.toInt() != value || value < 0) {
      throw FormatException('首页算法喂饭电子囤货的 $name 无效，我嘞个豆');
    }
    return value.toInt();
  }
}
