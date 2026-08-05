enum SteinProgressDebugLevel { info, success, warning, error }

class SteinProgressDebugEvent {
  const SteinProgressDebugEvent({
    required this.time,
    required this.stage,
    required this.detail,
    required this.level,
  });

  final DateTime time;
  final String stage;
  final String detail;
  final SteinProgressDebugLevel level;
}
