import 'package:flutter/material.dart';

class HomeExposureTracker {
  final Set<_HomeExposureDetectorState> _entries = {};
  final Set<String> _seenOccurrences = {};

  GlobalKey? _viewportKey;
  bool Function()? _canTrack;
  bool _scheduled = false;
  bool _disposed = false;

  void attach({
    required GlobalKey viewportKey,
    required bool Function() canTrack,
  }) {
    _viewportKey = viewportKey;
    _canTrack = canTrack;
    scheduleCheck();
  }

  void _register(_HomeExposureDetectorState entry) {
    if (_disposed || _seenOccurrences.contains(entry.occurrenceId)) {
      return;
    }
    _entries.add(entry);
    scheduleCheck();
  }

  void _unregister(_HomeExposureDetectorState entry) {
    _entries.remove(entry);
  }

  void scheduleCheck() {
    if (_disposed || _scheduled) {
      return;
    }
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      _checkVisibleEntries();
    });
  }

  void _checkVisibleEntries() {
    if (_disposed || _canTrack?.call() != true) {
      return;
    }
    final viewportContext = _viewportKey?.currentContext;
    final viewportBox = viewportContext?.findRenderObject();
    if (viewportBox is! RenderBox ||
        !viewportBox.attached ||
        !viewportBox.hasSize) {
      return;
    }

    final viewportRect =
        viewportBox.localToGlobal(Offset.zero) & viewportBox.size;
    final visible = <_HomeExposureDetectorState>[];
    for (final entry in _entries) {
      if (_seenOccurrences.contains(entry.occurrenceId) ||
          !entry.isVisibleIn(viewportRect)) {
        continue;
      }
      _seenOccurrences.add(entry.occurrenceId);
      visible.add(entry);
    }
    for (final entry in visible) {
      _entries.remove(entry);
      entry.onVisible();
    }
  }

  void dispose() {
    _disposed = true;
    _entries.clear();
    _seenOccurrences.clear();
    _viewportKey = null;
    _canTrack = null;
  }
}

class HomeExposureDetector extends StatefulWidget {
  final HomeExposureTracker tracker;
  final String occurrenceId;
  final VoidCallback onVisible;
  final Widget child;

  const HomeExposureDetector({
    super.key,
    required this.tracker,
    required this.occurrenceId,
    required this.onVisible,
    required this.child,
  });

  @override
  State<HomeExposureDetector> createState() => _HomeExposureDetectorState();
}

class _HomeExposureDetectorState extends State<HomeExposureDetector> {
  String get occurrenceId => widget.occurrenceId;

  @override
  void initState() {
    super.initState();
    widget.tracker._register(this);
  }

  @override
  void didUpdateWidget(covariant HomeExposureDetector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tracker != widget.tracker ||
        oldWidget.occurrenceId != widget.occurrenceId) {
      oldWidget.tracker._unregister(this);
      widget.tracker._register(this);
    } else {
      widget.tracker.scheduleCheck();
    }
  }

  @override
  void dispose() {
    widget.tracker._unregister(this);
    super.dispose();
  }

  bool isVisibleIn(Rect viewportRect) {
    if (!mounted) {
      return false;
    }
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      return false;
    }
    final itemRect =
        renderObject.localToGlobal(Offset.zero) & renderObject.size;
    final intersection = itemRect.intersect(viewportRect);
    return intersection.width > 0 && intersection.height > 0;
  }

  void onVisible() => widget.onVisible();

  @override
  Widget build(BuildContext context) => widget.child;
}
