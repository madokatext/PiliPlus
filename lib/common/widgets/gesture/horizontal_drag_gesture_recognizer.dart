import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/foundation.dart' show PlatformDispatcher;
import 'package:flutter/gestures.dart';

mixin InitialPositionMixin on GestureRecognizer {
  Offset? _initialPosition;
  Offset? get initialPosition => _initialPosition;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _initialPosition = event.position;
  }
}

class CustomHorizontalDragGestureRecognizer
    extends HorizontalDragGestureRecognizer
    with InitialPositionMixin {
  CustomHorizontalDragGestureRecognizer({
    super.debugOwner,
    super.supportedDevices,
    super.allowedButtonsFilter,
    this.shouldAcceptLeftDownwardDragAt45Degrees,
  });

  final bool Function()? shouldAcceptLeftDownwardDragAt45Degrees;
  bool _acceptLeftDownwardDragAt45Degrees = false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _acceptLeftDownwardDragAt45Degrees =
        shouldAcceptLeftDownwardDragAt45Degrees?.call() ?? false;
    super.addAllowedPointer(event);
  }

  @override
  DeviceGestureSettings get gestureSettings => _gestureSettings;
  final _gestureSettings = DeviceGestureSettings(touchSlop: touchSlopH);

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) {
    return _computeHitSlop(
      globalDistanceMoved.abs(),
      gestureSettings,
      pointerDeviceKind,
      _initialPosition,
      lastPosition.global,
      acceptLeftDownwardDragAt45Degrees:
          _acceptLeftDownwardDragAt45Degrees,
    );
  }

  @override
  bool isFlingGesture(
    VelocityEstimate estimate,
    PointerDeviceKind kind,
  ) {
    final double minDistance =
        minFlingDistance ?? computeHitSlop(kind, gestureSettings);

    return estimate.pixelsPerSecond.dx.abs() >
            Pref.tabSwipeVelocityThreshold &&
        estimate.offset.dx.abs() > minDistance;
  }
}

double touchSlopH = Pref.touchSlopH;

bool _computeHitSlop(
  double globalDistanceMoved,
  DeviceGestureSettings settings,
  PointerDeviceKind kind,
  Offset? initialPosition,
  Offset lastPosition, {
  required bool acceptLeftDownwardDragAt45Degrees,
}) {
  switch (kind) {
    case .mouse:
      return globalDistanceMoved > kPrecisePointerHitSlop;
    case .stylus:
    case .invertedStylus:
    case .unknown:
    case .touch:
      return globalDistanceMoved > settings.touchSlop! &&
          _calcAngle(
            initialPosition!,
            lastPosition,
            acceptLeftDownwardDragAt45Degrees:
                acceptLeftDownwardDragAt45Degrees,
          );
    case .trackpad:
      return globalDistanceMoved > settings.touchSlop!;
  }
}

bool _calcAngle(
  Offset initialPosition,
  Offset lastPosition, {
  required bool acceptLeftDownwardDragAt45Degrees,
}) {
  final offset = lastPosition - initialPosition;
  if (acceptLeftDownwardDragAt45Degrees &&
      offset.dx < 0 &&
      offset.dy > 0) {
    return offset.dx.abs() >= offset.dy;
  }
  return offset.dx.abs() > offset.dy.abs() * 3;
}

final deviceTouchSlop = _calcDeviceTouchSlop();

double _calcDeviceTouchSlop() {
  final view = PlatformDispatcher.instance.views.first;
  final physicalTouchSlop = view.gestureSettings.physicalTouchSlop;
  return physicalTouchSlop == null
      ? kTouchSlop
      : physicalTouchSlop / view.devicePixelRatio;
}
