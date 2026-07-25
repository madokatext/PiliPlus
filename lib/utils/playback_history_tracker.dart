import 'dart:async';

import 'package:PiliPlus/utils/recommend_history.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:synchronized/synchronized.dart';
import 'package:uuid/uuid.dart';

class PlaybackHistoryTracker {
  static final PlaybackHistoryTracker instance = PlaybackHistoryTracker._(
    () => RecommendHistoryRepository.instance,
  );

  final RecommendHistoryRepository Function() _repository;
  final Lock _lock = Lock();
  final Uuid _uuid = const Uuid();

  String? _sessionId;
  int _persistedMs = 0;
  int _unpersistedMs = 0;
  bool _ended = false;
  final Stopwatch _activeStopwatch = Stopwatch();
  Timer? _checkpointTimer;
  Timer? _thresholdTimer;

  PlaybackHistoryTracker._(this._repository);

  Future<void> begin({
    required String scopeId,
    required String videoKey,
    required bool active,
    DateTime? firstFrameAt,
  }) => _lock.synchronized(() async {
    await _endLocked();
    final sessionId = _uuid.v4();
    _sessionId = sessionId;
    _persistedMs = 0;
    _unpersistedMs = 0;
    _ended = false;
    await _repository().createPlaySession(
      scopeId: scopeId,
      sessionId: sessionId,
      videoKey: videoKey,
      firstFrameAt: firstFrameAt ?? DateTime.now(),
    );
    if (active) {
      _startActiveTimers();
    }
  });

  Future<void> setActive(bool active) => _lock.synchronized(() async {
    if (_sessionId == null || _ended) {
      return;
    }
    if (active) {
      if (!_activeStopwatch.isRunning && _totalMs < 300000) {
        _startActiveTimers();
      }
    } else if (_activeStopwatch.isRunning) {
      _captureElapsed();
      _cancelTimers();
      await _checkpointLocked();
    }
  });

  Future<void> checkpoint() => _lock.synchronized(_checkpointLocked);

  Future<void> end() => _lock.synchronized(_endLocked);

  Future<void> flush() async {
    await checkpoint();
    await _repository().flush();
  }

  int get _totalMs => (_persistedMs + _unpersistedMs).clamp(0, 300000);

  void _startActiveTimers() {
    _activeStopwatch
      ..reset()
      ..start();
    _checkpointTimer?.cancel();
    _checkpointTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(checkpoint()),
    );
    _scheduleThresholdCheckpoint();
  }

  void _scheduleThresholdCheckpoint() {
    _thresholdTimer?.cancel();
    final thresholdMs =
        Pref.recommendHistoryFilterSettings.minWatchSeconds * 1000;
    final remainingMs = thresholdMs - _totalMs;
    if (thresholdMs > 0 && remainingMs > 0) {
      _thresholdTimer = Timer(
        Duration(milliseconds: remainingMs),
        () => unawaited(checkpoint()),
      );
    }
  }

  void _captureElapsed() {
    if (!_activeStopwatch.isRunning) {
      return;
    }
    _activeStopwatch.stop();
    _unpersistedMs = (_unpersistedMs + _activeStopwatch.elapsedMilliseconds)
        .clamp(0, 300000 - _persistedMs)
        .toInt();
    _activeStopwatch.reset();
  }

  Future<void> _checkpointLocked({bool ended = false}) async {
    final sessionId = _sessionId;
    if (sessionId == null || _ended) {
      return;
    }

    final resume = _activeStopwatch.isRunning && !ended;
    _captureElapsed();
    final total = _totalMs;
    await _repository().updatePlaySession(
      sessionId: sessionId,
      activePlayedMs: total,
      ended: ended,
    );
    _persistedMs = total;
    _unpersistedMs = 0;

    if (total >= 300000 || ended) {
      _cancelTimers();
      _ended = ended;
      return;
    }
    if (resume) {
      _activeStopwatch.start();
      _scheduleThresholdCheckpoint();
    }
  }

  Future<void> _endLocked() async {
    if (_sessionId != null && !_ended) {
      await _checkpointLocked(ended: true);
    }
    _cancelTimers();
    _activeStopwatch
      ..stop()
      ..reset();
    _sessionId = null;
    _persistedMs = 0;
    _unpersistedMs = 0;
    _ended = false;
  }

  void _cancelTimers() {
    _checkpointTimer?.cancel();
    _checkpointTimer = null;
    _thresholdTimer?.cancel();
    _thresholdTimer = null;
  }
}
