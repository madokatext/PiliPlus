import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrintSynchronously;

/// Release-build Android diagnostics. Callers must only pass state, counters
/// and opaque IDs, never media URLs, route arguments or exception messages.
abstract final class StartupLog {
  static bool get enabled => Platform.isAndroid;
  static int _sequence = 0;
  static const _prefix = '[PiliPlusStartup] ';
  static const _maxBytes = 900;

  static List<String> callers([StackTrace? stackTrace]) {
    if (!enabled) return const [];
    return (stackTrace ?? StackTrace.current).toString().split('\n').where((line) {
      return line.contains('package:PiliPlus/') &&
          !line.contains('startup_log.dart') &&
          !line.contains('._logStartup ');
    }).take(3).map((line) {
      final trimmed = line.trim();
      return trimmed.length > 160 ? trimmed.substring(0, 160) : trimmed;
    }).toList();
  }

  static void write(
    String layer,
    String event,
    Map<String, Object?> fields,
  ) {
    if (!enabled) return;
    try {
      final header = <String, Object?>{
        'layer': layer,
        'event': event,
        'time': DateTime.now().toIso8601String(),
        'seq': ++_sequence,
      };
      String encode(Map<String, Object?> part, int index, int count) =>
          '$_prefix${jsonEncode({
            ...header,
            'part': index,
            'parts': count,
            ...part,
          })}';
      bool fits(Map<String, Object?> part) =>
          utf8.encode(encode(part, 9999, 9999)).length <= _maxBytes;

      // Keep each line valid JSON and repeat the identity on every part.
      // The previous single-line records were cut off by Android's logger.
      final parts = <Map<String, Object?>>[];
      var part = <String, Object?>{};
      for (final entry in fields.entries) {
        Object? value = entry.value;
        if (!fits({entry.key: value})) {
          value = {
            'omittedOversizedField': true,
            'encodedBytes': utf8.encode(jsonEncode(value)).length,
          };
        }
        final next = {...part, entry.key: value};
        if (part.isNotEmpty && !fits(next)) {
          parts.add(part);
          part = {};
        }
        part[entry.key] = value;
      }
      if (part.isNotEmpty || parts.isEmpty) parts.add(part);
      for (var i = 0; i < parts.length; i++) {
        debugPrintSynchronously(encode(parts[i], i + 1, parts.length));
      }
    } catch (_) {
      // Logging must not change playback or error propagation.
    }
  }
}
