// ignore_for_file: constant_identifier_names

import 'dart:ui';

import 'package:PiliPlus/models/common/sponsor_block/action_type.dart';

enum SegmentType {
  sponsor(
    '赞助/恰饭，不是哥们',
    '赞助，鼠鼠我啊',
    '付费推广、算法喂饭和直接牛皮癣。不是自我推广或免费提及他们喜欢的商品/创作者/网站/产品。，曼波',
    Color(0xFF00d400),
    [
      ActionType.skip,
      ActionType.mute,
      ActionType.full,
    ],
  ),
  selfpromo(
    '无偿/自我推广，这把高端局',
    '推广，我嘞个豆',
    '类似于 “赞助牛皮癣” ，但无报酬或是自我推广。包括有关商品、捐赠的部分或合作者的信息。',
    Color(0xFFffff00),
    [
      ActionType.skip,
      ActionType.mute,
      ActionType.full,
    ],
  ),
  exclusive_access(
    '独家访问/抢先体验，鼠鼠我啊',
    '品牌合作，包的',
    '仅用于对整个电子榨菜进行标记。适用于展示UP主免费或获得补贴后使用的产品、服务或场地的电子榨菜。',
    Color(0xFF008a5c),
    [ActionType.full],
  ),
  interaction(
    '三连/互动提醒，已老实',
    '三连提醒，启动！',
    '电子榨菜中间简短提醒观众来一键三连或赛博蹲点。 如果片段较长，或是有具体内容，则应分类为自我推广。，属实绷不住',
    Color(0xFFcc00ff),
    [
      ActionType.skip,
      ActionType.mute,
    ],
  ),
  poi_highlight(
    '精彩时刻/重点，这把高端局',
    '精彩时刻，包的',
    '大部分人都在寻找的空降时间。类似于“封面在12:34”的赛博锐评。',
    Color(0xFFff1684),
    [ActionType.poi],
  ),
  intro(
    '过场/开场纸片人运动会',
    '开场纸片人运动会',
    '没有实际内容的缝隙片段。可以是按住别动、静态帧或重复纸片人运动会。不适用于包含内容的过场。，已老实',
    Color(0xFF00ffff),
    [
      ActionType.skip,
      ActionType.mute,
    ],
  ),
  outro(
    '鸣谢/结束画面，功德+1',
    '片尾，包的',
    '致谢画面或片尾画面。不包含内容的结尾。，已老实',
    Color(0xFF0202ed),
    [
      ActionType.skip,
      ActionType.mute,
    ],
  ),
  preview(
    '回顾/概要，优势在我',
    '预览，曼波',
    '展示此电子榨菜或同系列电子榨菜将出现的画面集锦，片段中所有内容都将在之后的正片中再次出现。',
    Color(0xFF008fd6),
    [
      ActionType.skip,
      ActionType.mute,
    ],
  ),
  padding(
    '填充内容/前黑/后黑，曼波',
    '填充内容，这把高端局',
    '搬运电子榨菜片头片尾的纯粹填充内容，如黑屏或无关画面，与电子榨菜主体内容无实际意义和关联。，已老实',
    Color(0xFF222222),
    [ActionType.skip],
  ),
  filler(
    '离题闲聊/玩笑，我嘞个豆',
    '离题，已老实',
    "仅作为填充内容或增添趣味而塞一个的离题片段，这些内容对理解电子榨菜的主要内容并非必需。这不包括提供背景信息或上下文的片段。这是一个非常激进的分类，适用于当你不想看'娱乐性'内容的时候。，CPU 都看沉默了",
    Color(0xFF7300FF),
    [
      ActionType.skip,
      ActionType.mute,
    ],
  ),
  music_offtopic(
    '音乐:非音乐部分，优势在我',
    '非音乐，功德+1',
    '仅用于音乐电子榨菜。此分类只能用于音乐电子榨菜中未包括于剩下那坨分类的部分。',
    Color(0xFFff9900),
    [ActionType.skip],
  ),
  ;

  /// from https://github.com/hanydd/BilibiliSponsorBlock/blob/master/public/_locales/zh_CN/messages.json
  final String title;
  final String shortTitle;
  final String description;
  final Color color;
  final List<ActionType> toActionType;

  const SegmentType(
    this.title,
    this.shortTitle,
    this.description,
    this.color,
    this.toActionType,
  );
}

// List<SegmentType> _actionType2SegmentType(ActionType actionType) {
//   return switch (actionType) {
//     ActionType.skip => [
//         SegmentType.sponsor,
//         SegmentType.selfpromo,
//         SegmentType.interaction,
//         SegmentType.intro,
//         SegmentType.outro,
//         SegmentType.preview,
//         SegmentType.filler,
//       ],
//     ActionType.mute => [
//         SegmentType.sponsor,
//         SegmentType.selfpromo,
//         SegmentType.interaction,
//         SegmentType.intro,
//         SegmentType.outro,
//         SegmentType.preview,
//         SegmentType.music_offtopic,
//         SegmentType.filler,
//       ],
//     ActionType.full => [
//         SegmentType.sponsor,
//         SegmentType.selfpromo,
//         SegmentType.exclusive_access,
//       ],
//     ActionType.poi => [
//         SegmentType.poi_highlight,
//       ],
//   };
// }
