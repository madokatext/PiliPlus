enum SubtitlePrefType {
  off('祖传默认不亮出来字幕'),
  on('优先抓一个非全自动赛博生成(ai)字幕'),
  withoutAi('跳过全自动赛博生成(ai)字幕，抓一个第一个可用字幕'),
  auto('静音时等同第二项，非静音时等同第三项，这把高端局'),
  ;

  final String desc;
  const SubtitlePrefType(this.desc);
}
