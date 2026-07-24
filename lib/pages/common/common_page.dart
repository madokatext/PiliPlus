import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/pages/home/controller.dart';
import 'package:PiliPlus/pages/main/controller.dart';
import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

abstract class CommonPageState<T extends StatefulWidget> extends State<T> {
  RxDouble? _barOffset;
  RxBool? _showTopBar;
  RxBool? _showBottomBar;
  final _mainController = Get.find<MainController>();

  bool get needsCorrection => false;

/// 当前页面中会随 barOffset 改变布局高度的区域实际高度。
double get collapsibleExtent => Style.topBarHeight;

  @override
  void initState() {
    super.initState();
    _barOffset = _mainController.barOffset;
    _showBottomBar = _mainController.showBottomBar;
    try {
      _showTopBar = Get.find<HomeController>().showTopBar;
    } catch (_) {}
  }

  Widget onBuild(Widget child) {
    if (_barOffset != null) {
      return NotificationListener<ScrollNotification>(
        onNotification: onNotificationType2,
        child: child,
      );
    }
    if (_showTopBar != null || _showBottomBar != null) {
      return NotificationListener<UserScrollNotification>(
        onNotification: onNotificationType1,
        child: child,
      );
    }
    return child;
  }

  bool onNotificationType1(UserScrollNotification notification) {
  if (!_mainController.useBottomNav ||
      notification.depth != 0 ||
      notification.metrics.axis == .horizontal) {
    return false;
  }
    switch (notification.direction) {
      case .forward:
        _showTopBar?.value = true;
        _showBottomBar?.value = true;
      case .reverse:
        _showTopBar?.value = false;
        _showBottomBar?.value = false;
      case _:
    }
    return false;
  }

  void _updateOffset(double scrollDelta) {
    _barOffset!.value = clampDouble(
      _barOffset!.value + scrollDelta,
      0.0,
      Style.topBarHeight,
    );
  }

bool onNotificationType2(ScrollNotification notification) {
  if (!_mainController.useBottomNav ||
      notification.depth != 0 ||
      notification.metrics.axis == .horizontal) {
    return false;
  }

  final metrics = notification.metrics;

  if (notification is ScrollUpdateNotification) {
    final pixel = metrics.pixels;
    final scrollDelta = notification.scrollDelta ?? 0.0;
    final isDirectDrag = notification.dragDetails != null;

    // 顶部弹性区域回弹时，不把回弹方向当作新的向下滚动。
    if (pixel < 0.0 && scrollDelta > 0.0) {
      return false;
    }

    if (needsCorrection && isDirectDrag) {
      final oldValue = _barOffset!.value;
      final newValue = clampDouble(
        oldValue + scrollDelta,
        0.0,
        Style.topBarHeight,
      );

      // barOffset 的范围固定为 0~52，但页面实际收起高度可能不是 52。
      final correction =
          (oldValue - newValue) *
          collapsibleExtent /
          Style.topBarHeight;

      if (correction != 0.0) {
        _barOffset!.value = newValue;

        Scrollable.of(
          notification.context!,
        ).position.correctBy(correction);
      }
    } else {
      _updateOffset(scrollDelta);
    }

    return false;
  }

  if (notification is OverscrollNotification) {
    // ClampingScrollPhysics 到达边界时，位移表现为 overscroll，
    // 此时也要按真实收起高度换算，否则动态头像栏仍会移动过快。
    final offsetDelta = needsCorrection
        ? notification.overscroll *
              Style.topBarHeight /
              collapsibleExtent
        : notification.overscroll;

    _updateOffset(offsetDelta);
    return false;
  }

  return false;
}

  @override
  void dispose() {
    _barOffset = null;
    _showTopBar = null;
    _showBottomBar = null;
    super.dispose();
  }
}
