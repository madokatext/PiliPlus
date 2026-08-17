import 'package:PiliPlus/pages/fav/article/view.dart';
import 'package:PiliPlus/pages/fav/cheese/view.dart';
import 'package:PiliPlus/pages/fav/note/view.dart';
import 'package:PiliPlus/pages/fav/pgc/view.dart';
import 'package:PiliPlus/pages/fav/topic/view.dart';
import 'package:PiliPlus/pages/fav/video/view.dart';
import 'package:flutter/material.dart';

enum FavTabType {
  video('电子榨菜', FavVideoPage()),
  bangumi('电子追番', FavPgcPage(type: 1)),
  cinema('追剧，属实绷不住', FavPgcPage(type: 2)),
  article('赛博小作文', FavArticlePage()),
  note('笔记，属实绷不住', FavNotePage()),
  topic('话题，曼波', FavTopicPage()),
  cheese('知识灌脑区', FavCheesePage()),
  ;

  final String title;
  final Widget page;
  const FavTabType(this.title, this.page);
}
