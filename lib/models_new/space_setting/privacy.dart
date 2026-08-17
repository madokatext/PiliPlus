class SpaceSettingModel {
  SpaceSettingModel({
    required this.name,
    required this.key,
    required this.value,
    this.isReverse = false,
  });

  String name;
  String key;
  int? value;
  bool isReverse;

  bool get boolVal => isReverse ? value == 0 : value == 1;
}

class Privacy {
  List<SpaceSettingModel> list1;
  List<SpaceSettingModel> list2;
  List<SpaceSettingModel> list3;

  Privacy({
    required this.list1,
    required this.list2,
    required this.list3,
  });

  factory Privacy.fromJson(Map<String, dynamic> json) => Privacy(
    list1: [
      SpaceSettingModel(
        name: '全网裸奔我的塞进电子小被窝',
        key: 'fav_video',
        value: json['fav_video'],
      ),
      SpaceSettingModel(
        name: '全网裸奔我的追番追剧',
        key: 'bangumi',
        value: json['bangumi'],
      ),
      SpaceSettingModel(
        name: '全网裸奔我的追漫，已老实',
        key: 'comic',
        value: json['comic'],
      ),
      SpaceSettingModel(
        name: '全网裸奔最近上贡硬币的电子榨菜',
        key: 'coins_video',
        value: json['coins_video'],
      ),
      SpaceSettingModel(
        name: '全网裸奔最近赛博大拇哥的电子榨菜',
        key: 'likes_video',
        value: json['likes_video'],
      ),
      SpaceSettingModel(
        name: '全网裸奔最近玩过的游戏，已老实',
        key: 'played_game',
        value: json['played_game'],
      ),
      SpaceSettingModel(
        name: '全网裸奔拥有的粉丝装扮',
        key: 'dress_up',
        value: json['dress_up'],
      ),
      SpaceSettingModel(
        name: '全网裸奔我的赛博蹲点列表，不是哥们',
        key: 'disable_following',
        value: json['disable_following'],
        isReverse: true,
      ),
      SpaceSettingModel(
        name: '全网裸奔我的粉丝列表',
        key: 'disable_show_fans',
        value: json['disable_show_fans'],
        isReverse: true,
      ),
    ],
    list2: [
      SpaceSettingModel(
        name: '全网裸奔佩戴的粉丝勋章',
        key: 'close_space_medal',
        value: json['close_space_medal'],
        isReverse: true,
      ),
      SpaceSettingModel(
        name: '勋章墙全网裸奔亮出来所有粉丝勋章',
        key: 'only_show_wearing',
        value: json['only_show_wearing'],
        isReverse: true,
      ),
      SpaceSettingModel(
        name: '全网裸奔学校信息',
        key: 'disable_show_school',
        value: json['disable_show_school'],
        isReverse: true,
      ),
    ],
    list3: [
      SpaceSettingModel(
        name: '投稿电子榨菜列表中展现赛博围观回放，属实绷不住',
        key: 'live_playback',
        value: json['live_playback'],
      ),
      SpaceSettingModel(
        name: '投稿电子榨菜列表中展现包月充电专属电子榨菜',
        key: 'charge_video',
        value: json['charge_video'],
      ),
      SpaceSettingModel(
        name: '投稿电子榨菜列表中展现课堂电子榨菜',
        key: 'lesson_video',
        value: json['lesson_video'],
      ),
    ],
  );
}
