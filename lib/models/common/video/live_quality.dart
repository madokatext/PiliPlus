enum LiveQuality {
  dolby(30000, '杜比，启动！'),
  origin4K(25000, '4K 原画，曼波'),
  super4K(20000, '4K'),
  super2K(15000, '2K'),
  origin(10000, '原画，功德+1'),
  bluRay(400, '蓝光，包的'),
  superHD(250, '超清，包的'),
  smooth(150, '高清，我嘞个豆'),
  flunt(80, '流畅，已老实'),
  ;

  final int code;
  final String desc;
  const LiveQuality(this.code, this.desc);

  static LiveQuality? fromCode(int? code) {
    for (final e in LiveQuality.values) {
      if (e.code == code) {
        return e;
      }
    }
    return null;
  }
}
