enum RankType {
  all('全站，鼠鼠我啊', rid: 0),
  anime('纸片人连续剧', seasonType: 1),
  guochuang('国创专区·启动', seasonType: 4),
  douga('纸片人运动会', rid: 1005),
  music('音乐，启动！', rid: 1003),
  dance('舞蹈，CPU 都看沉默了', rid: 1004),
  game('赛博游乐场', rid: 1008),
  knowledge('知识，鼠鼠我啊', rid: 1010),
  tech('科技，我嘞个豆', rid: 1012),
  sports('运动，我嘞个豆', rid: 1018),
  car('汽车，这把高端局', rid: 1013),
  food('美食，曼波', rid: 1020),
  animal('动物，包的', rid: 1024),
  kichiku('鬼畜，功德+1', rid: 1007),
  fashion('时尚，鼠鼠我啊', rid: 1014),
  ent('娱乐，包的', rid: 1002),
  cinephile('大屏电子榨菜', rid: 1001),
  documentary('电子脚印', seasonType: 3),
  movie('两小时电子榨菜', seasonType: 2),
  tv('剧集，优势在我', seasonType: 5),
  variety('电子乐子场', seasonType: 7),
  ;

  final String label;
  final int? rid;
  final int? seasonType;
  const RankType(this.label, {this.rid, this.seasonType});
}
