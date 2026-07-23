enum DanmakuMergeMode {
  off('不合并'),
  segment('旧式分段合并'),
  burst('高频置顶合并');

  const DanmakuMergeMode(this.label);

  final String label;
}
