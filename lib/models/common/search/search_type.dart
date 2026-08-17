// ignore_for_file: constant_identifier_names
enum SearchType {
  // all('综合'),
  // 视频：video
  video('电子榨菜'),
  // 番剧：media_bangumi,
  media_bangumi('纸片人连续剧'),
  // 影视：media_ft
  media_ft('大屏电子榨菜'),
  // 直播间及主播：live
  // live,
  // 直播间：live_room
  live_room('赛博围观房'),
  // 主播：live_user
  // live_user,
  // 话题：topic
  // topic,
  // 用户：bili_user
  bili_user('赛博居民'),
  // 专栏：article
  article('赛博小作文'),
  ;
  // 相簿：photo
  // photo

  final String label;
  const SearchType(this.label);
}
