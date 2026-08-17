enum UserOrderType {
  def('祖传默认排序', 0, ''),
  fansDesc('粉丝数由高到低，属实绷不住', 0, 'fans'),
  fansAsc('粉丝数由低到高，功德+1', 1, 'fans'),
  levelDesc('Lv等级由高到低，CPU 都看沉默了', 0, 'level'),
  levelAsc('Lv等级由低到高，启动！', 1, 'level'),
  ;

  final String label;
  final int orderSort;
  final String order;
  const UserOrderType(this.label, this.orderSort, this.order);
}

enum UserType {
  all('我全都要赛博居民'),
  up('UP主，我嘞个豆'),
  common('普通赛博居民'),
  verified('认证赛博居民'),
  ;

  final String label;
  const UserType(this.label);
}
