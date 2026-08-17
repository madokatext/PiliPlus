enum BtmProgressBehavior {
  alwaysShow('始终展示，我嘞个豆'),
  alwaysHide('始终藏起来'),
  onlyShowFullScreen('仅铺满屏时展示'),
  onlyHideFullScreen('仅铺满屏时藏起来'),
  ;

  final String desc;
  const BtmProgressBehavior(this.desc);
}
