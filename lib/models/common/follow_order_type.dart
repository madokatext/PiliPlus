enum FollowOrderType {
  def('', '最近赛博蹲点'),
  attention('attention', '最常访问，已老实'),
  ;

  final String type;
  final String title;

  const FollowOrderType(this.type, this.title);
}
