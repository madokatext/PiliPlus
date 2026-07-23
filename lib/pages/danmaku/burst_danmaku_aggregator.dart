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
  ),
);

    entry.lastSeenMs = progressMs;

    if (entry.active) {
      entry.displayCount++;
      return true;
    }

    final windowStart = progressMs - windowMs;

_pruneSamples(
  entry,
  windowStart,
);

entry.samples.addLast(
  _BurstDanmakuSample(
    timestampMs: progressMs,
    color: color,
  ),
);
    if (entry.samples.length >= triggerCount) {
  // 只在首次触发时计算一次颜色众数。
  entry.color = _resolveModeColor(
    entry.samples,
  );

  entry.active = true;
  entry.activatedAtMs = progressMs;
  entry.displayCount = entry.samples.length;

  // 颜色已经锁定，之后不再需要保留触发前样本。
  entry.samples.clear();

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

_pruneSamples(
  entry,
  windowStart,
);

if (entry.samples.isEmpty) {
  removeKeys.add(entry.text);
}
    }

    for (final key in removeKeys) {
      _entries.remove(key);
    }

    return visibleChanged;
  }
static void _pruneSamples(
  _BurstDanmakuEntry entry,
  int windowStartMs,
) {
  while (entry.samples.isNotEmpty &&
      entry.samples.first.timestampMs < windowStartMs) {
    entry.samples.removeFirst();
  }
}

/// 计算触发窗口内的颜色众数。
///
/// 如果多个颜色计数相同，则选择窗口中最早出现的颜色。
static Color _resolveModeColor(
  Iterable<_BurstDanmakuSample> samples,
) {
  final colorCounts = <Color, int>{};

  for (final sample in samples) {
    colorCounts.update(
      sample.color,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
  }

  var maxCount = 0;

  for (final count in colorCounts.values) {
    if (count > maxCount) {
      maxCount = count;
    }
  }

  // 再按时间顺序扫描一次。
  // 第一个达到最大计数的颜色即为并列众数中的最早颜色。
  for (final sample in samples) {
    if (colorCounts[sample.color] == maxCount) {
      return sample.color;
    }
  }

  throw StateError(
    'Cannot resolve burst danmaku color from empty samples.',
  );
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
  });

  final String text;

  /// 仅保存尚未触发时，当前统计窗口内的弹幕样本。
  final Queue<_BurstDanmakuSample> samples =
      Queue<_BurstDanmakuSample>();

  /// 首次达到触发阈值时确定，之后永久不再修改。
  late final Color color;

  int lastSeenMs = 0;
  int activatedAtMs = 0;
  int displayCount = 0;
  bool active = false;
}

class _BurstDanmakuSample {
  const _BurstDanmakuSample({
    required this.timestampMs,
    required this.color,
  });

  final int timestampMs;
  final Color color;
}
