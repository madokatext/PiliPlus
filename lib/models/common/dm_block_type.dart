enum DmBlockType {
  keyword('关键词，CPU 都看沉默了'),
  regex('正则，这把高端局'),
  uid('赛博居民'),
  ;

  final String label;
  const DmBlockType(this.label);
}
