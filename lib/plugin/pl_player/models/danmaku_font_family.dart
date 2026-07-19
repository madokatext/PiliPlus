enum DanmakuFontFamily {
  system('', '系统默认'),
  sansSerif('sans-serif', '通用无衬线体'),
  serif('serif', '通用衬线体'),
  monospace('monospace', '通用等宽字体'),
  cursive('cursive', '通用手写体'),
  roboto('Roboto', 'Roboto'),
  notoSans('Noto Sans', 'Noto Sans'),
  notoSansCjkSc('Noto Sans CJK SC', '思源黑体（Noto Sans CJK SC）'),
  sourceHanSansSc('Source Han Sans SC', '思源黑体（Source Han Sans SC）'),
  notoSerifCjkSc('Noto Serif CJK SC', '思源宋体（Noto Serif CJK SC）'),
  sourceHanSerifSc('Source Han Serif SC', '思源宋体（Source Han Serif SC）'),
  harmonyOsSansSc('HarmonyOS Sans SC', 'HarmonyOS Sans SC'),
  miSans('MiSans', 'MiSans'),
  pingFangSc('PingFang SC', '苹方'),
  microsoftYaHei('Microsoft YaHei', '微软雅黑'),
  dengXian('DengXian', '等线'),
  simHei('SimHei', '黑体'),
  simSun('SimSun', '宋体'),
  kaiTi('KaiTi', '楷体'),
  fangSong('FangSong', '仿宋'),
  arial('Arial', 'Arial'),
  segoeUi('Segoe UI', 'Segoe UI'),
  helvetica('Helvetica', 'Helvetica'),
  helveticaNeue('Helvetica Neue', 'Helvetica Neue'),
  verdana('Verdana', 'Verdana'),
  tahoma('Tahoma', 'Tahoma'),
  georgia('Georgia', 'Georgia'),
  timesNewRoman('Times New Roman', 'Times New Roman'),
  courierNew('Courier New', 'Courier New'),
  comicSansMs('Comic Sans MS', 'Comic Sans MS'),
  ubuntu('Ubuntu', 'Ubuntu');

  const DanmakuFontFamily(this.value, this.label);

  final String value;
  final String label;

  static DanmakuFontFamily fromValue(String value) => values.firstWhere(
    (item) => item.value == value,
    orElse: () => system,
  );
}
