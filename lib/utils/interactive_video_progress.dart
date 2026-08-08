import 'package:PiliPlus/models_new/video/video_stein_edgeinfo/story_list.dart';
import 'package:PiliPlus/utils/storage.dart';

class InteractiveVideoProgress {
  const InteractiveVideoProgress({
    required this.entries,
    required this.currentIndex,
  });

  final List<InteractiveVideoProgressEntry> entries;
  final int currentIndex;

  InteractiveVideoProgressEntry get currentEntry => entries[currentIndex];

  String get cardLabel {
    final title = currentEntry.title?.trim();
    final displayTitle = title == null || title.isEmpty ? '未命名章节' : title;
    return '第${currentIndex + 1}章 · $displayTitle';
  }

  StoryList get current => currentEntry.toStory(
    cursor: currentIndex,
    isCurrent: true,
  );

  List<StoryList> toStoryList() => [
    for (final (index, entry) in entries.indexed)
      entry.toStory(
        cursor: index,
        isCurrent: index == currentIndex,
      ),
  ];

  Map<String, Object> toJson() => {
    'version': 1,
    'currentIndex': currentIndex,
    'entries': entries.map((entry) => entry.toJson()).toList(),
  };

  static InteractiveVideoProgress? fromJson(Object? value) {
    if (value is! Map || value['version'] != 1) return null;
    final rawEntries = value['entries'];
    final rawCurrentIndex = value['currentIndex'];
    if (rawEntries is! List || rawCurrentIndex is! int) return null;

    final entries = rawEntries
        .map(InteractiveVideoProgressEntry.fromJson)
        .whereType<InteractiveVideoProgressEntry>()
        .toList(growable: false);
    if (entries.isEmpty ||
        rawCurrentIndex < 0 ||
        rawCurrentIndex >= entries.length) {
      return null;
    }
    return InteractiveVideoProgress(
      entries: entries,
      currentIndex: rawCurrentIndex,
    );
  }
}

class InteractiveVideoProgressEntry {
  const InteractiveVideoProgressEntry({
    required this.edgeId,
    required this.cid,
    this.title,
  });

  final int edgeId;
  final int cid;
  final String? title;

  StoryList toStory({required int cursor, required bool isCurrent}) =>
      StoryList(
        edgeId: edgeId,
        cid: cid,
        title: title,
        cursor: cursor,
        isCurrent: isCurrent ? 1 : 0,
      );

  Map<String, Object> toJson() => {
    'edgeId': edgeId,
    'cid': cid,
    if (title != null) 'title': title!,
  };

  static InteractiveVideoProgressEntry? fromJson(Object? value) {
    if (value is! Map) return null;
    final edgeId = value['edgeId'];
    final cid = value['cid'];
    final title = value['title'];
    if (edgeId is! int || cid is! int || cid == 0) return null;
    return InteractiveVideoProgressEntry(
      edgeId: edgeId,
      cid: cid,
      title: title is String && title.isNotEmpty ? title : null,
    );
  }
}

abstract final class InteractiveVideoProgressRepository {
  static InteractiveVideoProgress? get(String bvid) =>
      InteractiveVideoProgress.fromJson(
        GStorage.interactiveVideoProgress.get(bvid),
      );

  static Future<void> put(
    String bvid,
    InteractiveVideoProgress progress,
  ) => GStorage.interactiveVideoProgress.put(bvid, progress.toJson());
}
