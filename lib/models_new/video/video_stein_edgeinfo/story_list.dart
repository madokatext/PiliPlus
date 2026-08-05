import 'package:PiliPlus/models_new/video/video_detail/episode.dart';

class StoryList extends BaseEpisodeItem {
  int? nodeId;
  int? edgeId;
  int? startPos;
  int? isCurrent;
  int? cursor;

  StoryList({
    this.nodeId,
    this.edgeId,
    super.title,
    super.cid,
    this.startPos,
    super.cover,
    this.isCurrent,
    this.cursor,
  });

  factory StoryList.fromJson(Map<String, dynamic> json) => StoryList(
    nodeId: json['node_id'] as int?,
    edgeId: json['edge_id'] as int?,
    title: json['title'] as String?,
    cid: json['cid'] as int?,
    startPos: json['start_pos'] as int?,
    cover: json['cover'] as String?,
    isCurrent: json['is_current'] as int?,
    cursor: json['cursor'] as int?,
  );
}
