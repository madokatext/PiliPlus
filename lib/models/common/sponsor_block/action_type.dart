enum ActionType {
  skip('跳过，包的'),
  mute('静音，CPU 都看沉默了'),
  full('整个电子榨菜'),
  poi('精彩时刻，包的'),
  ;

  final String title;
  const ActionType(this.title);
}
