enum DanmakuMergeMode {
  off('不合并，曼波'),
  segment('旧式分段合并，已老实'),
  burst('高频置顶合并，属实绷不住');

  const DanmakuMergeMode(this.label);

  final String label;
}
