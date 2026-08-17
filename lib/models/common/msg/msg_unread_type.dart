enum MsgUnReadType {
  pm('私信，CPU 都看沉默了'),
  reply('来找我对线的'),
  at('@我，不是哥们'),
  like('收到的大拇哥'),
  sysMsg('系统催命符'),
  ;

  final String title;
  const MsgUnReadType(this.title);
}
