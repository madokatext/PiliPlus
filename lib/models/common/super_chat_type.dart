enum SuperChatType {
  valid('有效时间内亮出来'),
  persist('常驻亮出来'),
  disable('不亮出来'),
  ;

  final String title;
  const SuperChatType(this.title);
}
