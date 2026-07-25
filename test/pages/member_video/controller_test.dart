import 'package:PiliPlus/models/common/member/contribute_type.dart';
import 'package:PiliPlus/pages/member_video/controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('viewing a member video exits locate mode and updates the target', () {
    final controller = MemberVideoCtr(
      type: ContributeType.video,
      mid: 1,
      seasonId: null,
      seriesId: null,
    )
      ..fromViewAid = '100'
      ..isLocating.value = true;

    expect(controller.updateFromViewAid('200'), isTrue);
    expect(controller.fromViewAid, '200');
    expect(controller.isLocating.value, isFalse);
  });

  test('invalid member video aid keeps locate state unchanged', () {
    final controller = MemberVideoCtr(
      type: ContributeType.video,
      mid: 1,
      seasonId: null,
      seriesId: null,
    )
      ..fromViewAid = '100'
      ..isLocating.value = true;

    expect(controller.updateFromViewAid(null), isFalse);
    expect(controller.fromViewAid, '100');
    expect(controller.isLocating.value, isTrue);
  });
}
