import 'package:PiliPlus/models_new/video/video_ai_conclusion/ai_subtitle.dart';
import 'package:PiliPlus/models_new/video/video_ai_conclusion/ai_subtitle_part.dart';
import 'package:PiliPlus/models_new/video/video_ai_conclusion/outline.dart';

class AiConclusionResult {
  String? summary;
  List<Outline>? outline;
  List<AiSubtitle>? subtitle;
  String? fallbackSubtitle;

  AiConclusionResult({
    this.summary,
    this.outline,
    this.subtitle,
    this.fallbackSubtitle,
  });

  Iterable<AiSubtitlePart> get webSubtitleParts sync* {
    for (final group in subtitle ?? const <AiSubtitle>[]) {
      for (final part in group.partSubtitle ?? const <AiSubtitlePart>[]) {
        if (part.content?.trim().isNotEmpty == true) {
          yield part;
        }
      }
    }
  }

  bool get hasSubtitle =>
      webSubtitleParts.isNotEmpty ||
      fallbackSubtitle?.trim().isNotEmpty == true;

  factory AiConclusionResult.fromJson(Map<String, dynamic> json) =>
      AiConclusionResult(
        summary: json['summary'] as String?,
        outline: (json['outline'] as List<dynamic>?)
            ?.map((e) => Outline.fromJson(e as Map<String, dynamic>))
            .toList(),
        subtitle: (json['subtitle'] as List<dynamic>?)
            ?.map((e) => AiSubtitle.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
