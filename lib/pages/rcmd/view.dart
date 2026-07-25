import 'package:PiliPlus/common/skeleton/video_card_v.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/video_card/video_card_v.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/home_tab_type.dart';
import 'package:PiliPlus/models/model_rec_video_item.dart';
import 'package:PiliPlus/pages/home/controller.dart';
import 'package:PiliPlus/pages/rcmd/controller.dart';
import 'package:PiliPlus/pages/rcmd/widgets/home_exposure_detector.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:PiliPlus/utils/home_card_layout_prefs.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class RcmdPage extends StatefulWidget {
  const RcmdPage({super.key});

  @override
  State<RcmdPage> createState() => _RcmdPageState();
}

class _RcmdPageState extends State<RcmdPage>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final RcmdController controller = Get.put(RcmdController());
  final GlobalKey _viewportKey = GlobalKey();
  final HomeExposureTracker _exposureTracker = HomeExposureTracker();
  late final HomeController _homeController = Get.find<HomeController>();
  bool _isAppForeground = true;
  bool _tickerModeEnabled = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isAppForeground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _homeController.tabController.addListener(_scheduleExposureCheck);
    _exposureTracker.attach(
      viewportKey: _viewportKey,
      canTrack: _canTrackExposure,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerModeEnabled = TickerMode.valuesOf(context).enabled;
    _scheduleExposureCheck();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppForeground = state == AppLifecycleState.resumed;
    if (_isAppForeground) {
      _scheduleExposureCheck();
    }
  }

  bool _canTrackExposure() {
    if (!mounted || !_isAppForeground || !_tickerModeEnabled) {
      return false;
    }
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      return false;
    }
    return _homeController.tabs[_homeController.tabController.index] ==
        HomeTabType.rcmd;
  }

  void _scheduleExposureCheck() => _exposureTracker.scheduleCheck();

  @override
  void dispose() {
    _homeController.tabController.removeListener(_scheduleExposureCheck);
    WidgetsBinding.instance.removeObserver(this);
    _exposureTracker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = ColorScheme.of(context);
    return Container(
      clipBehavior: .hardEdge,
      margin: EdgeInsets.symmetric(
        horizontal: HomeCardLayoutPrefs.horizontalPadding,
      ),
      decoration: const BoxDecoration(borderRadius: Style.mdRadius),
      child: refreshIndicator(
        onRefresh: controller.onRefresh,
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            _scheduleExposureCheck();
            final towardEnd = switch (notification) {
              ScrollUpdateNotification(:final scrollDelta?) => scrollDelta > 0,
              OverscrollNotification(:final overscroll) => overscroll > 0,
              _ => false,
            };
            if (towardEnd) {
              controller.onUserScrollTowardEnd(
                atEnd: notification.metrics.extentAfter <= 0,
              );
            }
            return false;
          },
          child: CustomScrollView(
            key: _viewportKey,
            controller: controller.scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const .only(top: Style.cardSpace, bottom: 100),
                sliver: Obx(
                  () => _buildBody(colorScheme, controller.loadingState.value),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  SliverGridDelegateWithExtentAndRatio get gridDelegate =>
      SliverGridDelegateWithExtentAndRatio(
        mainAxisSpacing: HomeCardLayoutPrefs.verticalSpacing,
        crossAxisSpacing: HomeCardLayoutPrefs.horizontalSpacing,
        maxCrossAxisExtent: Pref.recommendCardWidth,
        childAspectRatio: Pref.homeCardAspectRatio.ratio,
        mainAxisExtent: MediaQuery.textScalerOf(context).scale(90),
      );

  Widget _buildBody(
    ColorScheme colorScheme,
    LoadingState<List<dynamic>?> loadingState,
  ) {
    return switch (loadingState) {
      Loading() => _buildSkeleton,
      Success(:final response) =>
        response != null && response.isNotEmpty
            ? SliverGrid.builder(
                gridDelegate: gridDelegate,
                itemBuilder: (context, index) {
                  controller.requestLoadMore(index, response.length);
                  if (controller.lastRefreshAt != null) {
                    if (controller.lastRefreshAt == index) {
                      return GestureDetector(
                        onTap: () => controller
                          ..animateToTop()
                          ..onRefresh(),
                        child: Card(
                          child: Container(
                            alignment: Alignment.center,
                            padding: const .symmetric(horizontal: 10),
                            child: Text(
                              '上次看到这里\n\n点击刷新',
                              textAlign: .center,
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    final actualIndex = index > controller.lastRefreshAt!
                        ? index - 1
                        : index;
                    return _buildVideoCard(response[actualIndex], actualIndex);
                  } else {
                    return _buildVideoCard(response[index], index);
                  }
                },
                itemCount: controller.lastRefreshAt != null
                    ? response.length + 1
                    : response.length,
              )
            : HttpError(onReload: controller.onReload),
      Error(:final errMsg) => HttpError(
        errMsg: errMsg,
        onReload: controller.onReload,
      ),
    };
  }

  Widget get _buildSkeleton => SliverGrid.builder(
    gridDelegate: gridDelegate,
    itemBuilder: (context, index) => VideoCardVSkeleton(
      aspectRatio: Pref.homeCardAspectRatio.ratio,
    ),
    itemCount: 10,
  );

  Widget _buildVideoCard(dynamic rawItem, int index) {
    final item = rawItem as BaseRcmdVideoItemModel;
    final card = VideoCardV(
      videoItem: item,
      aspectRatio: Pref.homeCardAspectRatio.ratio,
      onRemove: () => controller.removeItemAt(index),
    );
    final occurrenceId = item.historyOccurrenceId;
    if (occurrenceId == null) {
      return card;
    }
    return HomeExposureDetector(
      key: ValueKey(occurrenceId),
      tracker: _exposureTracker,
      occurrenceId: occurrenceId,
      onVisible: () => controller.recordExposure(item),
      child: card,
    );
  }
}
