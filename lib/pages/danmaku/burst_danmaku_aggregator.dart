import 'dart:collection';

import 'package:flutter/material.dart';

class BurstDanmakuSnapshot {
  const BurstDanmakuSnapshot({
    required this.text,
    required this.color,
    required this.count,
    required this.activatedAtMs,
  });

  final String text;
  final Color color;
  final int count;
  final int activatedAtMs;
}

class BurstDanmakuAggregator {
  final Map<String, _BurstDanmakuEntry> _entries = {};

  bool get isEmpty => _entries.isEmpty;

  /// 添加一条弹幕。
  ///
  /// 返回 true 表示该条弹幕应被普通画布抑制：
  /// - 当前条刚好触发高频合并；
  /// - 或该内容已经处于高频合并状态。
  bool add({
    required String text,
    required Color color,
    required int progressMs,
    required int triggerCount,
    required int windowMs,
  }) {
    if (text.isEmpty) {
      return false;
    }

    final entry = _entries.putIfAbsent(
      text,
      () => _BurstDanmakuEntry(
        text: text,
        color: color,
      ),
    );

    entry.lastSeenMs = progressMs;

    if (entry.active) {
      entry.displayCount++;
      return true;
    }

    final windowStart = progressMs - windowMs;

    while (entry.timestamps.isNotEmpty &&
        entry.timestamps.first < windowStart) {
      entry.timestamps.removeFirst();
    }

    entry.timestamps.addLast(progressMs);

    if (entry.timestamps.length >= triggerCount) {
      entry.active = true;
      entry.activatedAtMs = progressMs;
      entry.displayCount = entry.timestamps.length;
      return true;
    }

    return false;
  }

  /// 推进播放时间并清理过期状态。
  ///
  /// 返回 true 表示当前顶部显示列表发生了变化。
  bool advance({
    required int progressMs,
    required int windowMs,
    required int cooldownMs,
  }) {
    var visibleChanged = false;
    final removeKeys = <String>[];

    for (final entry in _entries.values) {
      if (entry.active) {
        if (progressMs - entry.lastSeenMs >= cooldownMs) {
          removeKeys.add(entry.text);
          visibleChanged = true;
        }
        continue;
      }

      final windowStart = progressMs - windowMs;

      while (entry.timestamps.isNotEmpty &&
          entry.timestamps.first < windowStart) {
        entry.timestamps.removeFirst();
      }

      if (entry.timestamps.isEmpty) {
        removeKeys.add(entry.text);
      }
    }

    for (final key in removeKeys) {
      _entries.remove(key);
    }

    return visibleChanged;
  }

  List<BurstDanmakuSnapshot> get activeSnapshots {
    final result = _entries.values
        .where((entry) => entry.active)
        .map(
          (entry) => BurstDanmakuSnapshot(
            text: entry.text,
            color: entry.color,
            count: entry.displayCount,
            activatedAtMs: entry.activatedAtMs,
          ),
        )
        .toList();

    result.sort(
      (a, b) => a.activatedAtMs.compareTo(b.activatedAtMs),
    );

    return List.unmodifiable(result);
  }

  void reset() {
    _entries.clear();
  }
}

class _BurstDanmakuEntry {
  _BurstDanmakuEntry({
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  final Queue<int> timestamps = Queue<int>();

  int lastSeenMs = 0;
  int activatedAtMs = 0;
  int displayCount = 0;
  bool active = false;
}
