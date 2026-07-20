import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/gestures.dart'
    show
        GestureVelocityTrackerBuilder,
        PointerDeviceKind,
        VelocityEstimate,
        VelocityTracker;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

class CustomScrollBehavior extends MaterialScrollBehavior {
  const CustomScrollBehavior({
    this.customDragDevices,
    this.verticalInertiaScale = 1.0,
    this.verticalDecelerationScale = 1.0,
  });

  final Set<PointerDeviceKind>? customDragDevices;

  /// 纵向手势松开速度倍率。
  ///
  /// 只修改速度估算结果的 Y 分量，因此不会改变横向 Tab 切换、
  /// 横向 PageView 或播放器横向手势。
  final double verticalInertiaScale;

  /// 纵向惯性滚动的减速度倍率。
  ///
  /// 1.0 保持 Flutter 默认物理参数；
  /// 大于 1.0 更快停止，小于 1.0 滑行更久。
  final double verticalDecelerationScale;

  @override
  Set<PointerDeviceKind> get dragDevices =>
      customDragDevices ?? super.dragDevices;

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;

  /// 在手势速度估算阶段缩放纵向松手速度。
  ///
  /// 必须在这里处理惯性倍率，不能在 createBallisticSimulation()
  /// 中直接反复乘 velocity。后者可能在同一次滚动重建 simulation 时
  /// 重复缩放速度，造成速度不断放大或缩小。
  @override
  GestureVelocityTrackerBuilder velocityTrackerBuilder(BuildContext context) {
    final delegateBuilder = super.velocityTrackerBuilder(context);

    return (event) => _VerticalVelocityScaleTracker(
      delegateBuilder(event),
      verticalInertiaScale,
    );
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return _AdjustableVerticalScrollPhysics(
      platform: getPlatform(context),
      decelerationScale: verticalDecelerationScale,
      parent: super.getScrollPhysics(context),
    );
  }

  @override
  bool shouldNotify(covariant CustomScrollBehavior oldDelegate) {
    return customDragDevices != oldDelegate.customDragDevices ||
        verticalInertiaScale != oldDelegate.verticalInertiaScale ||
        verticalDecelerationScale != oldDelegate.verticalDecelerationScale;
  }
}

/// 包装 Flutter 原有 VelocityTracker，只缩放 Y 方向速度。
class _VerticalVelocityScaleTracker extends VelocityTracker {
  _VerticalVelocityScaleTracker(
    VelocityTracker delegate,
    this.scale,
  ) : _delegate = delegate,
      super.withKind(delegate.kind);

  final VelocityTracker _delegate;
  final double scale;

  @override
  void addPosition(Duration time, Offset position) {
    _delegate.addPosition(time, position);
  }

  @override
  VelocityEstimate? getVelocityEstimate() {
    final estimate = _delegate.getVelocityEstimate();
    if (estimate == null) {
      return null;
    }

    final velocity = estimate.pixelsPerSecond;

    return VelocityEstimate(
      pixelsPerSecond: Offset(
        velocity.dx,
        velocity.dy * scale,
      ),
      confidence: estimate.confidence,
      duration: estimate.duration,
      offset: estimate.offset,
    );
  }
}

/// 仅接管纵向 ballistic simulation。
///
/// 横向滚动继续交给父级 ScrollPhysics，因此不会改变 PageView、
/// TabBarView 等横向分页组件。
class _AdjustableVerticalScrollPhysics extends ScrollPhysics {
  const _AdjustableVerticalScrollPhysics({
    required this.platform,
    required this.decelerationScale,
    super.parent,
  });

  final TargetPlatform platform;
  final double decelerationScale;

  bool get _usesBouncingPhysics =>
      platform == TargetPlatform.iOS ||
      platform == TargetPlatform.macOS;

  @override
  _AdjustableVerticalScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _AdjustableVerticalScrollPhysics(
      platform: platform,
      decelerationScale: decelerationScale,
      parent: buildParent(ancestor),
    );
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    // 横向分页、横向列表等维持原 ScrollPhysics。
    if (axisDirectionToAxis(position.axisDirection) != Axis.vertical) {
      return parent?.createBallisticSimulation(position, velocity);
    }

    if (_usesBouncingPhysics) {
      return _createBouncingSimulation(position, velocity);
    }

    return _createClampingSimulation(position, velocity);
  }

  Simulation? _createClampingSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final tolerance = toleranceFor(position);

    if (position.outOfRange) {
      double? end;

      if (position.pixels > position.maxScrollExtent) {
        end = position.maxScrollExtent;
      }

      if (position.pixels < position.minScrollExtent) {
        end = position.minScrollExtent;
      }

      assert(end != null);

      return ScrollSpringSimulation(
        spring,
        position.pixels,
        end!,
        math.min(0.0, velocity),
        tolerance: tolerance,
      );
    }

    if (velocity.abs() < tolerance.velocity) {
      return null;
    }

    if (velocity > 0.0 &&
        position.pixels >= position.maxScrollExtent) {
      return null;
    }

    if (velocity < 0.0 &&
        position.pixels <= position.minScrollExtent) {
      return null;
    }

    return ClampingScrollSimulation(
      position: position.pixels,
      velocity: velocity,
      friction: 0.015 * decelerationScale,
      tolerance: tolerance,
    );
  }

  Simulation? _createBouncingSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final tolerance = toleranceFor(position);

    if (velocity.abs() < tolerance.velocity && !position.outOfRange) {
      return null;
    }

    return _AdjustableBouncingScrollSimulation(
      position: position.pixels,
      velocity: velocity,
      leadingExtent: position.minScrollExtent,
      trailingExtent: position.maxScrollExtent,
      spring: spring,
      // Flutter 默认使用 0.135。
      // 指数倍率能保持 1.0 时完全等于默认值。
      drag: math.pow(0.135, decelerationScale).toDouble(),
      tolerance: tolerance,
    );
  }
}

/// 基于 Flutter BouncingScrollSimulation，
/// 唯一区别是将固定 drag=0.135 改成可配置值。
class _AdjustableBouncingScrollSimulation extends Simulation {
  _AdjustableBouncingScrollSimulation({
    required double position,
    required double velocity,
    required this.leadingExtent,
    required this.trailingExtent,
    required this.spring,
    required this.drag,
    super.tolerance,
  }) : assert(leadingExtent <= trailingExtent) {
    if (position < leadingExtent) {
      _springSimulation = _underscrollSimulation(position, velocity);
      _springTime = double.negativeInfinity;
      return;
    }

    if (position > trailingExtent) {
      _springSimulation = _overscrollSimulation(position, velocity);
      _springTime = double.negativeInfinity;
      return;
    }

    _frictionSimulation = FrictionSimulation(
      drag,
      position,
      velocity,
    );

    final finalX = _frictionSimulation.finalX;

    if (velocity > 0.0 && finalX > trailingExtent) {
      _springTime = _frictionSimulation.timeAtX(trailingExtent);
      _springSimulation = _overscrollSimulation(
        trailingExtent,
        _transferVelocity(_frictionSimulation.dx(_springTime)),
      );
      return;
    }

    if (velocity < 0.0 && finalX < leadingExtent) {
      _springTime = _frictionSimulation.timeAtX(leadingExtent);
      _springSimulation = _underscrollSimulation(
        leadingExtent,
        _transferVelocity(_frictionSimulation.dx(_springTime)),
      );
      return;
    }

    _springTime = double.infinity;
  }

  static const double _maxSpringTransferVelocity = 5000.0;

  final double leadingExtent;
  final double trailingExtent;
  final SpringDescription spring;
  final double drag;

  late FrictionSimulation _frictionSimulation;
  late Simulation _springSimulation;
  late double _springTime;

  double _timeOffset = 0.0;

  double _transferVelocity(double velocity) {
    return velocity
        .clamp(
          -_maxSpringTransferVelocity,
          _maxSpringTransferVelocity,
        )
        .toDouble();
  }

  Simulation _underscrollSimulation(double position, double velocity) {
    return ScrollSpringSimulation(
      spring,
      position,
      leadingExtent,
      velocity,
    );
  }

  Simulation _overscrollSimulation(double position, double velocity) {
    return ScrollSpringSimulation(
      spring,
      position,
      trailingExtent,
      velocity,
    );
  }

  Simulation _simulation(double time) {
    final Simulation simulation;

    if (time > _springTime) {
      _timeOffset = _springTime.isFinite ? _springTime : 0.0;
      simulation = _springSimulation;
    } else {
      _timeOffset = 0.0;
      simulation = _frictionSimulation;
    }

    simulation.tolerance = tolerance;
    return simulation;
  }

  @override
  double x(double time) {
    return _simulation(time).x(time - _timeOffset);
  }

  @override
  double dx(double time) {
    return _simulation(time).dx(time - _timeOffset);
  }

  @override
  bool isDone(double time) {
    return _simulation(time).isDone(time - _timeOffset);
  }
}

const Set<PointerDeviceKind> desktopDragDevices = <PointerDeviceKind>{
  PointerDeviceKind.touch,
  PointerDeviceKind.stylus,
  PointerDeviceKind.invertedStylus,
  PointerDeviceKind.trackpad,
  PointerDeviceKind.unknown,
  PointerDeviceKind.mouse,
};
