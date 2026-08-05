import 'package:PiliPlus/models_new/video/video_stein_edgeinfo/edges.dart';
import 'package:PiliPlus/models_new/video/video_stein_edgeinfo/story_list.dart';

class EdgeInfoData {
  List<StoryList>? storyList;
  Edges? edges;

  EdgeInfoData({
    this.storyList,
    this.edges,
  });

  factory EdgeInfoData.fromJson(Map<String, dynamic> json) => EdgeInfoData(
    storyList: (json['story_list'] as List<dynamic>?)
        ?.map((e) => StoryList.fromJson(e as Map<String, dynamic>))
        .toList(),
    edges: json['edges'] == null
        ? null
        : Edges.fromJson(json['edges'] as Map<String, dynamic>),
  );
}
