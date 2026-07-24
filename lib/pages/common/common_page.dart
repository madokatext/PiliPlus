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
      notification.depth > 1 ||
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
      break;
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
double _convertScrollDelta(double scrollDelta) {
  if (!needsCorrection) {
    return scrollDelta;
  }

  return scrollDelta *
      Style.topBarHeight /
      collapsibleExtent;
}
bool onNotificationType2(ScrollNotification notification) {
  if (!_mainController.useBottomNav ||
      notification.depth > 1 ||
      notification.metrics.axis == .horizontal) {
    return false;
  }

  final metrics = notification.metrics;

  if (notification is ScrollUpdateNotification) {
    final pixel = metrics.pixels;
    final scrollDelta = notification.scrollDelta ?? 0.0;
    final isDirectDrag = notification.dragDetails != null;

    // 顶部弹性区域向内容范围回弹时，不反向推动栏位移。
    if (pixel < 0.0 && scrollDelta > 0.0) {
      return false;
    }

    final barDelta = _convertScrollDelta(scrollDelta);

    if (needsCorrection && isDirectDrag) {
      final oldValue = _barOffset!.value;
      final newValue = clampDouble(
        oldValue + barDelta,
        0.0,
        Style.topBarHeight,
      );

      // 将 barOffset 的变化量换算回实际布局高度变化量。
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
      // 惯性滚动、程序化滚动也必须使用同一套比例换算。
      _updateOffset(barDelta);
    }

    return false;
  }

  if (notification is OverscrollNotification) {
    _updateOffset(
      _convertScrollDelta(notification.overscroll),
    );
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
