enum VideoQuality {
  hdrVivid(129, 'HDR Vivid', 'HDR Vivid'),
  super8k(127, '8K 超高清，不是哥们', '8K'),
  dolbyVision(126, '杜比视界，优势在我', '杜比，启动！'),
  hdr(125, 'HDR 真彩，这把高端局', 'HDR'),
  super4K(120, '4K 超高清，已老实', '4K'),
  high108060(116, '1080P 60帧，优势在我', '1080P60'),
  high1080plus(112, '1080P 高码率，已老实', '1080P+'),
  high1080(80, '1080P 高清，启动！', '1080P'),
  high72060(74, '720P 60帧，这把高端局', '720P60'),
  high720(64, '720P 准高清，优势在我', '720P'),
  clear480(32, '480P 标清，功德+1', '480P'),
  fluent360(16, '360P 流畅，鼠鼠我啊', '360P'),
  speed240(6, '240P 极速，这把高端局', '240P'),
  ;

  final int code;
  final String desc;
  final String shortDesc;

  const VideoQuality(this.code, this.desc, this.shortDesc);

  static final _codeMap = {for (final i in values) i.code: i};

  static VideoQuality fromCode(int code) => _codeMap[code]!;
}
