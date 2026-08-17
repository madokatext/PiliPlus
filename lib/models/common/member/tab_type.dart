import 'package:PiliPlus/utils/storage_pref.dart';

enum MemberTabType {
  def('祖传默认'),
  home('主页，CPU 都看沉默了'),
  dynamic('互联网近况'),
  contribute('赛博投递'),
  favorite('塞进电子小被窝'),
  bangumi('纸片人连续剧'),
  cheese('知识灌脑区'),
  shop('小店，曼波'),
  ;

  static bool showMemberShop = Pref.showMemberShop;

  static bool contains(String type) {
    if (type == shop.name && !showMemberShop) {
      return false;
    }
    for (final e in MemberTabType.values) {
      if (e.name == type) {
        return true;
      }
    }
    return false;
  }

  final String title;
  const MemberTabType(this.title);
}
