import 'package:PiliPlus/models_new/video/video_ai_conclusion/ai_subtitle_part.dart';

class AiSubtitle {
  String? title;
  num? timestamp;
  List<AiSubtitlePart>? partSubtitle;

  AiSubtitle({
    this.title,
    this.timestamp,
    this.partSubtitle,
  });

  factory AiSubtitle.fromJson(Map<String, dynamic> json) => AiSubtitle(
    title: json['title'] as String?,
    timestamp: json['timestamp'] as num?,
    partSubtitle: (json['part_subtitle'] as List<dynamic>?)
        ?.map((e) => AiSubtitlePart.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
