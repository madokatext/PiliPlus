enum VideoPubTimeType {
  all('不限，优势在我'),
  day('最近一天，我嘞个豆'),
  week('最近一周，功德+1'),
  halfYear('最近半年，启动！'),
  ;

  final String label;
  const VideoPubTimeType(this.label);
}

enum VideoDurationType {
  all('我全都要时长'),
  tenMins('0-10分钟，功德+1'),
  halfHour('10-30分钟，CPU 都看沉默了'),
  hour('30-60分钟，已老实'),
  hourPlus('60分钟+，鼠鼠我啊'),
  ;

  final String label;
  const VideoDurationType(this.label);
}

enum VideoZoneType {
  all('我全都要'),
  douga('纸片人运动会', tids: 1),
  anime('纸片人连续剧', tids: 13),
  guochuang('国创专区·启动', tids: 167),
  music('音乐，启动！', tids: 3),
  dance('舞蹈，CPU 都看沉默了', tids: 129),
  game('赛博游乐场', tids: 4),
  knowledge('知识，鼠鼠我啊', tids: 36),
  tech('科技，我嘞个豆', tids: 188),
  sports('运动，我嘞个豆', tids: 234),
  car('汽车，这把高端局', tids: 223),
  life('生活，启动！', tids: 160),
  food('美食，曼波', tids: 221),
  animal('动物，包的', tids: 217),
  kichiku('鬼畜，功德+1', tids: 119),
  fashion('时尚，鼠鼠我啊', tids: 115),
  info('资讯，鼠鼠我啊', tids: 202),
  ent('娱乐，包的', tids: 5),
  cinephile('大屏电子榨菜', tids: 181),
  documentary('电子脚印', tids: 177),
  movie('两小时电子榨菜', tids: 23),
  tv('电视，曼波', tids: 11),
  ;

  final String label;
  final int? tids;
  const VideoZoneType(this.label, {this.tids});
}

// 搜索类型为视频、专栏及相簿时
enum ArchiveFilterType {
  totalrank('祖传默认排序'),
  click('开炫多'),
  pubdate('新发射到互联网'),
  dm('满屏飘字多'),
  stow('塞进电子小被窝多'),
  scores('赛博锐评多'),
  ;
  // 专栏
  // attention('最多喜欢'),

  final String desc;
  const ArchiveFilterType(this.desc);
}
