enum VideoFitType {
  fill('拉伸'),
  contain('自动'),
  cover('裁剪'),
  fitWidth('等宽'),
  fitHeight('等高'),
  none('原始'),
  scaleDown('限制'),
  ratio_4x3('4:3', aspectRatio: 4 / 3),
  ratio_16x9('16:9', aspectRatio: 16 / 9),
  ;

  final String desc;
  final double? aspectRatio;
  const VideoFitType(this.desc, {this.aspectRatio});

  String mpvPanscan(double sourceAspectRatio, double viewportAspectRatio) {
    final crop = switch (this) {
      VideoFitType.cover => true,
      VideoFitType.fitWidth => sourceAspectRatio < viewportAspectRatio,
      VideoFitType.fitHeight => sourceAspectRatio > viewportAspectRatio,
      _ => false,
    };
    return crop ? '1.0' : '0.0';
  }

  String get mpvVideoUnscaled => switch (this) {
    VideoFitType.none => 'yes',
    VideoFitType.scaleDown => 'downscale-big',
    _ => 'no',
  };

  String mpvAspectOverride(double viewportAspectRatio) => switch (this) {
    VideoFitType.fill => viewportAspectRatio.toString(),
    VideoFitType.ratio_4x3 => '4:3',
    VideoFitType.ratio_16x9 => '16:9',
    _ => 'no',
  };
}
