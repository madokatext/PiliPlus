import 'package:PiliPlus/common/widgets/scroll_physics.dart';
import 'package:PiliPlus/common/widgets/custom_height_widget.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/common/dynamic/dynamics_type.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/models/common/dynamic/up_panel_position.dart';
import 'package:PiliPlus/models/dynamics/up.dart';
import 'package:PiliPlus/pages/common/common_page.dart';
import 'package:PiliPlus/pages/dynamics/controller.dart';
import 'package:PiliPlus/pages/dynamics/widgets/up_panel.dart';
import 'package:PiliPlus/pages/dynamics_create/view.dart';
import 'package:PiliPlus/pages/dynamics_tab/view.dart';
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:flutter/material.dart' hide DraggableScrollableSheet;
import 'package:get/get.dart';

class DynamicsPage extends StatefulWidget {
  const DynamicsPage({super.key});

  @override
  State<DynamicsPage> createState() => _DynamicsPageState();
}

class _DynamicsPageState extends CommonPageState<DynamicsPage>
    with AutomaticKeepAliveClientMixin {
  final _dynamicsController = Get.putOrFind(DynamicsController.new);
  UpPanelPosition get upPanelPosition => _dynamicsController.upPanelPosition;
  late final MainController _mainController = Get.find<MainController>();
static const double _topUpPanelHeight = 76.0;

@override
bool get needsCorrection => upPanelPosition == .top;

@override
double get collapsibleExtent => _topUpPanelHeight;
  @override
  bool get wantKeepAlive => true;

  Widget _createDynamicBtn(ThemeData theme, {bool isRight = true}) => Center(
    child: Container(
      width: 34,
      height: 34,
      margin: EdgeInsets.only(left: !isRight ? 16 : 0, right: isRight ? 16 : 0),
      child: IconButton(
        tooltip: '发射到互联网互联网近况',
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          backgroundColor: WidgetStatePropertyAll(
            theme.colorScheme.secondaryContainer,
          ),
        ),
        onPressed: () => CreateDynPanel.onCreateDyn(context),
        icon: Icon(
          Icons.add,
          size: 18,
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    ),
  );

  Widget upPanelPart(ThemeData theme) {
    final isTop = upPanelPosition == .top;
    final needBg = upPanelPosition.index > 2;
    return Material(
      type: needBg ? .canvas : .transparency,
      color: needBg ? theme.colorScheme.surface : null,
      child: SizedBox(
        width: isTop ? null : 64,
        height: isTop ? _topUpPanelHeight : null,
        child: NotificationListener<ScrollEndNotification>(
          onNotification: (notification) {
            final metrics = notification.metrics;
            if (metrics.pixels >= metrics.maxScrollExtent - 300) {
              _dynamicsController.onLoadMore();
            }
            return false;
          },
          child: Obx(
            () => _buildUpPanel(_dynamicsController.loadingState.value),
          ),
        ),
      ),
    );
  }
Widget _collapsibleTopUpPanel(ThemeData theme) {
  // 放在 Obx 外，避免每一个滚动像素都重新创建整个头像栏组件树。
  final panel = upPanelPart(theme);

  final barOffset = _mainController.barOffset;

  // sync 模式
  if (barOffset != null) {
    return Obx(() {
      final offset =
          (barOffset.value /
                  Style.topBarHeight *
                  _topUpPanelHeight)
              .clamp(0.0, _topUpPanelHeight)
              .toDouble();

      return ClipRect(
        child: CustomHeightWidget(
          height: _topUpPanelHeight - offset,
          offset: Offset(0.0, -offset),
          child: panel,
        ),
      );
    });
  }

  final showBottomBar = _mainController.showBottomBar;

  // instant 模式
  if (showBottomBar != null) {
    return Obx(
      () => TweenAnimationBuilder<double>(
        tween: Tween<double>(
          end: showBottomBar.value
              ? 0.0
              : _topUpPanelHeight,
        ),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: panel,
        builder: (context, offset, child) {
          return ClipRect(
            child: CustomHeightWidget(
              height: _topUpPanelHeight - offset,
              offset: Offset(0.0, -offset),
              child: child!,
            ),
          );
        },
      ),
    );
  }

  return panel;
}
  Widget _buildUpPanel(LoadingState<FollowUpModel> upState) {
    return switch (upState) {
      Loading() => const SizedBox.shrink(),
      Success(:final response) => UpPanel(
        upData: response,
        dynamicsController: _dynamicsController,
      ),
      Error() => Center(
        child: IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _dynamicsController.onReload,
        ),
      ),
    };
  }

  bool get _isCurrentPage =>
    _mainController.navigationBars[
        _mainController.selectedIndex.value
    ] ==
    .dynamics;

  @override
bool onNotificationType1(
  UserScrollNotification notification,
) {
  if (!_isCurrentPage) {
    return false;
  }
  return super.onNotificationType1(notification);
}

@override
bool onNotificationType2(
  ScrollNotification notification,
) {
  if (!_isCurrentPage) {
    return false;
  }
  return super.onNotificationType2(notification);
}

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    Widget? drawer;
    Widget? endDrawer;

    Widget? leading;
    List<Widget>? actions;

    Widget child = tabBarView(
      controller: _dynamicsController.tabController,
      children: DynamicsTabType.values
          .map((e) => DynamicsTabPage(dynamicsType: e))
          .toList(),
    );

    switch (upPanelPosition) {
      case UpPanelPosition.top:
  child = Column(
    children: [
      _collapsibleTopUpPanel(theme),
      Expanded(child: child),
    ],
  );
  actions = [_createDynamicBtn(theme)];
      case UpPanelPosition.leftFixed:
        child = Row(
          children: [
            upPanelPart(theme),
            Expanded(child: child),
          ],
        );
        actions = [_createDynamicBtn(theme)];
      case UpPanelPosition.rightFixed:
        child = Row(
          children: [
            Expanded(child: child),
            upPanelPart(theme),
          ],
        );
        actions = [_createDynamicBtn(theme)];
      case UpPanelPosition.leftDrawer:
        drawer = upPanelPart(theme);
        actions = [_createDynamicBtn(theme)];
      case UpPanelPosition.rightDrawer:
        endDrawer = upPanelPart(theme);
        leading = _createDynamicBtn(theme, isRight: false);
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        primary: false,
        leading: leading,
        leadingWidth: 50,
        toolbarHeight: 50,
        backgroundColor: Colors.transparent,
        title: SizedBox(
          height: 50,
          child: TabBar(
            dividerHeight: 0,
            isScrollable: true,
            tabAlignment: .center,
            dividerColor: Colors.transparent,
            labelColor: theme.colorScheme.primary,
            indicatorColor: theme.colorScheme.primary,
            controller: _dynamicsController.tabController,
            unselectedLabelColor: theme.colorScheme.onSurface,
            labelStyle:
                TabBarTheme.of(context).labelStyle?.copyWith(fontSize: 13) ??
                const TextStyle(fontSize: 13),
            tabs: DynamicsTabType.values
                .map((e) => Tab(text: e.label))
                .toList(),
            onTap: (index) {
              if (!_dynamicsController.tabController.indexIsChanging) {
                _dynamicsController.animateToTop();
              }
            },
          ),
        ),
        actions: actions,
      ),
      drawer: drawer,
      endDrawer: endDrawer,
      body: onBuild(child),
    );
  }
}
