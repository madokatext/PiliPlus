import 'package:PiliPlus/utils/path_utils.dart';
import 'package:path/path.dart' as path;

sealed class DataSource {
  final String videoSource;
  final String? audioSource;

  DataSource({
    required this.videoSource,
    required this.audioSource,
  });
}

class NetworkSource extends DataSource {
  final List<String> cdnVideoSources;
  final List<String?> cdnAudioSources;
  final int cdnIndex;

  NetworkSource({
    required String videoSource,
    required String? audioSource,
    List<String>? cdnVideoSources,
    List<String?>? cdnAudioSources,
    this.cdnIndex = 0,
  }) : cdnVideoSources = List<String>.unmodifiable(
         cdnVideoSources == null || cdnVideoSources.isEmpty
             ? [videoSource]
             : cdnVideoSources,
       ),
       cdnAudioSources = List<String?>.unmodifiable(
         cdnAudioSources == null || cdnAudioSources.isEmpty
             ? [audioSource]
             : cdnAudioSources,
       ),
       super(videoSource: videoSource, audioSource: audioSource);

  int get cdnCount => cdnVideoSources.length;

  bool get hasNextCdn => cdnIndex + 1 < cdnCount;

  NetworkSource atCdnIndex(int index) {
    final resolvedIndex = index < 0
        ? 0
        : index >= cdnCount
        ? cdnCount - 1
        : index;
    final resolvedAudioIndex = resolvedIndex >= cdnAudioSources.length
        ? cdnAudioSources.length - 1
        : resolvedIndex;
    final resolvedAudio = cdnAudioSources.isEmpty
        ? audioSource
        : cdnAudioSources[resolvedAudioIndex];
    return NetworkSource(
      videoSource: cdnVideoSources[resolvedIndex],
      audioSource: resolvedAudio,
      cdnVideoSources: cdnVideoSources,
      cdnAudioSources: cdnAudioSources,
      cdnIndex: resolvedIndex,
    );
  }
}

class FileSource extends DataSource {
  final String dir;
  final bool isMp4;

  FileSource({
    required this.dir,
    required this.isMp4,
    required bool hasDashAudio,
    required String typeTag,
  }) : super(
         videoSource: path.join(
           dir,
           typeTag,
           isMp4 ? PathUtils.videoNameType1 : PathUtils.videoNameType2,
         ),
         audioSource: isMp4 || !hasDashAudio
             ? null
             : path.join(dir, typeTag, PathUtils.audioNameType2),
       );
}
