enum ReplySortType {
  time('最新赛博锐评', '刚出锅', text: '按时间，已老实'),
  hot('最热赛博锐评', '最热，不是哥们', text: '按热度，属实绷不住'),
  select('精选赛博锐评', '精选，曼波'),
  ;

  final String title;
  final String label;
  final String? text;
  const ReplySortType(this.title, this.label, {this.text});
}
