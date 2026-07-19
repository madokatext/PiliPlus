import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:PiliPlus/utils/horizontal_seek_gesture_prefs.dart';
import 'package:flutter/gestures.dart'
    show
        GestureDisposition,
        GestureRecognizer,
        PointerCancelEvent,
        PointerDownEvent,
        PointerEvent,
        PointerMoveEvent,
        PointerPanZoomEndEvent,
        PointerPanZoomStartEvent,
        PointerPanZoomUpdateEvent,
        PointerUpEvent,
        RecognizerCallback,
        ScaleGestureRecognizer;

mixin PlayerGestureMixin on GestureRecognizer {
  bool isPosAllowed = true;

  @override
  T? invokeCallback<T>(
    String name,
    RecognizerCallback<T> callback, {
    String Function()? debugReport,
  }) {
    if (!isPosAllowed) return null;
    return super.invokeCallback(name, callback, debugReport: debugReport);
  }
}

class PlayerScaleGestureRecognizer extends ScaleGestureRecognizer
    with PlayerGestureMixin {
  PlayerScaleGestureRecognizer({
    super.debugOwner,
    super.supportedDevices,
    super.allowedButtonsFilter,
    super.dragStartBehavior,
    super.trackpadScrollCausesScale,
    super.trackpadScrollToScaleFactor,
  });

  static const double _touchHorizontalSlope = 1.0;
  static const double _panZoomHorizontalSlope = 1 / 3;
  static const double _classificationEpsilon = 0.001;

  final Set<int> _activePointers = <int>{};
  final Map<int, Offset> _pointerStartPositions = <int, Offset>{};
  final Map<int, Offset> _lastForwardedPositions = <int, Offset>{};
  final Set<int> _acceptedHorizontalPointers = <int>{};
  bool _acceptedHorizontalPanZoom = false;

  double _classifiedDy(Offset delta, double horizontalSlope) {
    final dx = delta.dx.abs();
    final dy = delta.dy.abs();
    if (dx == 0) return delta.dy;

    final angleFromHorizontal =
        math.atan2(dy, dx) * 180.0 / math.pi;
    final legacyBoundary = dx * horizontalSlope;
    final sign = delta.dy < 0 ? -1.0 : 1.0;

    if (angleFromHorizontal <= HorizontalSeekGesturePrefs.angle) {
      if (dy < legacyBoundary) return delta.dy;
      return sign * math.max(0.0, legacyBoundary - _classificationEpsilon);
    }

    if (dy > legacyBoundary) return delta.dy;
    return sign * (legacyBoundary + _classificationEpsilon);
  }

  PointerMoveEvent _classifyPointerMove(PointerMoveEvent event) {
    final pointer = event.pointer;
    final start = _pointerStartPositions[pointer];
    if (start == null || _activePointers.length != 1) {
      _lastForwardedPositions[pointer] = event.position;
      return event;
    }

    if (_acceptedHorizontalPointers.contains(pointer)) {
      final last = _lastForwardedPositions[pointer] ?? event.position - event.delta;
      _lastForwardedPositions[pointer] = event.position;
      return event.copyWith(delta: event.position - last);
    }

    final delta = event.position - start;
    final classifiedPosition = Offset(
      event.position.dx,
      start.dy + _classifiedDy(delta, _touchHorizontalSlope),
    );
    final last = _lastForwardedPositions[pointer] ?? start;
    final classifiedEvent = event.copyWith(
      position: classifiedPosition,
      delta: classifiedPosition - last,
    );
    _lastForwardedPositions[pointer] = classifiedPosition;

    final angleFromHorizontal =
        math.atan2(delta.dy.abs(), delta.dx.abs()) * 180.0 / math.pi;
    if (angleFromHorizontal <= HorizontalSeekGesturePrefs.angle &&
        delta.dx.abs() >= HorizontalSeekGesturePrefs.triggerDistance) {
      _acceptedHorizontalPointers.add(pointer);
    }

    return classifiedEvent;
  }

  PointerPanZoomUpdateEvent _classifyPanZoom(
    PointerPanZoomUpdateEvent event,
  ) {
    if (_acceptedHorizontalPanZoom) return event;

    final pan = event.pan;
    final classifiedPan = Offset(
      pan.dx,
      _classifiedDy(pan, _panZoomHorizontalSlope),
    );
    final angleFromHorizontal =
        math.atan2(pan.dy.abs(), pan.dx.abs()) * 180.0 / math.pi;
    if (angleFromHorizontal <= HorizontalSeekGesturePrefs.angle &&
        pan.dx.abs() >= HorizontalSeekGesturePrefs.triggerDistance) {
      _acceptedHorizontalPanZoom = true;
    }

    return classifiedPan == pan ? event : event.copyWith(pan: classifiedPan);
  }

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _activePointers.add(event.pointer);
    _pointerStartPositions[event.pointer] = event.position;
    _lastForwardedPositions[event.pointer] = event.position;

    // A vertical pinch competes with the surrounding video's vertical
    // Scrollable. Claim the gesture as soon as the second finger lands,
    // before that Scrollable can interpret either finger as a drag.
    if (_activePointers.length >= 2) {
      _acceptedHorizontalPointers.clear();
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    PointerEvent classifiedEvent = event;
    if (event is PointerMoveEvent) {
      classifiedEvent = _classifyPointerMove(event);
    } else if (event is PointerPanZoomStartEvent) {
      _acceptedHorizontalPanZoom = false;
    } else if (event is PointerPanZoomUpdateEvent) {
      classifiedEvent = _classifyPanZoom(event);
    }

    super.handleEvent(classifiedEvent);

    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _activePointers.remove(event.pointer);
      _pointerStartPositions.remove(event.pointer);
      _lastForwardedPositions.remove(event.pointer);
      _acceptedHorizontalPointers.remove(event.pointer);
    } else if (event is PointerPanZoomEndEvent) {
      _acceptedHorizontalPanZoom = false;
    }
  }

  @override
  void rejectGesture(int pointer) {
    _activePointers.remove(pointer);
    _pointerStartPositions.remove(pointer);
    _lastForwardedPositions.remove(pointer);
    _acceptedHorizontalPointers.remove(pointer);
    super.rejectGesture(pointer);
  }

  @override
  void dispose() {
    _activePointers.clear();
    _pointerStartPositions.clear();
    _lastForwardedPositions.clear();
    _acceptedHorizontalPointers.clear();
    _acceptedHorizontalPanZoom = false;
    super.dispose();
  }
}
