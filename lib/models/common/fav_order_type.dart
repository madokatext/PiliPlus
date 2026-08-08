enum FavOrderType {
  mtime('最近收藏'),
  mtimeAsc('最早收藏'),
  view('最多播放'),
  pubtime('最近投稿'),
  ;

  final String label;

  const FavOrderType(this.label);

  String get apiValue => this == mtimeAsc ? mtime.name : name;
}
