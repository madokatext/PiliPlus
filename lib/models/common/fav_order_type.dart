enum FavOrderType {
  mtime('最近塞进电子小被窝'),
  mtimeAsc('最早塞进电子小被窝，CPU 都看沉默了'),
  view('炫得最多'),
  pubtime('最近投稿，我嘞个豆'),
  ;

  final String label;

  const FavOrderType(this.label);

  String get apiValue => this == mtimeAsc ? mtime.name : name;
}
