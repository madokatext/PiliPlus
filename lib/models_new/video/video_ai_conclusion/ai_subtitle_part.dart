class AiSubtitlePart {
  String? content;
  num? startTimestamp;
  num? endTimestamp;

  AiSubtitlePart({
    this.content,
    this.startTimestamp,
    this.endTimestamp,
  });

  factory AiSubtitlePart.fromJson(Map<String, dynamic> json) =>
      AiSubtitlePart(
        content: json['content'] as String?,
        startTimestamp: json['start_timestamp'] as num?,
        endTimestamp: json['end_timestamp'] as num?,
      );
}
