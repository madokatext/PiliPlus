import 'package:PiliPlus/models_new/video/video_stein_edgeinfo/choice.dart';

class Question {
  int? startTime;
  List<Choice>? choices;

  Question({
    this.startTime,
    this.choices,
  });

  factory Question.fromJson(Map<String, dynamic> json) => Question(
    startTime: (json['start_time'] as num?)?.toInt(),
    choices: (json['choices'] as List<dynamic>?)
        ?.map((e) => Choice.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
