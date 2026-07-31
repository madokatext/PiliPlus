import 'package:PiliPlus/utils/default_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ships the portable phone settings as defaults', () {
    expect(defaultSettingValues['burstDanmakuCooldownSeconds'], 2.0);
    expect(defaultSettingValues['customPrimarySeed'], 4278205695);
    expect(defaultSettingValues['homeCardAspectRatio'], 'fourThree');
    expect(defaultSettingValues['showAdvancedSettings'], isFalse);
    expect(defaultSettingValues['useMpvVideoScaling'], isFalse);
    expect(defaultSettingValues['useRelativeSlide'], isFalse);
    expect(defaultSettingValues['videoPlayerSwitchForceTimeoutSeconds'], 5);
    expect(defaultSettingValues['preloadVideoShot'], isTrue);
    expect(defaultSettingValues['rcmdRefreshCount'], 20);
    expect(defaultSettingValues['showRecommendRefreshStatsToast'], isFalse);
    expect(defaultSettingValues['danmakuFontScale'], 0.9);
    expect(defaultSettingValues['danmakuFontScaleFS'], 1.2);
    expect(defaultSettingValues['danmakuMassiveMode'], isTrue);
    expect(defaultSettingValues['rememberDanmakuSwitchState'], isFalse);
    expect(defaultSettingValues['showBufferingInfo'], isTrue);
    expect(defaultVideoValues['cacheVideoFit'], 1);
    expect(defaultSettingValues['recommendHistoryFilterSettings'], {
      'enabled': false,
      'lookbackMinutes': 10080,
      'exposureThreshold': 1,
      'watchThreshold': 0,
      'minWatchSeconds': 30,
    });
  });

  test('does not ship account, device, or local font settings', () {
    expect(defaultSettingValues.containsKey('blockUserID'), isFalse);
    expect(defaultSettingValues.containsKey('displayMode'), isFalse);
    expect(
      defaultSettingValues.containsKey('danmakuChineseFontFile'),
      isFalse,
    );
    expect(
      defaultSettingValues.containsKey('danmakuChineseFontName'),
      isFalse,
    );
    expect(defaultSettingValues.containsKey('danmakuFontFamily'), isFalse);
  });
}
