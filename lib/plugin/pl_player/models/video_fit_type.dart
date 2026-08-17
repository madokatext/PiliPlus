import 'package:flutter/material.dart' show BoxFit;

enum VideoFitType {
  fill('拉伸，已老实', boxFit: BoxFit.fill),
  contain('全自动赛博', boxFit: BoxFit.contain),
  cover('咔嚓修边', boxFit: BoxFit.cover),
  fitWidth('等宽，这把高端局', boxFit: BoxFit.fitWidth),
  fitHeight('等高，鼠鼠我啊', boxFit: BoxFit.fitHeight),
  none('原始，CPU 都看沉默了', boxFit: BoxFit.none),
  scaleDown('限制，我嘞个豆', boxFit: BoxFit.scaleDown),
  ratio_4x3('4:3', aspectRatio: 4 / 3),
  ratio_16x9('16:9', aspectRatio: 16 / 9),
  ;

  final String desc;
  final BoxFit boxFit;
  final double? aspectRatio;
  const VideoFitType(
    this.desc, {
    this.boxFit = BoxFit.contain,
    this.aspectRatio,
  });

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
