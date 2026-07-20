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
    if (!_mainController.useBottomNav) return false;
    if (notification.metrics.axis == .horizontal) return false;
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
  if (!_mainController.useBottomNav) return false;

  final metrics = notification.metrics;
  if (metrics.axis == .horizontal) return false;

  if (notification is ScrollUpdateNotification) {
    final pixel = metrics.pixels;
    final scrollDelta = notification.scrollDelta ?? 0.0;
    final isDirectDrag = notification.dragDetails != null;

    // 顶部弹性区域向内容范围回弹时，不反向推动栏位移。
    if (pixel < 0.0 && scrollDelta > 0.0) {
      return false;
    }

    if (needsCorrection && isDirectDrag) {
      // 手指直接拖动时，顶栏高度改变会同时改变滚动视口位置。
      // 继续修正 ScrollPosition，保证内容与手指保持 1:1 跟随。
      final value = _barOffset!.value;
      final newValue = clampDouble(
        value + scrollDelta,
        0.0,
        Style.topBarHeight,
      );
      final correction = value - newValue;

      if (correction != 0.0) {
        _barOffset!.value = newValue;

        if (pixel < 0.0 && scrollDelta < 0.0 && value > 0.0) {
          return false;
        }

        Scrollable.of(
          notification.context!,
        ).position.correctBy(correction);
      }
    } else {
      // 惯性滚动、程序化滚动，以及不需要布局修正的页面：
      // 只让顶/底栏跟随实际滚动增量，不干扰正在运行的 simulation。
      _updateOffset(scrollDelta);
    }

    return false;
  }

  if (notification is OverscrollNotification) {
    _updateOffset(notification.overscroll);
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
