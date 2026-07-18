import 'dart:async' show unawaited;
import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models/common/account_type.dart';
import 'package:PiliPlus/models/home/rcmd/result.dart';
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
  static const int _cacheVersion = 1;

  late bool enableSaveLastData = Pref.enableSaveLastData;
  final bool appRcmd = Pref.appRcmd;

  int? lastRefreshAt;
  late bool savedRcmdTip = Pref.savedRcmdTip;
  bool _restoredFromCache = false;
  bool _isPullRefresh = false;

  @override
  bool get isEnd => false;

  @override
  void onInit() {
    super.onInit();
    page = 0;
    if (!enableSaveLastData || !_restoreCache()) {
      queryData();
    }
  }

  @override
  Future<LoadingState<List<BaseRcmdVideoItemModel>>> customGetData() {
    return appRcmd
        ? VideoHttp.rcmdVideoListApp(
            freshIdx: page,
            pull: _isPullRefresh || page == 0,
          )
        : VideoHttp.rcmdVideoList(freshIdx: page, ps: 20);
  }

  @override
  bool handleError(String? errMsg) {
    return enableSaveLastData && loadingState.value is Success;
  }

  @override
  void handleListResponse(List<BaseRcmdVideoItemModel> dataList) {
    if (enableSaveLastData && _isPullRefresh) {
      if (loadingState.value case Success(:final response)) {
        if (response != null && response.isNotEmpty) {
          if (savedRcmdTip) {
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
    if (enableSaveLastData) {
      // CommonListController updates loadingState and page after this callback.
      unawaited(Future<void>.microtask(_saveCache));
    }
  }

  @override
  Future<void> onRefresh() async {
    _isPullRefresh = true;
    // The first request after restoring cache must continue from the saved
    // fresh index. Requesting index 0 again can return the cached batch itself.
    if (!_restoredFromCache) {
      page = 0;
    }
    _restoredFromCache = false;
    isEnd = false;
    try {
      await queryData();
    } finally {
      _isPullRefresh = false;
    }
  }

  void removeAt(int index) {
    if (loadingState.value case Success(:final response?)) {
      if (index < 0 || index >= response.length) return;
      if (lastRefreshAt != null && index < lastRefreshAt!) {
        lastRefreshAt = lastRefreshAt! - 1;
      }
      response.removeAt(index);
      loadingState.refresh();
      if (enableSaveLastData) {
        unawaited(_saveCache());
      }
    }
  }

  void updateSaveLastData(bool value) {
    enableSaveLastData = value;
    lastRefreshAt = null;
    if (value) {
      unawaited(_saveCache());
    } else {
      unawaited(GStorage.localCache.delete(LocalCacheKey.homeRcmdCache));
    }
  }

  void updateSavedRcmdTip(bool value) {
    savedRcmdTip = value;
    lastRefreshAt = null;
    if (enableSaveLastData) {
      unawaited(_saveCache());
    }
  }

  int get _recommendMid => Accounts.get(AccountType.recommend).mid;

  bool _restoreCache() {
    final rawCache = GStorage.localCache.get(LocalCacheKey.homeRcmdCache);
    if (rawCache is! String) return false;

    try {
      final decoded = jsonDecode(rawCache);
      if (decoded is! Map) return false;
      final cache = Map<String, dynamic>.from(decoded);
      if (cache['version'] != _cacheVersion ||
          cache['appRcmd'] != appRcmd ||
          cache['mid'] != _recommendMid) {
        return false;
      }

      final rawItems = cache['items'];
      if (rawItems is! List || rawItems.isEmpty) return false;
      final items = <BaseRcmdVideoItemModel>[];
      for (final rawItem in rawItems) {
        if (rawItem is Map) {
          try {
            items.add(_itemFromJson(Map<String, dynamic>.from(rawItem)));
          } catch (_) {}
        }
      }
      if (items.isEmpty) return false;

      final savedPage = (cache['page'] as num?)?.toInt() ?? 1;
      page = savedPage < 1 ? 1 : savedPage;
      final marker = (cache['lastRefreshAt'] as num?)?.toInt();
      lastRefreshAt = marker != null && marker >= 0 && marker <= items.length
          ? marker
          : null;
      loadingState.value = Success(items);
      _restoredFromCache = true;
      return true;
    } catch (_) {
      unawaited(GStorage.localCache.delete(LocalCacheKey.homeRcmdCache));
      return false;
    }
  }

  Future<void> _saveCache() async {
    if (loadingState.value case Success(:final response?)) {
      if (response.isEmpty) {
        await GStorage.localCache.delete(LocalCacheKey.homeRcmdCache);
        return;
      }
      await GStorage.localCache.put(
        LocalCacheKey.homeRcmdCache,
        jsonEncode({
          'version': _cacheVersion,
          'appRcmd': appRcmd,
          'mid': _recommendMid,
          'page': page,
          'lastRefreshAt': lastRefreshAt,
          'items': response.map(_itemToJson).toList(),
        }),
      );
    }
  }

  static Map<String, dynamic> _itemToJson(BaseRcmdVideoItemModel item) {
    return {
      'source': item is RcmdVideoItemAppModel ? 'app' : 'web',
      'aid': item.aid,
      'bvid': item.bvid,
      'cid': item.cid,
      'goto': item.goto,
      'uri': item.uri,
      'cover': item.cover,
      'title': item.title,
      'duration': item.duration,
      'pubdate': item.pubdate,
      'desc': item.desc,
      'isFollowed': item.isFollowed,
      'rcmdReason': item.rcmdReason,
      'param': item.param,
      'pgcBadge': item.pgcBadge,
      'ownerMid': item.owner.mid,
      'ownerName': item.owner.name,
      'statView': item.stat.view,
      'statLike': item.stat.like,
      'statDanmu': item.stat.danmu,
      if (item case final RcmdVideoItemAppModel appItem) ...{
        'talkBack': appItem.talkBack,
        'cardType': appItem.cardType,
        'threePoint': _threePointToJson(appItem.threePoint),
      },
    };
  }

  static List<Map<String, dynamic>>? _threePointToJson(ThreePoint? value) {
    if (value == null) return null;
    return [
      if (value.dislikeReasons case final reasons?)
        {
          'type': 'dislike',
          'reasons': reasons.map(_reasonToJson).toList(),
        },
      if (value.feedbacks case final reasons?)
        {
          'type': 'feedback',
          'reasons': reasons.map(_reasonToJson).toList(),
        },
    ];
  }

  static Map<String, dynamic> _reasonToJson(Reason value) => {
    'id': value.id,
    'name': value.name,
    'toast': value.toast,
  };

  static BaseRcmdVideoItemModel _itemFromJson(Map<String, dynamic> json) {
    if (json['source'] == 'app') {
      return RcmdVideoItemAppModel.fromJson({
        'player_args': {
          'aid': json['aid'],
          'cid': json['cid'],
          'duration': json['duration'],
        },
        'bvid': json['bvid'],
        'cover': json['cover'],
        'cover_left_text_1': '${json['statView'] ?? 0}',
        'cover_left_text_2': '${json['statDanmu'] ?? 0}',
        'title': json['title'],
        'goto': json['goto'],
        'param': '${json['param'] ?? json['aid'] ?? 0}',
        'uri': json['uri'],
        'talk_back': json['talkBack'],
        'rcmd_reason': json['isFollowed'] == true
            ? '已关注'
            : json['rcmdReason'],
        'cover_right_text': json['pgcBadge'],
        'card_type': json['cardType'],
        'three_point_v2': json['threePoint'],
        'desc': json['desc'],
        'args': {
          'up_id': json['ownerMid'],
          'up_name': json['ownerName'],
        },
        'desc_button': {'text': json['ownerName']},
      });
    }

    return RcmdVideoItemModel.fromJson({
      'id': json['aid'],
      'bvid': json['bvid'],
      'cid': json['cid'],
      'goto': json['goto'],
      'uri': json['uri'],
      'pic': json['cover'],
      'title': json['title'],
      'duration': json['duration'],
      'pubdate': json['pubdate'],
      'owner': {
        'mid': json['ownerMid'],
        'name': json['ownerName'],
      },
      'stat': {
        'view': json['statView'],
        'like': json['statLike'],
        'danmaku': json['statDanmu'],
      },
      'is_followed': json['isFollowed'] == true ? 1 : 0,
      'rcmd_reason': json['rcmdReason'] == null
          ? null
          : {'content': json['rcmdReason']},
    });
  }
}
