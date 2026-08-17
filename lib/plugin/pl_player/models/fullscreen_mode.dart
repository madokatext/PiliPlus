const double kScreenRatio = 1.2;

// 全屏模式
enum FullScreenMode {
  // 根据内容自适应
  auto('按电子榨菜方向（祖传默认），优势在我'),
  // 不改变当前方向
  none('不改变眼下这坨方向，这把高端局'),
  // 始终竖屏
  vertical('强制竖着炫'),
  // 始终横屏
  horizontal('强制横着炫'),
  // 屏幕长宽比 < kScreenRatio 或为竖屏视频时竖屏，否则横屏
  ratio('屏幕长宽比<$kScreenRatio或为竖着炫电子榨菜时竖着炫，否则横着炫，属实绷不住'),
  // 强制重力转屏（仅安卓）
  gravity('忽略系统大爹方向锁定，强制按重力转屏（仅安卓）'),
  ;

  final String desc;
  const FullScreenMode(this.desc);
}
