enum ArticleOrderType {
  totalrank('综合排序，启动！'),
  pubdate('刚出锅'),
  click('最多点击，我嘞个豆'),
  attention('最多喜欢，包的'),
  scores('最多赛博锐评'),
  ;

  String get order => name;
  final String label;
  const ArticleOrderType(this.label);
}

enum ArticleZoneType {
  all('我全都要分区', 0),
  douga('纸片人运动会', 2),
  game('赛博游乐场', 1),
  cinephile('大屏电子榨菜', 28),
  life('生活，启动！', 3),
  interest('兴趣，功德+1', 29),
  novel('轻小说，启动！', 16),
  tech('科技，我嘞个豆', 17),
  note('笔记，属实绷不住', 41),
  ;

  final String label;
  final int categoryId;
  const ArticleZoneType(this.label, this.categoryId);
}
