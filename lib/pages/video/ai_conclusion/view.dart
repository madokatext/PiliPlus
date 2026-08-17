import 'package:PiliPlus/common/widgets/gesture/tap_gesture_recognizer.dart';
import 'package:PiliPlus/common/widgets/selectable_text.dart';
import 'package:PiliPlus/models_new/video/video_ai_conclusion/model_result.dart';
import 'package:PiliPlus/pages/common/slide/common_slide_page.dart';
import 'package:PiliPlus/pages/video/controller.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:extended_nested_scroll_view/extended_nested_scroll_view.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AiConclusionPanel extends CommonSlidePage {
  final AiConclusionResult item;

  const AiConclusionPanel({
    super.key,
    required this.item,
  });

  @override
  State<AiConclusionPanel> createState() => _AiDetailState();

  static String buildCopyText(AiConclusionResult res) {
    final subtitleParts = res.webSubtitleParts.toList(growable: false);
    if (subtitleParts.isNotEmpty) {
      return subtitleParts
          .map(
            (item) =>
                '${DurationUtils.formatDuration(item.startTimestamp)} '
                '${item.content!.trim()}',
          )
          .join('\n');
    }
    return res.fallbackSubtitle?.trim() ?? '';
  }

  static Widget buildContent(
    BuildContext context,
    ThemeData theme,
    AiConclusionResult res, {
    Key? key,
    bool tap = true,
  }) {
    final subtitleParts = res.webSubtitleParts.toList(growable: false);
    final fallbackSubtitle = res.fallbackSubtitle?.trim();
    final copyText = buildCopyText(res);
    final bottomPadding =
        !tap ? 0.0 : MediaQuery.viewPaddingOf(context).bottom + 100;

    return CustomScrollView(
      key: key,
      shrinkWrap: !tap,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (copyText.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            sliver: SliverToBoxAdapter(
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => Utils.copyText(
                    copyText,
                    toastText: '已赛博复刻我全都要内容，曼波',
                  ),
                  icon: const Icon(Icons.copy_all_outlined, size: 18),
                  label: const Text('赛博复刻我全都要，这把高端局'),
                ),
              ),
            ),
          ),
        if (subtitleParts.isNotEmpty)
          SliverPadding(
            padding: EdgeInsets.only(
              left: 14,
              right: 14,
              bottom: bottomPadding,
            ),
            sliver: SliverList.builder(
              itemCount: subtitleParts.length,
              itemBuilder: (context, index) {
                final item = subtitleParts[index];
                final startTimestamp = item.startTimestamp;
                return Padding(
                  padding: EdgeInsets.only(top: index == 0 ? 0 : 8),
                  child: SelectionArea(
                    child: Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface,
                          height: 1.5,
                        ),
                        children: [
                          TextSpan(
                            text: DurationUtils.formatDuration(startTimestamp),
                            style: tap && startTimestamp != null
                                ? TextStyle(color: theme.colorScheme.primary)
                                : null,
                            recognizer: tap && startTimestamp != null
                                ? (NoDeadlineTapGestureRecognizer()
                                    ..onTap = () {
                                      try {
                                        Get.find<VideoDetailController>(
                                          tag: Get.arguments['heroTag'],
                                        ).plPlayerController.seekTo(
                                          Duration(
                                            milliseconds:
                                                (startTimestamp * 1000).round(),
                                          ),
                                          isSeek: false,
                                        );
                                      } catch (_) {}
                                    })
                                : null,
                          ),
                          const TextSpan(text: ' '),
                          TextSpan(text: item.content?.trim() ?? ''),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        if (subtitleParts.isEmpty && fallbackSubtitle?.isNotEmpty == true)
          SliverPadding(
            padding: EdgeInsets.only(
              left: 14,
              right: 14,
              bottom: bottomPadding,
            ),
            sliver: SliverToBoxAdapter(
              child: selectableText(
                fallbackSubtitle!,
                style: const TextStyle(fontSize: 15, height: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}

class _AiDetailState extends State<AiConclusionPanel>
    with SingleTickerProviderStateMixin, CommonSlideMixin {
  @override
  Widget buildPage(ThemeData theme) {
    return Material(
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          GestureDetector(
            onTap: Get.back,
            child: SizedBox(
              height: 35,
              child: Center(
                child: Container(
                  width: 32,
                  height: 3,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: const BorderRadius.all(Radius.circular(3)),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: enableSlide ? slideList(theme) : buildList(theme),
          ),
        ],
      ),
    );
  }

  late Key _key;
  late bool _isNested;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = PrimaryScrollController.of(context);
    _isNested = controller is ExtendedNestedScrollController;
    _key = ValueKey(controller.hashCode);
  }

  @override
  Widget buildList(ThemeData theme) {
    final child = AiConclusionPanel.buildContent(
      context,
      theme,
      widget.item,
      key: _key,
    );
    if (_isNested) {
      return ExtendedVisibilityDetector(
        uniqueKey: const Key('ai-conclusion'),
        child: child,
      );
    }
    return child;
  }
}
