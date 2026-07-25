import 'package:PiliPlus/models/model_owner.dart';
import 'package:PiliPlus/models/model_video.dart';

abstract class BaseRcmdVideoItemModel extends BaseVideoItemModel {
  String? goto;
  String? uri;
  String? rcmdReason;
  String? historyOccurrenceId;

  // app推荐专属
  int? param;
  String? pgcBadge;
}

class RcmdVideoItemModel extends BaseRcmdVideoItemModel {
  RcmdVideoItemModel.fromJson(Map<String, dynamic> json) {
    aid = json["id"];
    bvid = json["bvid"];
    cid = json["cid"];
    goto = json["goto"];
    uri = json["uri"];
    cover = json["pic"];
    title = json["title"];
    duration = json["duration"];
    pubdate = json["pubdate"];
    owner = Owner.fromJson(json["owner"]);
    stat = Stat.fromJson(json["stat"]);
    isFollowed = json["is_followed"] == 1;
    // rcmdReason = json["rcmd_reason"] != null
    //     ? RcmdReason.fromJson(json["rcmd_reason"])
    //     : RcmdReason(content: '');
    rcmdReason = json["rcmd_reason"]?['content'];
  }

  RcmdVideoItemModel.fromCacheJson(Map<String, dynamic> json) {
    aid = (json['aid'] as num?)?.toInt();
    bvid = json['bvid'] as String?;
    cid = (json['cid'] as num?)?.toInt();
    goto = json['goto'] as String?;
    uri = json['uri'] as String?;
    cover = json['cover'] as String?;
    title = json['title'] as String;
    duration = (json['duration'] as num).toInt();
    pubdate = (json['pubdate'] as num?)?.toInt();
    owner = Owner.fromJson(Map<String, dynamic>.from(json['owner'] as Map));
    final statJson = Map<String, dynamic>.from(json['stat'] as Map);
    stat = Stat.fromJson({
      'view': statJson['view'],
      'like': statJson['like'],
      'danmaku': statJson['danmu'],
    });
    isFollowed = json['isFollowed'] as bool;
    rcmdReason = json['rcmdReason'] as String?;
    historyOccurrenceId = json['historyOccurrenceId'] as String?;
  }

  Map<String, dynamic> toCacheJson() => {
    'aid': aid,
    'bvid': bvid,
    'cid': cid,
    'goto': goto,
    'uri': uri,
    'cover': cover,
    'title': title,
    'duration': duration,
    'pubdate': pubdate,
    'owner': {'mid': owner.mid, 'name': owner.name},
    'stat': {'view': stat.view, 'like': stat.like, 'danmu': stat.danmu},
    'isFollowed': isFollowed,
    'rcmdReason': rcmdReason,
    'historyOccurrenceId': historyOccurrenceId,
  };

  // @override
  // String? get desc => null;
}

// @HiveType(typeId: 2)
// class RcmdReason {
//   RcmdReason({
//     this.reasonType,
//     this.content,
//   });
// //   int? reasonType;
// //   String? content;
//
//   RcmdReason.fromJson(Map<String, dynamic> json) {
//     reasonType = json["reason_type"];
//     content = json["content"] ?? '';
//   }
// }
