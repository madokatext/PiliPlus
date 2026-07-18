import 'package:flutter/gestures.dart'
    show
        GestureDisposition,
        GestureRecognizer,
        PointerCancelEvent,
        PointerDownEvent,
        PointerEvent,
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

  final Set<int> _activePointers = <int>{};

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _activePointers.add(event.pointer);

    // A vertical pinch competes with the surrounding video's vertical
    // Scrollable. Claim the gesture as soon as the second finger lands,
    // before that Scrollable can interpret either finger as a drag.
    if (_activePointers.length >= 2) {
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    super.handleEvent(event);
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _activePointers.remove(event.pointer);
    }
  }

  @override
  void rejectGesture(int pointer) {
    _activePointers.remove(pointer);
    super.rejectGesture(pointer);
  }

  @override
  void dispose() {
    _activePointers.clear();
    super.dispose();
  }
}
