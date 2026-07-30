import 'dart:async' show Completer, StreamSubscription, Timer, unawaited;
import 'dart:convert' show ascii;
import 'dart:io' show Platform;
import 'dart:math' show max, min;
import 'dart:ui' as ui;

import 'package:PiliPlus/common/assets.dart';
import 'package:PiliPlus/common/constants.dart';
import 'package:PiliPlus/http/browser_ua.dart';
import 'package:PiliPlus/http/constants.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/models/common/account_type.dart';
import 'package:PiliPlus/models/common/audio_normalization.dart';
import 'package:PiliPlus/models/common/super_resolution_type.dart';
import 'package:PiliPlus/models/common/video/video_type.dart';
import 'package:PiliPlus/models/user/danmaku_rule.dart';
import 'package:PiliPlus/models/video/play/url.dart';
import 'package:PiliPlus/models_new/video/video_shot/data.dart';
import 'package:PiliPlus/pages/danmaku/danmaku_model.dart';
import 'package:PiliPlus/pages/setting/models/play_settings.dart'
    show kMaxVolume;
import 'package:PiliPlus/pages/sponsor_block/block_mixin.dart';
import 'package:PiliPlus/plugin/pl_player/models/data_source.dart';
import 'package:PiliPlus/plugin/pl_player/models/data_status.dart';
import 'package:PiliPlus/plugin/pl_player/models/double_tap_type.dart';
import 'package:PiliPlus/plugin/pl_player/models/duration.dart';
import 'package:PiliPlus/plugin/pl_player/models/fullscreen_mode.dart';
import 'package:PiliPlus/plugin/pl_player/models/heart_beat_type.dart';
import 'package:PiliPlus/plugin/pl_player/models/play_repeat.dart';
import 'package:PiliPlus/plugin/pl_player/models/play_status.dart';
import 'package:PiliPlus/plugin/pl_player/models/video_fit_type.dart';
import 'package:PiliPlus/plugin/pl_player/utils/fullscreen.dart';
import 'package:PiliPlus/services/mpv_log_service.dart';
import 'package:PiliPlus/services/service_locator.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/android/android_helper.dart';
import 'package:PiliPlus/utils/android/bindings.g.dart';
import 'package:PiliPlus/utils/asset_utils.dart';
import 'package:PiliPlus/utils/cache_manager.dart';
import 'package:PiliPlus/utils/device_utils.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:PiliPlus/utils/extension/box_ext.dart';
import 'package:PiliPlus/utils/extension/num_ext.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:PiliPlus/utils/image_utils.dart';
import 'package:PiliPlus/utils/mpv_utils.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/path_utils.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/playback_history_tracker.dart';
import 'package:PiliPlus/utils/recommend_history.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:archive/archive.dart' show getCrc32;
import 'package:canvas_danmaku/canvas_danmaku.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback, DeviceOrientation;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:native_device_orientation/native_device_orientation.dart';
import 'package:path/path.dart' as path;
import 'package:screen_brightness_platform_interface/screen_brightness_platform_interface.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

typedef PlayCallback = Future<void>? Function();
typedef _PlayerPair = ({
  Player player,
  VideoController videoController,
  StreamSubscription<PlayerLog>? initializationLogSubscription,
});

class _InitialPlayGate {
  _InitialPlayGate({
    required this.generation,
    required this.player,
    required this.firstFrameRendered,
  });

  final int generation;
  final Player player;
  final Future<void> firstFrameRendered;
  final Completer<void> canceled = Completer<void>();
  bool active = true;
}

class PlPlayerController with BlockConfigMixin {
  Player? _videoPlayerController;
  VideoController? _videoController;
  Future<Player>? _playerInitTask;
  _InitialPlayGate? _initialPlayGate;
  int? _initialPlayReleaseGeneration;
  Timer? _mediaRecoveryTimer;
  bool _mediaRecoveryRunning = false;
  int _mediaRecoveryAttempt = 0;
  bool _videoNetworkFailed = false;
  bool _pausedForVideoStall = false;
  bool _resumeAfterVideoRecovery = false;
  Duration? _videoStallPosition;
  Timer? _videoStallWatchdogTimer;
  DateTime? _videoStallSince;
  int _postSeekWatchdogGuardGeneration = 0;
  NativePlayer? _postSeekWatchdogGuardPlayer;
  Duration? _postSeekWatchdogGuardTarget;
  DateTime? _postSeekWatchdogGuardMinimumUntil;

  static const List<Duration> _mediaRecoveryDelays = [
    Duration(milliseconds: 350),
    Duration(milliseconds: 700),
    Duration(milliseconds: 1400),
    Duration(milliseconds: 2800),
    Duration(seconds: 4),
  ];
  static PlPlayerController? _instance;

  final playerStatus = PlPlayerStatus(.playing);

  final Rx<DataStatus> dataStatus = Rx(.none);

  Duration? seekToPos;
  bool hasToasted = false;
  final RxBool isSeeking = false.obs;
    final RxBool isGestureSeeking = false.obs;
final RxInt seekStartPosition = 0.obs;
  final RxInt position = RxInt(0);

  int get positionInMilliseconds =>
      videoPlayerController?.state.position.inMilliseconds ?? 0;

  final RxInt buffered = RxInt(0);

  final RxInt duration = RxInt(0);

  int durationInMilliseconds = 0;

  void updateDuration(Duration value) {
    duration.value = value.inSeconds;
    durationInMilliseconds = value.inMilliseconds;
  }

  int _playerCount = 0;
  String? _activeVideoPageTag;
  String? _loadedVideoPageTag;
  int _dataSourceGeneration = 0;
  String? _cdnFailoverMediaKey;
  int _currentVideoCdnIndex = 0;
  int? _videoCdnFailoverGeneration;
  bool _videoCdnFailoverPending = false;
  NativePlayer? _videoCdnFailoverSourcePlayer;
  int? _mpvLogSession;
  String? _mpvLogMediaKey;
  String? _mpvLogPageTag;
  int _videoPlayerSwitchGeneration = 0;
  Completer<void>? _videoPlayerSwitchCancellation;
  Player? _standbyVideoPlayerController;
  VideoController? _standbyVideoController;
  bool _standbyVideoOnTop = false;
  bool _standbyVideoOnly = false;
  int _presentedVideoOutputRevision = -1;
  VideoController? _presentedVideoController;
  int? _pendingVideoOutputRevision;
  VideoController? _pendingVideoOutputController;
  Completer<void>? _pendingVideoOutputPresentation;
  final RxInt videoOutputRevision = 0.obs;
  final RxBool videoPlayerSwitching = false.obs;

  void setVideoPageActive(String pageTag, bool isActive) {
    if (isActive) {
      _activeVideoPageTag = pageTag;
    } else if (_activeVideoPageTag == pageTag) {
      _activeVideoPageTag = null;
    }
  }

  bool isVideoPageActive(String pageTag) => _activeVideoPageTag == pageTag;

  bool isVideoPageDataSourceLoaded(String pageTag) =>
      _loadedVideoPageTag == pageTag &&
      _videoPlayerController != null &&
      _videoController != null &&
      _videoPlayerController!.current.isNotEmpty;

  String _buildCdnFailoverMediaKey(
    DataSource dataSource, {
    required bool isLive,
    required String? videoPageTag,
    required String? bvid,
    required int? cid,
    required int? epid,
  }) {
    if (isLive || dataSource is FileSource) {
      return '';
    }
    final hasStableMediaId = bvid != null || cid != null || epid != null;
    return [
      videoPageTag ?? '',
      bvid ?? '',
      cid?.toString() ?? '',
      epid?.toString() ?? '',
      if (!hasStableMediaId) dataSource.videoSource,
    ].join('\u0000');
  }

  void resetCdnForCurrentVideo() {
    _cdnFailoverMediaKey = null;
    _currentVideoCdnIndex = 0;
    _videoCdnFailoverGeneration = null;
    _videoCdnFailoverPending = false;
    _videoCdnFailoverSourcePlayer = null;
  }

  String _buildMpvLogMediaKey(
    DataSource dataSource, {
    required bool isLive,
    required String? videoPageTag,
    required String? bvid,
    required int? cid,
    required int? epid,
  }) {
    if (isLive) return 'live';
    final hasStableMediaId = bvid != null || cid != null || epid != null;
    return [
      'video',
      videoPageTag ?? '',
      bvid ?? '',
      cid?.toString() ?? '',
      epid?.toString() ?? '',
      if (!hasStableMediaId) dataSource.videoSource,
    ].join('\u0000');
  }

  Future<bool> _ensureMpvLogSession(
    DataSource dataSource, {
    required bool isLive,
    required String? videoPageTag,
    required String? bvid,
    required int? cid,
    required int? epid,
    required bool Function() isCurrentDataSource,
  }) async {
    final mediaKey = _buildMpvLogMediaKey(
      dataSource,
      isLive: isLive,
      videoPageTag: videoPageTag,
      bvid: bvid,
      cid: cid,
      epid: epid,
    );
    final currentSession = _mpvLogSession;
    if (_mpvLogMediaKey == mediaKey &&
        MpvLogService.isSessionActive(currentSession)) {
      final player = _videoPlayerController;
      if (player != null) {
        MpvLogService.attachPlayer(player, session: currentSession!);
      }
      return true;
    }

    final session = await MpvLogService.beginSession(
      _videoPlayerController,
      source: isLive ? 'live video' : 'video',
    );
    if (!isCurrentDataSource()) {
      await MpvLogService.endSession(session);
      return false;
    }

    _mpvLogSession = session;
    _mpvLogMediaKey = mediaKey;
    _mpvLogPageTag = videoPageTag;
    return true;
  }

  void endMpvLogSessionForPage(String pageTag) {
    if (_mpvLogPageTag == pageTag) {
      _endMpvLogSession();
    }
  }

  void _endMpvLogSession() {
    final session = _mpvLogSession;
    _mpvLogSession = null;
    _mpvLogMediaKey = null;
    _mpvLogPageTag = null;
    if (session != null) {
      unawaited(MpvLogService.endSession(session));
    }
  }

  late double lastPlaybackSpeed = 1.0;
  final RxDouble _playbackSpeed = Pref.playSpeedDefault.obs;
  late final RxDouble _longPressSpeed = Pref.longPressSpeedDefault.obs;

  final RxDouble volume = RxDouble(
    PlatformUtils.isDesktop ? Pref.desktopVolume : 1.0,
  );
  final setSystemBrightness = Pref.setSystemBrightness;

  final RxDouble brightness = (-1.0).obs;

  final RxBool showControls = false.obs;

  final RxBool showBrightnessStatus = false.obs;

  final RxBool longPressStatus = false.obs;

  final RxBool controlsLock = false.obs;

  final RxBool isFullScreen = false.obs;
  final RxBool frameSyncVideoResize = false.obs;
  bool isLive = false;

  bool _isVertical = false;

  final Rx<VideoFitType> videoFit = Rx(.contain);

  late final RxBool continuePlayInBackground =
      Pref.continuePlayInBackground.obs;

  bool _autoPlay = false;

  // 记录历史记录
  int? _aid;
  String? _bvid;
  int? cid;
  int? _epid;
  int? _seasonId;
  int? _pgcType;
  VideoType _videoType = VideoType.ugc;
  bool _historySessionStarted = false;
  int _heartDuration = 0;
  int? width;
  int? height;

  late final tryLook = !Accounts.get(AccountType.video).isLogin && Pref.p1080;

  late DataSource dataSource;

  Timer? _timer;
  StreamSubscription? _subForSeek;

  Box setting = GStorage.setting;

  // final Durations durations;

  String get bvid => _bvid!;

  /// 视频播放速度
  double get playbackSpeed => _playbackSpeed.value;

  // 长按倍速
  double get longPressSpeed => _longPressSpeed.value;

  /// [videoPlayerController] instance of Player
  Player? get videoPlayerController => _videoPlayerController;

  /// [videoController] instance of Player
  VideoController? get videoController => _videoController;

  /// 预缓冲中的备用视频输出。界面通常将它绘制在当前输出下方；正式
  /// 交接时会先提升到顶层，并在 Flutter 确认该 Texture 已呈现后再切音频。
  VideoController? get standbyVideoController => _standbyVideoController;

  /// 预缓冲中的备用播放器实例。
  Player? get standbyVideoPlayerController => _standbyVideoPlayerController;

  bool get standbyVideoOnTop => _standbyVideoOnTop;

  bool get standbyVideoOnly => _standbyVideoOnly;

  bool get mainPlayerHasVideoSource =>
      _videoPlayerController?.current.isNotEmpty ?? false;

  bool get standbyPlayerHasVideoSource =>
      _standbyVideoPlayerController?.current.isNotEmpty ?? false;

  bool isMuted = false;

  /// 听视频
  late final RxBool onlyPlayAudio = false.obs;

  /// 镜像
  late final RxBool flipX = false.obs;

  late final RxBool flipY = false.obs;

  final RxBool isBuffering = true.obs;

  /// 全屏方向
  // ignore: unnecessary_getters_setters
  bool get isVertical => _isVertical;

  set isVertical(bool value) {
    _isVertical = value;
  }

  /// 弹幕开关
  late final RxBool enableShowDanmaku = Pref.enableShowDanmaku.obs;
  late final RxBool enableShowLiveDanmaku = Pref.enableShowLiveDanmaku.obs;
  RxBool get enableShowDanmakuAdaptive =>
      isLive ? enableShowLiveDanmaku : enableShowDanmaku;

  void setDanmakuEnabled(bool value) {
    enableShowDanmaku.value = value;
    if (!tempPlayerConf && Pref.rememberDanmakuSwitchState) {
      setting.put(SettingBoxKey.enableShowDanmaku, value);
    }
  }

  void setDanmakuEnabledAdaptive(bool value) {
    if (isLive) {
      enableShowLiveDanmaku.value = value;
      if (!tempPlayerConf) {
        setting.put(SettingBoxKey.enableShowLiveDanmaku, value);
      }
    } else {
      setDanmakuEnabled(value);
    }
  }

  late final bool autoPiP = Pref.autoPiP;
  bool get isPipMode =>
      (Platform.isAndroid && AndroidHelper.isPipMode) ||
      (PlatformUtils.isDesktop && isDesktopPip);
  late bool isDesktopPip = false;
  late Rect _lastWindowBounds;

  late final showWindowTitleBar = Pref.showWindowTitleBar;
  late final RxBool isAlwaysOnTop = false.obs;
  Future<void> setAlwaysOnTop(bool value) {
    isAlwaysOnTop.value = value;
    return windowManager.setAlwaysOnTop(value);
  }

  Future<void> exitDesktopPip() {
    isDesktopPip = false;
    return Future.wait([
      if (showWindowTitleBar)
        windowManager.setTitleBarStyle(TitleBarStyle.normal),
      windowManager.setMinimumSize(const Size(400, 700)),
      windowManager.setBounds(_lastWindowBounds),
      setAlwaysOnTop(false),
      windowManager.setAspectRatio(0),
    ]);
  }

  Future<void> enterDesktopPip() async {
    if (isFullScreen.value) return;

    isDesktopPip = true;

    _lastWindowBounds = await windowManager.getBounds();

    if (showWindowTitleBar) {
      windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    }

    final Size size;
    final state = videoPlayerController!.state;
    int width = state.width;
    int height = state.height;
    if (width == 0) {
      width = this.width ?? 16;
    }
    if (height == 0) {
      height = this.height ?? 9;
    }
    if (height > width) {
      size = Size(280.0, 280.0 * height / width);
    } else {
      size = Size(280.0 * width / height, 280.0);
    }

    await windowManager.setMinimumSize(size);
    setAlwaysOnTop(true);
    windowManager
      ..setSize(size)
      ..setAspectRatio(width / height);
  }

  void toggleDesktopPip() {
    if (isDesktopPip) {
      exitDesktopPip();
    } else {
      enterDesktopPip();
    }
  }

  late bool _isAutoEnterPip = false;
  bool get isAutoEnterPip => _isAutoEnterPip;

  static bool get _isCurrVideoPage {
    final routing = Get.routing;
    if (routing.route is! GetPageRoute) {
      return false;
    }
    return _isVideoPage(routing.current);
  }

  static bool _isVideoPage(String routeName) {
    return routeName == '/videoV' || routeName == '/liveRoom';
  }

  void enterPip({bool autoEnter = false}) {
    if (videoPlayerController != null) {
      final state = videoPlayerController!.state;
      PageUtils.enterPip(
        autoEnter: autoEnter,
        width: state.width == 0 ? width : state.width,
        height: state.height == 0 ? height : state.height,
        isLive: isLive,
        isPlaying: playerStatus.isPlaying,
      );
    }
  }

  void _disableAutoEnterPip() {
    if (_isAutoEnterPip) {
      PiliAndroidHelper.disableAutoEnterPip();
    }
  }

  // 弹幕相关配置
  late final enableTapDm = PlatformUtils.isMobile && Pref.enableTapDm;
  late RuleFilter filters = Pref.danmakuFilterRule;
  // 关联弹幕控制器
  DanmakuController<DanmakuExtra>? danmakuController;
    /// bool 参数为 true 时重置当前高频弹幕统计；
/// false 时只要求刷新显示样式。
ValueChanged<bool>? onDanmakuMergeSettingsChanged;
  bool showDanmaku = true;
  Set<int> dmState = <int>{};
  
  late final String midHash = getCrc32(
    ascii.encode(Accounts.main.mid.toString()),
    0,
  ).toRadixString(16);
  late final RxDouble danmakuOpacity = Pref.danmakuOpacity.obs;

  late List<double> speedList = Pref.speedList;
  late bool enableAutoLongPressSpeed = Pref.enableAutoLongPressSpeed;
  Duration get longPressSpeedTriggerDelay =>
      Duration(milliseconds: Pref.longPressSpeedTriggerDelay);
  Duration get showControlDuration => Duration(
  seconds: Pref.playerControlDisplayDurationSeconds,
);
  // 字幕
  late double subtitleFontScale = Pref.subtitleFontScale;
  late double subtitleFontScaleFS = Pref.subtitleFontScaleFS;
  late int subtitlePaddingH = Pref.subtitlePaddingH;
  late int subtitlePaddingB = Pref.subtitlePaddingB;
  late double subtitleBgOpacity = Pref.subtitleBgOpacity;
  final bool showVipDanmaku = Pref.showVipDanmaku; // loop unswitching
  late double subtitleStrokeWidth = Pref.subtitleStrokeWidth;
  late int subtitleFontWeight = Pref.subtitleFontWeight;

  // settings
  late final showFSActionItem = Pref.showFSActionItem;
  late final enableShrinkVideoSize = Pref.enableShrinkVideoSize;
  double get pinchGestureAngleThreshold => Pref.pinchGestureAngleThreshold;
  double get horizontalSeekGestureThreshold =>
      Pref.horizontalSeekGestureThreshold;
  late final darkVideoPage = Pref.darkVideoPage;
  late final enableSlideVolumeBrightness = Pref.enableSlideVolumeBrightness;
  late final showLongPressSpeedToast = Pref.showLongPressSpeedToast;
  bool get volumeBrightnessGestureProgressBar =>
      Pref.volumeBrightnessGestureProgressBar;
  late final biliProgressTimeStyle = Pref.biliProgressTimeStyle;
  double get playerProgressThumbScale => Pref.playerProgressThumbScale;
  double get playerProgressBarTouchPadding =>
      Pref.playerProgressBarTouchPadding;
  double get playerControlHorizontalPadding =>
      Pref.playerControlHorizontalPadding;
  double get playerControlBarThicknessScale =>
      Pref.playerControlBarThicknessScale;
  double get playerControlBarGradientExtent =>
      Pref.playerControlBarGradientExtent;
  double get volumeGestureAngleThreshold =>
      Pref.volumeGestureAngleThreshold;
  double get brightnessGestureAngleThreshold =>
      Pref.brightnessGestureAngleThreshold;
  double get volumeGestureSpeed => Pref.volumeGestureSpeed;
  double get brightnessGestureSpeed => Pref.brightnessGestureSpeed;
  double get seekTimeToastVerticalPercent =>
      Pref.seekTimeToastVerticalPercent;
  double get longPressSpeedToastVerticalPercent =>
      Pref.longPressSpeedToastVerticalPercent;
  double get seekTimeToastFontSize => Pref.seekTimeToastFontSize;
  double get longPressSpeedToastFontSize =>
      Pref.longPressSpeedToastFontSize;
  late final enableSlideFS = Pref.enableSlideFS;
  late final enableDragSubtitle = Pref.enableDragSubtitle;
  late final fastForBackwardDuration = Duration(
    seconds: Pref.fastForBackwardDuration,
  );

  late final horizontalSeasonPanel = Pref.horizontalSeasonPanel;
  late final preInitPlayer = Pref.preInitPlayer;
  late final preloadVideoShot = Pref.preloadVideoShot;
  late final showRelatedVideo = Pref.showRelatedVideo;
  late final showVideoReply = Pref.showVideoReply;
  late final showBangumiReply = Pref.showBangumiReply;
  late final reverseFromFirst = Pref.reverseFromFirst;
  late final horizontalPreview = Pref.horizontalPreview;
  late final showDmChart = Pref.showDmChart;
  late final showViewPoints = Pref.showViewPoints;
  late final showFsScreenshotBtn = Pref.showFsScreenshotBtn;
  late final showFsLockBtn = Pref.showFsLockBtn;
  late final keyboardControl = Pref.keyboardControl;
  late final uiScale = Pref.uiScale;

  late final bool autoEnterFullScreen = Pref.autoEnterFullScreen;
  late final bool autoExitFullscreen = Pref.autoExitFullscreen;
  late final bool autoPlayEnable = Pref.autoPlayEnable;
  late final bool enableVerticalExpand = Pref.enableVerticalExpand;
  late final bool pipNoDanmaku = Pref.pipNoDanmaku;

  late final bool tempPlayerConf = Pref.tempPlayerConf;

  late int? cacheVideoQa = PlatformUtils.isMobile ? null : Pref.defaultVideoQa;
  late int cacheAudioQa = Pref.defaultAudioQa;
  bool enableHeart = true;
  late final String? hwdec = Pref.enableHA ? Pref.hardwareDecoding : null;

  late final progressType = Pref.btmProgressBehavior;
  late final enableQuickDouble = Pref.enableQuickDouble;
  late final fullScreenGestureReverse = Pref.fullScreenGestureReverse;

  late final isRelative = Pref.useRelativeSlide;
  late final offset = isRelative
      ? Pref.sliderDuration / 100
      : Pref.sliderDuration * 1000;

  num get sliderScale => isRelative ? durationInMilliseconds * offset : offset;

  // 播放顺序相关
  late PlayRepeat playRepeat = Pref.playRepeat;

  TextStyle get subTitleStyle => TextStyle(
    height: 1.5,
    fontSize:
        16 * (isFullScreen.value ? subtitleFontScaleFS : subtitleFontScale),
    letterSpacing: 0.1,
    wordSpacing: 0.1,
    color: Colors.white,
    fontWeight: FontWeight.values[subtitleFontWeight],
    backgroundColor: subtitleBgOpacity == 0
        ? null
        : Colors.black.withValues(alpha: subtitleBgOpacity),
  );

  late final Rx<SubtitleViewConfiguration> subtitleConfig = getSubConfig.obs;

  SubtitleViewConfiguration get getSubConfig {
    final subTitleStyle = this.subTitleStyle;
    return SubtitleViewConfiguration(
      style: subTitleStyle,
      strokeStyle: subtitleBgOpacity == 0
          ? subTitleStyle.copyWith(
              color: null,
              background: null,
              backgroundColor: null,
              foreground: Paint()
                ..color = Colors.black
                ..style = PaintingStyle.stroke
                ..strokeWidth = subtitleStrokeWidth,
            )
          : null,
      padding: EdgeInsets.only(
        left: subtitlePaddingH.toDouble(),
        right: subtitlePaddingH.toDouble(),
        bottom: subtitlePaddingB.toDouble(),
      ),
      textScaleFactor: 1,
    );
  }

  void updateSubtitleStyle() {
    subtitleConfig.value = getSubConfig;
  }

  void onUpdatePadding(EdgeInsets padding) {
    subtitlePaddingB = padding.bottom.round().clamp(0, 200);
    putSubtitleSettings();
  }

  static PlPlayerController? get instance => _instance;

  static bool instanceExists() {
    return _instance != null;
  }

  static void setPlayCallBack(PlayCallback? playCallBack) {
    _playCallBack = playCallBack;
  }

  static PlayCallback? _playCallBack;

  static Future<void>? playIfExists() {
    return _playCallBack?.call();
  }

  // try to get PlayerStatus
  static PlayerStatus? getPlayerStatusIfExists() {
    return _instance?.playerStatus.value;
  }

  static Future<void> pauseIfExists({
    bool notify = true,
    bool isInterrupt = false,
  }) async {
    if (_instance?.playerStatus.isPlaying ?? false) {
      await _instance?.pause(notify: notify, isInterrupt: isInterrupt);
    }
  }

  static Future<void> seekToIfExists(
    Duration position, {
    bool isSeek = true,
  }) async {
    await _instance?.seekTo(position, isSeek: isSeek);
  }

  static double? getVolumeIfExists() {
    return _instance?.volume.value;
  }

  static Future<void>? setVolumeIfExists(
    double volumeNew, {
    bool showIndicator = true,
  }) {
    return _instance?.setVolume(volumeNew, showIndicator: showIndicator);
  }

  Box video = GStorage.video;

  bool visible = true;

  DeviceOrientation? _orientation;
  late final checkIsAutoRotate = Platform.isAndroid && mode != .gravity;
  StreamSubscription<OrientationParams>? _orientationListener;

  void _stopOrientationListener() {
    _orientationListener?.cancel();
    _orientationListener = null;
  }

  void _onOrientationChanged(OrientationParams param) {
    _orientation = param.orientation;
    if (Platform.isIOS && !visible) return;
    final orientation = param.orientation;
    final isFullScreen = this.isFullScreen.value;
    if (checkIsAutoRotate &&
        param.isAutoRotate != true &&
        (!isFullScreen ||
            _isVertical ||
            orientation == .portraitUp ||
            orientation == .portraitDown)) {
      return;
    }
    switch (orientation) {
      case .portraitUp:
        if (!_isVertical && controlsLock.value) return;
        if (!horizontalScreen && !_isVertical && isFullScreen) {
          if (!isManualFS) {
            triggerFullScreen(status: false, orientation: orientation);
          }
        } else {
          portraitUpMode();
        }
      case .portraitDown:
        if (!horizontalScreen) return;
        if (!_isVertical && controlsLock.value) return;
        portraitDownMode();
      case .landscapeLeft:
        if (!horizontalScreen && !isFullScreen) {
          triggerFullScreen(orientation: orientation, isManualFS: false);
        } else {
          landscapeLeftMode();
        }
      case .landscapeRight:
        if (!horizontalScreen && !isFullScreen) {
          triggerFullScreen(orientation: orientation, isManualFS: false);
        } else {
          landscapeRightMode();
        }
    }
  }

  // 添加一个私有构造函数
  PlPlayerController._() {
    if (PlatformUtils.isMobile) {
      _orientationListener = NativeDeviceOrientationPlatform.instance
          .onOrientationChanged(
            checkIsAutoRotate: checkIsAutoRotate,
            angleDegrees: Platform.isAndroid ? Pref.angleDegrees : null,
          )
          .listen(_onOrientationChanged);
    }

    if (!Accounts.heartbeat.isLogin || Pref.historyPause) {
      enableHeart = false;
    }

    if (Platform.isAndroid && autoPiP) {
      if (DeviceUtils.sdkInt < 31) {
        AndroidHelper$ToDart.onUserLeaveHint = Runnable.implement(
          $Runnable(run: _onUserLeaveHint),
        );
      } else {
        _isAutoEnterPip = true;
      }
    }
  }

  void _onUserLeaveHint() {
    if (playerStatus.isPlaying && _isCurrVideoPage) {
      enterPip();
    }
  }

  // 获取实例 传参
  static PlPlayerController getInstance({bool isLive = false}) {
    // 如果实例尚未创建，则创建一个新实例
    return (_instance ??= PlPlayerController._())
      ..isLive = isLive
      .._playerCount += 1;
  }

  static Future<bool> exitFullscreenAndPauseIfActive({
    bool forcePortrait = false,
  }) async {
    final instance = _instance;
    if (instance == null || !instance.isFullScreen.value) {
      return false;
    }
    await instance.pause();
    await instance.triggerFullScreen(status: false);
    if (forcePortrait && PlatformUtils.isMobile) {
      await portraitUpMode();
    }
    return true;
  }

  bool _processing = false;
  bool get processing => _processing;

  // offline
  bool get isFileSource => dataSource is FileSource;

  late final _audioNormalization = Pref.audioNormalization;
  late final enableAudioNormalization =
      Platform.isAndroid && _audioNormalization != '0';
  late final String _audioNormalizationParam =
      AudioNormalization.getParamFromConfig(_audioNormalization);

  // 初始化资源
  Future<void> setDataSource(
    DataSource dataSource, {
    bool isLive = false,
    bool autoplay = true,
    // 初始化播放位置
    Duration? seekTo,
    // 初始化播放速度
    double speed = 1.0,
    int? width,
    int? height,
    Duration? duration,
    // 方向
    bool? isVertical,
    // 记录历史记录
    int? aid,
    String? bvid,
    int? cid,
    int? epid,
    int? seasonId,
    int? pgcType,
    VideoType? videoType,
    VoidCallback? onVideoOutputReady,
    VoidCallback? onInit,
    Volume? volume,
    bool autoFullScreenFlag = false,
    String? videoPageTag,
  }) async {
    if (videoPageTag != null && !isVideoPageActive(videoPageTag)) {
      return;
    }
    unawaited(PlaybackHistoryTracker.instance.end());
    _historySessionStarted = false;
    cancelVideoPlayerSwitch();
    _resetMediaOpenRetry();

    if (dataSource case NetworkSource networkSource when !isLive) {
      final mediaKey = _buildCdnFailoverMediaKey(
        networkSource,
        isLive: isLive,
        videoPageTag: videoPageTag,
        bvid: bvid,
        cid: cid,
        epid: epid,
      );
      if (_cdnFailoverMediaKey != mediaKey) {
        _cdnFailoverMediaKey = mediaKey;
        _currentVideoCdnIndex = 0;
      }
      final selectedSource = networkSource.atCdnIndex(
        _currentVideoCdnIndex,
      );
      dataSource = selectedSource;
      _currentVideoCdnIndex = selectedSource.cdnIndex;
    } else {
      resetCdnForCurrentVideo();
    }

    final dataSourceGeneration = ++_dataSourceGeneration;
    await _cancelInitialPlayGate();
    bool isCurrentDataSource() =>
        dataSourceGeneration == _dataSourceGeneration &&
        (videoPageTag == null || isVideoPageActive(videoPageTag));

    if (!await _ensureMpvLogSession(
      dataSource,
      isLive: isLive,
      videoPageTag: videoPageTag,
      bvid: bvid,
      cid: cid,
      epid: epid,
      isCurrentDataSource: isCurrentDataSource,
    )) {
      return;
    }

    _InitialPlayGate? initialPlayGate;
    try {
      if (!isCurrentDataSource()) return;
      _processing = true;
      _loadedVideoPageTag = null;
      this.isLive = isLive;
      if (!isLive && !Pref.rememberDanmakuSwitchState) {
        enableShowDanmaku.value = Pref.enableShowDanmaku;
      }
      _videoType = videoType ?? VideoType.ugc;
      this.width = width;
      this.height = height;
      this.dataSource = dataSource;
      _autoPlay = autoplay;
      // 初始化视频倍速
      // _playbackSpeed.value = speed;
      // 初始化数据加载状态
      dataStatus.value = DataStatus.loading;
      // 初始化全屏方向
      _isVertical = isVertical ?? false;
      _aid = aid;
      _bvid = bvid;
      this.cid = cid;
      _epid = epid;
      _seasonId = seasonId;
      _pgcType = pgcType;

      if (showAnySeekPreview) {
        _clearPreview();
        if (!this.isLive &&
            !isFileSource &&
            _bvid?.isNotEmpty == true &&
            this.cid != null &&
            preloadVideoShot) {
          _loadVideoShot(preloadImages: true);
        }
      }
      cancelLongPressTimer();
      if (_videoPlayerController != null &&
          _videoPlayerController!.state.playing) {
        await pause(notify: false);
      }

      if (_playerCount == 0 || !isCurrentDataSource()) {
        return;
      }
      // 配置Player 音轨、字幕等等
      initialPlayGate = await _createVideoController(
        dataSource,
        seekTo,
        volume,
        dataSourceGeneration: dataSourceGeneration,
        isCurrentDataSource: isCurrentDataSource,
      );

      if (_playerCount == 0 || !isCurrentDataSource()) {
        await _cancelInitialPlayGate(initialPlayGate);
        if (_playerCount == 0) {
          await _removeListeners();
          _videoPlayerController?.dispose();
          _videoPlayerController = null;
          _videoController = null;
          _loadedVideoPageTag = null;
        }
        return;
      }

      updateDuration(duration ?? _videoPlayerController!.state.duration);
      position.value = buffered.value = seekTo?.inSeconds ?? 0;

      dataStatus.value = .loaded;

      if (isCurrentDataSource()) {
        // The Android autoplay gate waits for a real Surface frame. Mount the
        // video output before waiting, otherwise a nested video page can wait
        // for a frame while its output widget is still unmounted.
        onVideoOutputReady?.call();
      }

      if (autoFullScreenFlag && autoEnterFullScreen) {
        triggerFullScreen(status: true);
      }

      await _initializePlayer(
        isCurrentDataSource,
        initialPlayGate,
      );
      if (isCurrentDataSource()) {
        _loadedVideoPageTag = videoPageTag;
        onInit?.call();
      }
    } catch (err, stackTrace) {
      await _cancelInitialPlayGate(initialPlayGate);
      if (isCurrentDataSource()) {
        dataStatus.value = DataStatus.error;
        if (kDebugMode) {
          debugPrint(stackTrace.toString());
          debugPrint('plPlayer err:  $err');
        }
      }
    } finally {
      if (dataSourceGeneration == _dataSourceGeneration) {
        _processing = false;
      }
    }
  }

  String? shadersDirPath;
  Future<String> get copyShadersToExternalDirectory async {
    if (shadersDirPath != null) {
      return shadersDirPath!;
    }

    return shadersDirPath = await AssetUtils.getOrCopy(
      'assets/shaders',
      Assets.mpvAnime4KShaders.followedBy(Assets.mpvAnime4KShadersLite),
      path.join(appSupportDirPath, 'anime_shaders'),
    );
  }

  late final isAnim = _pgcType == 1 || _pgcType == 4;
  late final Rx<SuperResolutionType> superResolutionType =
      (isAnim ? Pref.superResolutionType : SuperResolutionType.disable).obs;
  Future<void> setShader([SuperResolutionType? type, NativePlayer? pp]) async {
    if (type == null) {
      type = superResolutionType.value;
    } else {
      superResolutionType.value = type;
      if (isAnim && !tempPlayerConf) {
        setting.put(SettingBoxKey.superResolutionType, type.index);
      }
    }
    pp ??= _videoPlayerController!;
    switch (type) {
      case SuperResolutionType.disable:
        return pp.command(const ['change-list', 'glsl-shaders', 'clr', '']);
      case SuperResolutionType.efficiency:
        return pp.command([
          'change-list',
          'glsl-shaders',
          'set',
          PathUtils.buildShadersAbsolutePath(
            await copyShadersToExternalDirectory,
            Assets.mpvAnime4KShadersLite,
          ),
        ]);
      case SuperResolutionType.quality:
        return pp.command([
          'change-list',
          'glsl-shaders',
          'set',
          PathUtils.buildShadersAbsolutePath(
            await copyShadersToExternalDirectory,
            Assets.mpvAnime4KShaders,
          ),
        ]);
    }
  }

  static final loudnormRegExp = RegExp('loudnorm=([^,]+)');

  bool get _shouldGateInitialPlay {
    final configuredVo = MpvUtils.customOptions['vo'];
    return Platform.isAndroid &&
        !isLive &&
        !onlyPlayAudio.value &&
        (configuredVo == null || configuredVo == 'gpu');
  }

  _InitialPlayGate _beginInitialPlayGate(
    Player player,
    int generation,
    Future<void> firstFrameRendered,
  ) {
    final gate = _InitialPlayGate(
      generation: generation,
      player: player,
      firstFrameRendered: firstFrameRendered,
    );

    _initialPlayGate = gate;
    try {
      _holdInitialPlay(gate);
    } catch (_) {
      _finishInitialPlayGate(gate);
      rethrow;
    }
    return gate;
  }

  void _holdInitialPlay(_InitialPlayGate gate) {
    if (!gate.active) return;
    gate.player.setProperty('pause', 'yes');
  }

  Future<bool> _waitForInitialPlayOutput(
    _InitialPlayGate gate,
    NativePlayer player,
    bool Function() isCurrentDataSource,
    DateTime deadline,
  ) async {
    while (DateTime.now().isBefore(deadline)) {
      if (!gate.active ||
          !isCurrentDataSource() ||
          gate.generation != _dataSourceGeneration ||
          !identical(player, _videoPlayerController)) {
        return false;
      }

      final currentVo = player
          .getProperty('current-vo')
          .trim()
          .toLowerCase();
      if (currentVo.isNotEmpty && currentVo != 'null') {
        return true;
      }

      final canceled = await Future.any<bool>([
        gate.canceled.future.then((_) => true),
        Future<bool>.delayed(const Duration(milliseconds: 20), () => false),
      ]);
      if (canceled) return false;
    }
    return false;
  }

  Future<void> _releaseInitialPlayGate(
    _InitialPlayGate gate,
    bool Function() isCurrentDataSource,
  ) async {
    final player = _videoPlayerController;
    if (player == null || !identical(gate.player, player)) return;

    final readyDeadline = DateTime.now().add(const Duration(seconds: 15));
    final firstFrameReady = await Future.any<bool>([
      gate.firstFrameRendered.then(
        (_) => true,
        onError: (_) => false,
      ),
      gate.canceled.future.then((_) => false),
      Future<bool>.delayed(const Duration(seconds: 15), () => false),
    ]);
    final outputReady =
        firstFrameReady &&
        await _waitForInitialPlayOutput(
          gate,
          player,
          isCurrentDataSource,
          readyDeadline,
        );
    if (!outputReady ||
        !gate.active ||
        !isCurrentDataSource() ||
        gate.generation != _dataSourceGeneration ||
        !identical(player, _videoPlayerController)) {
      if (gate.active) {
        await _cancelInitialPlayGate(gate);
      }
      return;
    }

    try {
      // Surface 已以最终封面视口尺寸出帧；从这里开始只解除一次暂停。
      _holdInitialPlay(gate);
      _initialPlayReleaseGeneration = gate.generation;
      await playIfExists();
      if (gate.active &&
          isCurrentDataSource() &&
          gate.generation == _dataSourceGeneration &&
          identical(player, _videoPlayerController)) {
        _finishInitialPlayGate(gate);
      }
    } finally {
      if (_initialPlayReleaseGeneration == gate.generation) {
        _initialPlayReleaseGeneration = null;
      }
    }
  }

  void _finishInitialPlayGate(_InitialPlayGate gate) {
    if (!gate.active) return;
    gate.active = false;
    if (!gate.canceled.isCompleted) {
      gate.canceled.complete();
    }
    if (identical(_initialPlayGate, gate)) {
      _initialPlayGate = null;
    }
  }

  Future<void> _cancelInitialPlayGate([
    _InitialPlayGate? expected,
  ]) async {
    final gate = expected ?? _initialPlayGate;
    if (gate == null ||
        !gate.active ||
        (expected != null && !identical(_initialPlayGate, expected))) {
      return;
    }

    if (identical(_initialPlayGate, gate)) {
      _initialPlayGate = null;
    }
    gate.active = false;
    if (!gate.canceled.isCompleted) {
      gate.canceled.complete();
    }
    var paused = false;
    try {
      if (gate.player.state.playing) {
        await gate.player.pause();
        paused = true;
      }
    } catch (_) {
      // 数据源替换只需尽力阻止静音中的旧起播继续推进。
    }
    if (paused) {
      audioSessionHandler?.setActive(false);
    }
  }

  void _discardInitialPlayGate() {
    final gate = _initialPlayGate;
    _initialPlayGate = null;
    if (gate == null || !gate.active) return;
    gate.active = false;
    if (!gate.canceled.isCompleted) {
      gate.canceled.complete();
    }
  }

  Future<_PlayerPair> _createPlayerPair({
    bool muted = false,
    int? logSession,
  }) async {
    final customOptions = MpvUtils.customOptions;
    final builtInOptions = <String, String>{
      'video-sync': Pref.videoSync,
      if (Platform.isAndroid) 'ao': Pref.audioOutput,
      'volume': muted
          ? '0'
          : (PlatformUtils.isMobile ? Pref.playerVolume : volume.value * 100)
                .toString(),
      if (muted) 'mute': 'yes',
      'volume-max': kMaxVolume.toString(),
    };
    final autosync = Pref.autosync;
    if (autosync != '0') {
      builtInOptions['autosync'] = autosync;
    }
    final options = {
      ...builtInOptions,
      ...customOptions,
      if (muted) ...{'volume': '0', 'mute': 'yes'},
    };

    final player = await Player.create(
      configuration: PlayerConfiguration(
        logLevel: MpvUtils.logLevel,
        options: options,
      ),
    );
    final initializationLogSubscription =
        logSession != null &&
            MpvLogService.attachPlayer(player, session: logSession)
        ? player.stream.log.listen((log) => MpvLogService.add(player, log))
        : null;

    try {
      final customHwdec = customOptions['hwdec'];
      final configuredVo = customOptions['vo'];
      final videoController = await VideoController.create(
        player,
        configuration: VideoControllerConfiguration(
          vo: configuredVo,
          enableHardwareAcceleration: customHwdec != null
              ? customHwdec != 'no'
              : hwdec != null,
          androidAttachSurfaceAfterVideoParameters:
              Platform.isAndroid &&
              (configuredVo == null || configuredVo == 'gpu'),
          hwdec: customHwdec ?? hwdec,
        ),
      );

      player.setMediaHeader(
        userAgent: BrowserUa.pc,
        referer: HttpString.baseUrl,
      );

      return (
        player: player,
        videoController: videoController,
        initializationLogSubscription: initializationLogSubscription,
      );
    } catch (_) {
      await initializationLogSubscription?.cancel();
      if (logSession != null) {
        MpvLogService.detachPlayer(player, session: logSession);
      }
      await player.dispose();
      rethrow;
    }
  }

  Future<Player> _initPlayer() async {
    assert(_videoPlayerController == null);
    assert(_videoController == null);
    final logSession = _mpvLogSession;
    final pair = await _createPlayerPair(logSession: logSession);
    _videoController = pair.videoController;
    await pair.initializationLogSubscription?.cancel();
    if (logSession != null) {
      MpvLogService.attachPlayer(pair.player, session: logSession);
    }
    _startListeners(pair.player);
    return pair.player;
  }

  Map<String, String>? _buffer;
  Map<String, String> get buffer =>
      _buffer ??= Pref.initBuffer(_playbackSpeed.value);
  Map<String, String>? _liveBuffer;
  Map<String, String> get liveBuffer => _liveBuffer ??= Pref.initLiveBuffer();

  // 配置播放器
  Future<_InitialPlayGate?> _createVideoController(
    DataSource dataSource,
    Duration? seekTo,
    Volume? volume, {
    required int dataSourceGeneration,
    required bool Function() isCurrentDataSource,
  }) async {
    if (!isCurrentDataSource()) return null;
    isBuffering.value = false;
    _heartDuration = 0;
    danmakuController?.clear();

    var player = _videoPlayerController;

    if (player == null) {
      final initTask = _playerInitTask ??= _initPlayer();
      try {
        player = await initTask;
      } finally {
        if (identical(_playerInitTask, initTask)) {
          _playerInitTask = null;
        }
      }
      if (_playerCount == 0) {
        await _removeListeners();
        player.dispose();
        _videoController = null;
        _loadedVideoPageTag = null;
        return null;
      }
      _videoPlayerController ??= player;
      if (!isCurrentDataSource()) return null;
      if (isAnim && superResolutionType.value != .disable) {
        await setShader();
        if (!isCurrentDataSource()) return null;
      }
    }

    final Map<String, String> extras = {};

    if (dataSource is FileSource) {
      extras['cache'] = 'no';
    } else {
      if (isLive) {
        extras.addAll(liveBuffer);
      } else {
        extras.addAll(buffer);
      }
    }

    String video = dataSource.videoSource;
    if (dataSource.audioSource case final audio? when (audio.isNotEmpty)) {
      if (onlyPlayAudio.value) {
        video = audio;
      } else {
        extras['audio-files'] =
            '"${Platform.isWindows ? audio.replaceAll(';', r'\;') : audio.replaceAll(':', r'\:')}"';
      }
      if (enableAudioNormalization) {
        final String audioNormalization;
        if (volume != null && volume.isNotEmpty) {
          audioNormalization = _audioNormalizationParam.replaceFirstMapped(
            loudnormRegExp,
            (i) =>
                'loudnorm=${volume.format(
                  Map.fromEntries(
                    i.group(1)!.split(':').map((item) {
                      final parts = item.split('=');
                      return MapEntry(parts[0].toLowerCase(), num.parse(parts[1]));
                    }),
                  ),
                )}',
          );
        } else {
          audioNormalization = _audioNormalizationParam.replaceFirst(
            loudnormRegExp,
            AudioNormalization.getParamFromConfig(Pref.fallbackNormalization),
          );
        }
        if (audioNormalization.isNotEmpty) {
          extras['lavfi-complex'] = '"[aid1] $audioNormalization [ao]"';
        }
      }
    }

    MpvUtils.overridePerFileOptions(extras);
    _InitialPlayGate? gate;
    try {
      await _openVideoMedia(
        player,
        Media(
          video,
          start: seekTo,
          extras: extras.isEmpty ? null : extras,
        ),
        play: false,
        isCurrentDataSource: isCurrentDataSource,
        beforeOpen: () {
          final videoController = _videoController;
          if (_shouldGateInitialPlay &&
              isCurrentDataSource() &&
              videoController != null) {
            gate = _beginInitialPlayGate(
              player!,
              dataSourceGeneration,
              videoController.armWaitUntilFirstFrameRendered(),
            );
          }
        },
      );
      if (gate case final gate?) {
        // open 及逐文件参数可能再次改写 pause。真正 Surface 帧确认前
        // 始终保持暂停。
        _holdInitialPlay(gate);
      }
      return gate;
    } catch (_) {
      if (gate case final gate?) {
        _finishInitialPlayGate(gate);
      }
      rethrow;
    }
  }

  Future<void> _openVideoMedia(
    NativePlayer player,
    Media media, {
    required bool play,
    bool Function()? isCurrentDataSource,
    VoidCallback? beforeOpen,
  }) async {
    if (isCurrentDataSource?.call() == false) return;
    // player.open 会先卸载旧媒体；手动刷新与直播错误重试前重新应用用户
    // 参数，避免这些原地打开路径绕过自定义设置。
    MpvUtils.applyRuntimeOverrides(player);
    beforeOpen?.call();
    await player.open(media, play: play);
  }

  Future<void>? refreshPlayer() {
    if (dataSource is FileSource) {
      return null;
    }
    if (_videoPlayerController case final ctr? when (ctr.current.isNotEmpty)) {
      final source = dataSource as NetworkSource;
      return _openVideoMedia(
        ctr,
        ctr.current.last.copyWith(
          uri: source.videoSource,
          start: ctr.state.position,
        ),
        play: true,
      );
    }
    return null;
  }
  void _resetMediaOpenRetry() {
    _mediaRecoveryTimer?.cancel();
    _mediaRecoveryTimer = null;
    _mediaRecoveryAttempt = 0;
    _videoNetworkFailed = false;
    _pausedForVideoStall = false;
    _resumeAfterVideoRecovery = false;
    _videoStallPosition = null;
    _videoCdnFailoverGeneration = null;
    _videoCdnFailoverPending = false;
    _videoCdnFailoverSourcePlayer = null;
    _clearPostSeekWatchdogGuard();
    _resetVideoStallObservation();
  }

  bool _isTlsHandshakeFailure(String prefix, String message) {
    final text = '$prefix $message'.toLowerCase();
    final hasTlsContext =
        text.contains('tls') ||
        text.contains('ssl') ||
        text.contains('gnutls');
    if (!hasTlsContext) {
      return false;
    }
    final hasHandshakeContext =
        text.contains('handshake') ||
        text.contains('certificate verify') ||
        text.contains('certificate unknown') ||
        text.contains('unknown ca') ||
        text.contains('unable to negotiate') ||
        text.contains('failed to initialize') ||
        text.contains('ssl_connect') ||
        text.contains('tls_connect') ||
        text.contains('wrong version number') ||
        text.contains('protocol version') ||
        text.contains('no suitable signature') ||
        text.contains('peer did not return a certificate');
    final hasFailure =
        text.contains('fail') ||
        text.contains('error') ||
        text.contains('fatal') ||
        text.contains('unable') ||
        text.contains('timeout') ||
        text.contains('timed out') ||
        text.contains('unknown') ||
        text.contains('wrong') ||
        text.contains('alert');
    return hasHandshakeContext && hasFailure;
  }

  bool _messageReferencesUrl(String message, String? source) {
    if (source == null || source.isEmpty) {
      return false;
    }
    final text = message
        .replaceAll(r'\:', ':')
        .replaceAll('&amp;', '&')
        .toLowerCase();
    final normalizedSource = source
        .replaceAll(r'\:', ':')
        .replaceAll('&amp;', '&')
        .toLowerCase();
    if (text.contains(normalizedSource)) {
      return true;
    }

    try {
      return text.contains(Uri.decodeFull(normalizedSource));
    } catch (_) {
      return false;
    }
  }

  bool _isExternalAudioFailure(NetworkSource source, String message) {
    final text = message.toLowerCase();
    if (text.contains('can not open external file') ||
        text.contains('cannot open external file') ||
        text.contains('failed to open external file')) {
      return true;
    }

    final referencesAudio = _messageReferencesUrl(message, source.audioSource);
    final referencesVideo = _messageReferencesUrl(message, source.videoSource);
    return referencesAudio && !referencesVideo;
  }

  bool _isExplicitVideoOpenFailure(
    NetworkSource source,
    String message,
  ) {
    return message.toLowerCase().contains('failed to open') &&
        _messageReferencesUrl(message, source.videoSource);
  }

  void _triggerVideoCdnFailover(NativePlayer player) {
    if (!identical(player, _videoPlayerController) ||
        _playerCount == 0 ||
        isLive ||
        dataSource is! NetworkSource) {
      return;
    }
    _videoNetworkFailed = true;
    unawaited(_switchCdnAfterVideoFailure(player));
  }

  bool _handleVideoCdnFailure(
    NativePlayer player,
    String prefix,
    String message,
  ) {
    final source = dataSource;
    if (!identical(player, _videoPlayerController) ||
        _playerCount == 0 ||
        isLive ||
        source is! NetworkSource) {
      return false;
    }

    final text = '$prefix $message';
    if (_isExplicitVideoOpenFailure(source, text)) {
      _triggerVideoCdnFailover(player);
      return true;
    }
    if (!_isTlsHandshakeFailure(prefix, message)) {
      return false;
    }
    if (_isExternalAudioFailure(source, text)) {
      return false;
    }

    final referencesVideo = _messageReferencesUrl(text, source.videoSource);
    // DASH 视频与 audio-files 共用错误流；存在外置音轨时，只有日志明确
    // 指向视频 URL 才能触发整媒体 CDN 切换。无 URL 的错误交给视频停滞
    // 看门狗确认，不能用猜测破坏仍然正常的视频实例。
    if (referencesVideo || source.audioSource?.isNotEmpty != true) {
      _triggerVideoCdnFailover(player);
      return true;
    }
    return false;
  }

  Future<void> _switchCdnAfterVideoFailure(
    NativePlayer failedPlayer,
  ) async {
    final generation = _dataSourceGeneration;
    if (_videoCdnFailoverGeneration == generation) {
      if (!identical(failedPlayer, _videoCdnFailoverSourcePlayer)) {
        _videoCdnFailoverPending = true;
      }
      return;
    }
    final initialSource = dataSource;
    if (initialSource is! NetworkSource || !initialSource.hasNextCdn) {
      _scheduleSeamlessMediaRecovery();
      return;
    }

    _videoCdnFailoverGeneration = generation;
    _videoCdnFailoverPending = false;
    _videoCdnFailoverSourcePlayer = failedPlayer;
    _mediaRecoveryTimer?.cancel();
    _mediaRecoveryTimer = null;
    _mediaRecoveryAttempt = 0;
    var attemptedSource = initialSource;
    var shouldScheduleRecovery = false;

    try {
      while (_playerCount > 0 &&
          generation == _dataSourceGeneration &&
          identical(failedPlayer, _videoPlayerController) &&
          attemptedSource.hasNextCdn) {
        final nextSource = attemptedSource.atCdnIndex(
          attemptedSource.cdnIndex + 1,
        );
        var nextVideoCdnFailed = false;
        final success = await switchVideoPlayer(
          targetSource: nextSource,
          width:
              width ??
              (failedPlayer.state.width > 0
                  ? failedPlayer.state.width
                  : null),
          height:
              height ??
              (failedPlayer.state.height > 0
                  ? failedPlayer.state.height
                  : null),
          reloadSameSource: true,
          useCurrentVideoCdn: false,
          allowForcedHandoff: false,
          strictTimeout: const Duration(seconds: 8),
          onVideoCdnFailure: () {
            nextVideoCdnFailed = true;
          },
        );

        if (success ||
            generation != _dataSourceGeneration ||
            !identical(failedPlayer, _videoPlayerController)) {
          return;
        }
        if (!nextVideoCdnFailed) {
          shouldScheduleRecovery = true;
          return;
        }
        attemptedSource = nextSource;
      }
      shouldScheduleRecovery = true;
    } finally {
      final retryPendingVideoFailure = _videoCdnFailoverPending;
      if (_videoCdnFailoverGeneration == generation) {
        _videoCdnFailoverGeneration = null;
        _videoCdnFailoverPending = false;
        _videoCdnFailoverSourcePlayer = null;
      }
      if (shouldScheduleRecovery &&
          generation == _dataSourceGeneration &&
          identical(failedPlayer, _videoPlayerController)) {
        _scheduleSeamlessMediaRecovery();
      } else if (retryPendingVideoFailure &&
          generation == _dataSourceGeneration) {
        final activePlayer = _videoPlayerController;
        if (activePlayer != null) {
          unawaited(_switchCdnAfterVideoFailure(activePlayer));
        }
      }
    }
  }

  bool _isRetryableVideoMediaError(
    NetworkSource source,
    String event,
  ) {
    if (_isExternalAudioFailure(source, event)) {
      return false;
    }
    final text = event.toLowerCase();
    final retryable =
        text.startsWith('failed to open https://') ||
        text.contains('ffurl_read returned') ||
        text.contains('i/o error') ||
        text.contains('connection reset') ||
        text.contains('connection timed out') ||
        text.contains('network is unreachable') ||
        text.contains('error reading') ||
        text.contains('tls') ||
        text.contains('broken pipe');
    if (!retryable) {
      return false;
    }

    if (_messageReferencesUrl(event, source.videoSource)) {
      return true;
    }

    // DASH 的视频与 audio-files 共享同一个 mpv 错误流。没有 URL 的
    // ffurl_read/I/O 错误无法证明坏的是哪条链路，不能据此重建整个媒体；
    // 真正的视频中断仍由视频缓存/输出看门狗触发恢复。
    return source.audioSource?.isNotEmpty != true;
  }

  void _resetVideoStallObservation() {
    _videoStallSince = null;
  }

  int? _beginPostSeekWatchdogGuard(
    NativePlayer? player,
    Duration target,
  ) {
    if (player == null) {
      return null;
    }
    final generation = ++_postSeekWatchdogGuardGeneration;
    _postSeekWatchdogGuardPlayer = player;
    _postSeekWatchdogGuardTarget = target;
    final now = DateTime.now();
    _postSeekWatchdogGuardMinimumUntil = now.add(
      const Duration(seconds: 1),
    );
    _resetVideoStallObservation();
    return generation;
  }

  void _clearPostSeekWatchdogGuard({int? generation}) {
    if (generation != null &&
        generation != _postSeekWatchdogGuardGeneration) {
      return;
    }
    _postSeekWatchdogGuardGeneration++;
    _postSeekWatchdogGuardPlayer = null;
    _postSeekWatchdogGuardTarget = null;
    _postSeekWatchdogGuardMinimumUntil = null;
  }

  bool _isPostSeekWatchdogGuardActive(NativePlayer player) {
    if (!identical(player, _postSeekWatchdogGuardPlayer)) {
      return false;
    }

    final target = _postSeekWatchdogGuardTarget;
    final minimumUntil = _postSeekWatchdogGuardMinimumUntil;
    final now = DateTime.now();
    if (target == null || minimumUntil == null) {
      _clearPostSeekWatchdogGuard();
      return false;
    }

    final state = player.state;
    final minimumGuardElapsed = !now.isBefore(minimumUntil);
    final videoBufferReachedTarget =
        state.buffer > Duration.zero &&
        state.buffer >= target;
    if (minimumGuardElapsed && videoBufferReachedTarget) {
      _clearPostSeekWatchdogGuard();
      return false;
    }

    // 网络缓冲没有可靠的最长耗时。只要缓存末端还没追到 seek 目标，
    // 就不能让启发式看门狗把 seek 前的旧缓存误判为视频流已停止。
    // 明确的网络错误仍会由 stream.error 触发播放器恢复。
    return true;
  }

  String? _readPlayerProperty(NativePlayer player, String name) {
    try {
      return player.getProperty(name);
    } catch (_) {
      return null;
    }
  }

  void _startVideoStallWatchdog(NativePlayer player) {
    _videoStallWatchdogTimer?.cancel();
    _clearPostSeekWatchdogGuard();
    _resetVideoStallObservation();
    _videoStallWatchdogTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => _checkVideoStall(player),
    );
  }

  void _checkVideoStall(NativePlayer player) {
    final seeking =
        _readPlayerProperty(player, 'seeking') == 'yes';

    if (_pausedForVideoStall ||
        !identical(player, _videoPlayerController) ||
        _playerCount == 0 ||
        isLive ||
        dataSource is FileSource ||
        onlyPlayAudio.value ||
        isSeeking.value ||
        seeking ||
        player.current.isEmpty ||
        !player.state.playing ||
        player.state.buffering) {
      _resetVideoStallObservation();
      return;
    }

    if (_isPostSeekWatchdogGuardActive(player)) {
      _resetVideoStallObservation();
      return;
    }

    final state = player.state;
    if (state.position <= Duration.zero ||
        state.width <= 0 ||
        state.height <= 0) {
      _resetVideoStallObservation();
      return;
    }

    final nearNaturalEnd =
        state.duration > Duration.zero &&
        state.duration - state.position <= const Duration(seconds: 1);

    if (nearNaturalEnd) {
      _resetVideoStallObservation();
      return;
    }

    final now = DateTime.now();
    // 主媒体是视频，外置 DASH 音频通过 audio-files 加载。
    // 视频 EOF 后 mpv 会改用音频时钟推进 time-pos，因此 position 可以
    // 继续增长，但主视频的 demuxer-cache-time（state.buffer）会停在
    // 最后一帧附近。全局进度持续越过它，就是音频已越过视频缓存终点。
    final playbackPastVideoBuffer =
        state.buffer > Duration.zero &&
        state.position >=
            state.buffer + const Duration(milliseconds: 150);

    if (!playbackPastVideoBuffer) {
      _videoStallSince = null;
      return;
    }

    _videoStallSince ??= now;

    if (now.difference(_videoStallSince!) >=
        const Duration(milliseconds: 400)) {
      unawaited(_pauseForVideoStall(player));
    }
  }

  void _handleVideoPipelineLog(NativePlayer player, PlayerLog log) {
    if (_pausedForVideoStall ||
        !identical(player, _videoPlayerController) ||
        _playerCount == 0 ||
        isLive ||
        dataSource is FileSource ||
        onlyPlayAudio.value ||
        isSeeking.value ||
        !player.state.playing ||
        player.state.buffering) {
      return;
    }

    if (_isPostSeekWatchdogGuardActive(player)) {
      return;
    }

    final state = player.state;
    final nearNaturalEnd =
        state.duration > Duration.zero &&
        state.duration - state.position <= const Duration(seconds: 1);
    if (nearNaturalEnd) {
      return;
    }

    final prefix = log.prefix.toLowerCase();
    final text = log.text.toLowerCase();
    final videoFilterEnded =
        prefix == 'vf' && text.contains('filter output eof');
    final androidVideoOutputFailed =
        prefix.contains('aimagereader') &&
        (text.contains('waiting for frame timed out') ||
            text.contains('acquirelatestimage failed'));

    if (!videoFilterEnded && !androidVideoOutputFailed) {
      return;
    }

    // vf output EOF 已经证明视频链没有后续帧。Android ImageReader 错误
    // 可能由瞬时 Surface 变化引起，因此只在播放时钟已越过视频缓存后采用。
    final playbackPastVideoBuffer =
        state.buffer > Duration.zero &&
        state.position >= state.buffer;
    if (!videoFilterEnded && !playbackPastVideoBuffer) {
      return;
    }

    _videoNetworkFailed = true;
    unawaited(_pauseForVideoStall(player));
  }

  Future<void> _pauseForVideoStall(NativePlayer player) async {
    if (_pausedForVideoStall ||
        !identical(player, _videoPlayerController) ||
        _playerCount == 0) {
      return;
    }
    if (_isPostSeekWatchdogGuardActive(player)) {
      _resetVideoStallObservation();
      return;
    }
    if (player.state.buffering) {
      _resetVideoStallObservation();
      return;
    }

    _pausedForVideoStall = true;
    _resumeAfterVideoRecovery = player.state.playing;
    final state = player.state;
    _videoStallPosition =
        state.buffer > Duration.zero && state.buffer < state.position
        ? state.buffer
        : state.position;

    // 暂停整个旧 mpv，保留最后一帧，并阻止独立音轨继续推进。
    try {
      await player.pause();
    } catch (err, stackTrace) {
      if (identical(player, _videoPlayerController)) {
        _pausedForVideoStall = false;
        _resumeAfterVideoRecovery = false;
        _videoStallPosition = null;
        if (kDebugMode) {
          debugPrint('failed to pause stalled video player: $err');
          debugPrint(stackTrace.toString());
        }
      }
      return;
    }

    if (!_pausedForVideoStall ||
        !identical(player, _videoPlayerController) ||
        _playerCount == 0) {
      return;
    }

    isBuffering.value = true;
    _scheduleSeamlessMediaRecovery();
  }

  void _scheduleSeamlessMediaRecovery() {
    if (_playerCount == 0 ||
        isLive ||
        dataSource is FileSource ||
        _videoCdnFailoverGeneration == _dataSourceGeneration ||
        _mediaRecoveryTimer != null ||
        _mediaRecoveryRunning) {
      return;
    }

    final generation = _dataSourceGeneration;
    final activePlayer = _videoPlayerController;

    if (activePlayer == null || activePlayer.current.isEmpty) {
      return;
    }

    final delayIndex = min(
      _mediaRecoveryAttempt,
      _mediaRecoveryDelays.length - 1,
    );
    final delay = _mediaRecoveryDelays[delayIndex];

    _mediaRecoveryTimer = Timer(delay, () async {
      _mediaRecoveryTimer = null;

      if (_playerCount == 0 ||
          generation != _dataSourceGeneration ||
          !identical(activePlayer, _videoPlayerController)) {
        return;
      }

      // 用户此时可能正在主动切换画质。网络恢复不能取消画质切换。
      if (_videoPlayerSwitchCancellation != null) {
        _scheduleSeamlessMediaRecovery();
        return;
      }

      final currentSource = dataSource;
      if (currentSource is! NetworkSource) {
        return;
      }

      _mediaRecoveryRunning = true;
      var shouldRetry = false;

      try {
        final success = await switchVideoPlayer(
          targetSource: currentSource,
          width:
              width ??
              (activePlayer.state.width > 0
                  ? activePlayer.state.width
                  : null),
          height:
              height ??
              (activePlayer.state.height > 0
                  ? activePlayer.state.height
                  : null),
          reloadSameSource: true,
          useCurrentVideoCdn: false,
          allowForcedHandoff: false,
          strictTimeout: const Duration(seconds: 8),
        );

        if (!success &&
            (generation != _dataSourceGeneration ||
                !identical(activePlayer, _videoPlayerController))) {
          return;
        }

        if (success) {
          _mediaRecoveryAttempt = 0;
        } else {
          _mediaRecoveryAttempt++;
          shouldRetry = true;
        }
      } catch (err, stackTrace) {
        if (generation != _dataSourceGeneration ||
            !identical(activePlayer, _videoPlayerController)) {
          return;
        }

        _mediaRecoveryAttempt++;
        shouldRetry = true;

        if (kDebugMode) {
          debugPrint('seamless media recovery failed: $err');
          debugPrint(stackTrace.toString());
        }
      } finally {
        _mediaRecoveryRunning = false;

        if (shouldRetry &&
            _playerCount > 0 &&
            generation == _dataSourceGeneration &&
            identical(activePlayer, _videoPlayerController)) {
          _scheduleSeamlessMediaRecovery();
        }
      }
    });
  }

  VideoController? get _visibleVideoController {
    if ((_standbyVideoOnTop || _standbyVideoOnly) &&
        _standbyVideoController != null) {
      return _standbyVideoController;
    }
    return _videoController;
  }

  int _bumpVideoOutputRevision() {
    final revision = videoOutputRevision.value + 1;
    videoOutputRevision.value = revision;
    return revision;
  }

  void acknowledgeVideoOutputPresentation(
    int revision,
    VideoController controller,
  ) {
    if (revision != videoOutputRevision.value ||
        !identical(controller, _visibleVideoController)) {
      return;
    }
    _presentedVideoOutputRevision = revision;
    _presentedVideoController = controller;
    if (_pendingVideoOutputRevision == revision &&
        identical(_pendingVideoOutputController, controller)) {
      final presentation = _pendingVideoOutputPresentation;
      if (presentation != null && !presentation.isCompleted) {
        presentation.complete();
      }
    }
  }

  Future<bool> _waitForVideoOutputPresentation(
    int revision,
    VideoController controller,
    Completer<void> cancellation,
  ) async {
    if (_presentedVideoOutputRevision == revision &&
        identical(_presentedVideoController, controller)) {
      return true;
    }

    final presentation = Completer<void>();
    _pendingVideoOutputRevision = revision;
    _pendingVideoOutputController = controller;
    _pendingVideoOutputPresentation = presentation;
    final presented = await Future.any<bool>([
      presentation.future.then((_) => true),
      cancellation.future.then((_) => false),
      Future<bool>.delayed(const Duration(seconds: 2), () => false),
    ]);
    if (identical(_pendingVideoOutputPresentation, presentation)) {
      _pendingVideoOutputRevision = null;
      _pendingVideoOutputController = null;
      _pendingVideoOutputPresentation = null;
    }
    return presented &&
        revision == videoOutputRevision.value &&
        identical(controller, _visibleVideoController);
  }

  Future<void> _waitForVideoOutputFrame() {
    return Future.any<void>([
      WidgetsBinding.instance.endOfFrame,
      Future<void>.delayed(const Duration(milliseconds: 250)),
    ]);
  }

  void _disposePlayerAfterOutputPresentation(
    Player player, {
    required int? revision,
    required VideoController? controller,
  }) {
    unawaited(() async {
      if (revision != null && controller != null) {
        await _waitForVideoOutputPresentation(
          revision,
          controller,
          Completer<void>(),
        );
      } else {
        await _waitForVideoOutputFrame();
      }
      try {
        await player.dispose();
      } catch (_) {
        // 切换取消或页面关闭时，播放器可能已由其它生命周期路径释放。
      }
    }());
  }

  void cancelVideoPlayerSwitch() {
    _videoPlayerSwitchGeneration++;
    final cancellation = _videoPlayerSwitchCancellation;
    _videoPlayerSwitchCancellation = null;
    if (cancellation != null && !cancellation.isCompleted) {
      cancellation.complete();
    }

    final standbyPlayer = _standbyVideoPlayerController;
    final hadStandbyOutput =
        _standbyVideoController != null ||
        _standbyVideoOnTop ||
        _standbyVideoOnly;
    _standbyVideoPlayerController = null;
    _standbyVideoController = null;
    _standbyVideoOnTop = false;
    _standbyVideoOnly = false;
    videoPlayerSwitching.value = false;
    int? outputRevision;
    if (hadStandbyOutput) {
      outputRevision = _bumpVideoOutputRevision();
    }
    if (standbyPlayer != null) {
      _disposePlayerAfterOutputPresentation(
        standbyPlayer,
        revision: outputRevision,
        controller: _visibleVideoController,
      );
    }
  }

  /// 使用第二个 mpv 实例预缓冲目标画质。
  ///
  /// 备用实例加载与当前实例相同的音频和媒体参数，静音播放并在当前画面
  /// 下方预先挂载纹理。只有首帧、前向缓存与时间同步均达到门槛后，才将
  /// 备用 Texture 提升到顶层；Flutter 确认新 Texture 可见且旧 Texture
  /// 已移除后，才把播放控制与音频交给同一实例。同源网络恢复可显式绕过
  /// 地址短路，并关闭未就绪时的强制交接。
  Media _mediaForNetworkSource(
    Media currentMedia,
    NetworkSource currentSource,
    NetworkSource targetSource,
    Duration start,
  ) {
    final extras = <String, String>{...?currentMedia.extras};
    if (targetSource.audioSource != currentSource.audioSource) {
      final audio = targetSource.audioSource;
      if (audio == null || audio.isEmpty) {
        extras.remove('audio-files');
        extras.remove('lavfi-complex');
      } else {
        extras['audio-files'] =
            '"${Platform.isWindows ? audio.replaceAll(';', r'\;') : audio.replaceAll(':', r'\:')}"';
      }
    }
    return currentMedia.copyWith(
      uri: targetSource.videoSource,
      extras: extras,
      start: start,
    );
  }

  Future<bool> switchVideoPlayer({
    required NetworkSource targetSource,
    required int? width,
    required int? height,
    bool reloadSameSource = false,
    bool useCurrentVideoCdn = true,
    bool allowForcedHandoff = true,
    Duration strictTimeout = const Duration(seconds: 30),
    VoidCallback? onVideoCdnFailure,
  }) async {
    final activePlayer = _videoPlayerController;
    final activeController = _videoController;
    final currentSource = dataSource;
    if (activePlayer == null ||
        activeController == null ||
        currentSource is! NetworkSource ||
        activePlayer.current.isEmpty ||
        onlyPlayAudio.value ||
        _playerCount == 0) {
      return false;
    }
    final resolvedTargetSource = useCurrentVideoCdn
        ? targetSource.atCdnIndex(_currentVideoCdnIndex)
        : targetSource;
    if (!reloadSameSource &&
        currentSource.videoSource == resolvedTargetSource.videoSource) {
      return true;
    }

    final activeStateAtSwitchStart = activePlayer.state;
    // A failed initial open has no valid frame, output geometry, or playback
    // clock to align against. This exception is limited to recovery reloads;
    // normal quality switches and recoveries from an already rendered player
    // continue to use the strict two-player handoff.
    final activeMediaNeverLoaded =
        reloadSameSource &&
        (activeStateAtSwitchStart.width <= 0 ||
            activeStateAtSwitchStart.height <= 0);

    cancelVideoPlayerSwitch();
    final generation = ++_videoPlayerSwitchGeneration;
    final dataSourceGeneration = _dataSourceGeneration;
    final mpvLogSession = _mpvLogSession;
    final cancellation = Completer<void>();
    _videoPlayerSwitchCancellation = cancellation;
    videoPlayerSwitching.value = true;

    bool isCurrentSwitch() =>
        generation == _videoPlayerSwitchGeneration &&
        dataSourceGeneration == _dataSourceGeneration &&
        identical(activePlayer, _videoPlayerController) &&
        _playerCount > 0 &&
        !onlyPlayAudio.value &&
        !cancellation.isCompleted;

    Duration activeHandoffPosition() {
      final position =
          _pausedForVideoStall && _videoStallPosition != null
          ? _videoStallPosition!
          : activePlayer.state.position;
      final postSeekTarget =
          identical(activePlayer, _postSeekWatchdogGuardPlayer)
          ? _postSeekWatchdogGuardTarget
          : null;

      // seek 尚未完成时若遇到明确的网络错误，备用实例也必须从 seek
      // 目标或更后的位置接管，不能重新打开到 seek 前的旧播放位置。
      if (postSeekTarget != null && position < postSeekTarget) {
        return postSeekTarget;
      }
      return position;
    }

    late final Player standbyPlayer;
    late final VideoController standbyController;
    var standbyCreated = false;
    var standbyRegistered = false;
    var committed = false;
    var activeListenersDetached = false;
    var resumeActiveOnFailure = false;
    StreamSubscription<PlayerLog>? standbyInitializationLogSubscription;
    StreamSubscription<PlayerLog>? standbyCdnLogSubscription;
    StreamSubscription<String>? standbyCdnErrorSubscription;
    var standbyVideoCdnFailed = false;
    var standbyUnattributedTlsFailure = false;

    try {
      final pair = await _createPlayerPair(
        muted: true,
        logSession: mpvLogSession,
      );
      standbyPlayer = pair.player;
      standbyController = pair.videoController;
      standbyInitializationLogSubscription =
          pair.initializationLogSubscription;
      standbyCreated = true;
      void markStandbyVideoCdnFailure() {
        if (standbyVideoCdnFailed) {
          return;
        }
        standbyVideoCdnFailed = true;
        onVideoCdnFailure?.call();
      }

      void inspectStandbyCdnFailure(String prefix, String message) {
        final text = '$prefix $message';
        if (_isExplicitVideoOpenFailure(resolvedTargetSource, text)) {
          markStandbyVideoCdnFailure();
          return;
        }
        if (!_isTlsHandshakeFailure(prefix, message)) {
          return;
        }
        if (_isExternalAudioFailure(resolvedTargetSource, text)) {
          return;
        }
        if (_messageReferencesUrl(
              text,
              resolvedTargetSource.videoSource,
            ) ||
            resolvedTargetSource.audioSource?.isNotEmpty != true) {
          markStandbyVideoCdnFailure();
        } else {
          // 先记下没有 URL 的 TLS 错误，但不立即判死整个实例。若视频随后
          // 成功出画，说明该错误不能归因给主视频；若始终没有视频输出，
          // finally 会把它确认为候选 CDN 的视频打开失败。
          standbyUnattributedTlsFailure = true;
        }
      }

      standbyCdnLogSubscription = standbyPlayer.stream.log.listen((log) {
        inspectStandbyCdnFailure(log.prefix, log.text);
      });
      standbyCdnErrorSubscription = standbyPlayer.stream.error.listen((event) {
        if (_isExternalAudioFailure(resolvedTargetSource, event)) {
          return;
        }
        inspectStandbyCdnFailure('', event);
      });
      if (!isCurrentSwitch()) {
        return false;
      }

      _standbyVideoPlayerController = standbyPlayer;
      _standbyVideoController = standbyController;
      standbyRegistered = true;
      _bumpVideoOutputRevision();

      if (isAnim && superResolutionType.value != .disable) {
        await setShader(null, standbyPlayer);
        if (!isCurrentSwitch()) {
          return false;
        }
      }

      final currentMedia = activePlayer.current.last;
      final startPosition = activeHandoffPosition();
      MpvUtils.applyRuntimeOverrides(standbyPlayer);
      standbyPlayer
        ..setProperty('mute', 'yes')
        ..setProperty('volume', '0');
      await standbyPlayer.open(
        _mediaForNetworkSource(
          currentMedia,
          currentSource,
          resolvedTargetSource,
          startPosition,
        ),
        play: false,
      );
      _bumpVideoOutputRevision();
      if (!isCurrentSwitch()) {
        return false;
      }

      // 先在暂停态完成媒体打开，再强制静音并开始解码，避免用户的自定义
      // mpv 参数或逐文件参数让备用实例在预缓冲阶段短暂出声。
      standbyPlayer
        ..setProperty('mute', 'yes')
        ..setProperty('volume', '0');
      await standbyPlayer.setRate(activePlayer.state.rate);
      await standbyPlayer.play();

final forceTimeoutSeconds = allowForcedHandoff
    ? Pref.videoPlayerSwitchForceTimeoutSeconds
    : 0;

final forceDeadline = forceTimeoutSeconds > 0
    ? DateTime.now().add(
        Duration(seconds: forceTimeoutSeconds),
      )
    : null;

var forceHandoff = false;

var firstFrameRendered = false;
      var firstFrameFailed = false;
      final requireConfiguredAndroidOutput =
          Platform.isAndroid && Pref.useMpvVideoScaling;
      Rect? configuredOutputRect;
      Duration? positionWhenOutputConfigured;
      var renderedAfterOutputConfiguration =
          !requireConfiguredAndroidOutput;

      bool standbyOutputReady() {
        if (!requireConfiguredAndroidOutput) {
          return true;
        }

        final standbyRect = standbyController.rect.value;
        // When the initial player never loaded, validate the standby output's
        // own configured Surface instead of waiting for an invalid active rect.
        final targetRect = activeMediaNeverLoaded
            ? standbyRect
            : activeController.rect.value;
        if (targetRect == null ||
            targetRect.width <= 1 ||
            targetRect.height <= 1) {
          configuredOutputRect = null;
          positionWhenOutputConfigured = null;
          renderedAfterOutputConfiguration = false;
          return false;
        }

        final rectMatches =
            standbyRect != null &&
            (standbyRect.width - targetRect.width).abs() < 0.5 &&
            (standbyRect.height - targetRect.height).abs() < 0.5;

        if (!rectMatches) {
          configuredOutputRect = null;
          positionWhenOutputConfigured = null;
          renderedAfterOutputConfiguration = false;
          return false;
        }

        if (configuredOutputRect != targetRect ||
            positionWhenOutputConfigured == null) {
          configuredOutputRect = targetRect;
          positionWhenOutputConfigured = standbyPlayer.state.position;
          renderedAfterOutputConfiguration = false;
          return false;
        }

        if (!renderedAfterOutputConfiguration) {
          final progress =
              (standbyPlayer.state.position - positionWhenOutputConfigured!)
                  .inMilliseconds
                  .abs();
          renderedAfterOutputConfiguration = progress >= 20;
        }
        return renderedAfterOutputConfiguration;
      }

      unawaited(
        standbyController.waitUntilFirstFrameRendered.then<void>(
          (_) => firstFrameRendered = true,
          onError: (_) {
            firstFrameFailed = true;
          },
        ),
      );
bool canForceHandoff() {
  final state = standbyPlayer.state;

  return !firstFrameFailed &&
      (firstFrameRendered ||
          (state.width > 0 && state.height > 0) ||
          state.duration > Duration.zero);
}
      final configuredWait =
          double.tryParse(activePlayer.getProperty('cache-pause-wait')) ?? 1.0;
      final requiredBufferSeconds =
          max(1.0, configuredWait) * max(1.0, activePlayer.state.rate);
      final strictDeadline = DateTime.now().add(
  Duration(
    seconds: max(
      strictTimeout.inSeconds,
      (requiredBufferSeconds * 4).ceil(),
    ),
  ),
);

      double requiredBufferAt(Duration target) {
        final mediaDuration = activePlayer.state.duration;
        if (mediaDuration <= Duration.zero) {
          return requiredBufferSeconds;
        }
        final remaining =
            (mediaDuration - target).inMilliseconds /
            Duration.millisecondsPerSecond;
        return max(0.25, min(requiredBufferSeconds, remaining));
      }

      var bufferReady = false;

while (isCurrentSwitch()) {
  final now = DateTime.now();

  if (standbyVideoCdnFailed) {
    return false;
  }

  // 明确的渲染错误属于硬失败，不能强制接管。
  if (firstFrameFailed) {
    return false;
  }

  // 开启强制接管后，以用户设置的总等待时间为准。
  // 到达强制接管时间后，必须先确认备用实例已经识别到媒体。
// 如果连首帧、分辨率和时长都没有获得，说明它可能根本没有打开成功，
// 此时保留仍能播放的旧实例。
if (forceDeadline != null &&
    !now.isBefore(forceDeadline)) {
  if (!canForceHandoff()) {
    return false;
  }

  forceHandoff = true;
  break;
}

  // 设置为 0 时维持原来的严格超时逻辑。
  if (forceDeadline == null &&
      !now.isBefore(strictDeadline)) {
    break;
  }

  final target = activeHandoffPosition();
  final bufferedAhead =
      (standbyPlayer.state.buffer - target).inMilliseconds /
      Duration.millisecondsPerSecond;

  if (firstFrameRendered &&
      standbyOutputReady() &&
      standbyPlayer.state.width > 0 &&
      standbyPlayer.state.height > 0 &&
      !standbyPlayer.state.buffering &&
      standbyPlayer.getProperty('paused-for-cache') != 'yes' &&
      bufferedAhead >= requiredBufferAt(target)) {
    bufferReady = true;
    break;
  }

  final keepWaiting = await Future.any<bool>([
    Future<bool>.delayed(
      const Duration(milliseconds: 40),
      () => true,
    ),
    cancellation.future.then((_) => false),
  ]);

  if (!keepWaiting) {
    return false;
  }
}

if ((!bufferReady && !forceHandoff) ||
    !isCurrentSwitch()) {
  return false;
}

            // 备用实例已经从旧实例当时的位置开始播放，并使用相同倍速。
      // 正常情况下两个实例会自然保持同步，不能在短时间内循环 seek。
      // AV1/HEVC 连续 seek 会反复清空解码与缓存队列，导致备用实例
      // 一直处于 buffering，最终无法完成交接。
      final shouldPlay = activeMediaNeverLoaded
          ? _autoPlay
          : activePlayer.state.playing;
      final targetRate = activePlayer.state.rate;

      if (standbyPlayer.state.rate != targetRate) {
        await standbyPlayer.setRate(targetRate);
      }

      if (!shouldPlay && standbyPlayer.state.playing) {
        await standbyPlayer.pause();
      }

      var target = activeHandoffPosition();
      var drift =
          (standbyPlayer.state.position - target).inMilliseconds.abs();

      // 播放状态下只有偏差明显时才执行一次 seek。
      // 暂停状态下则必须回到旧播放器当前的静止位置。
      if (!activeMediaNeverLoaded &&
          (forceHandoff || !shouldPlay || drift > 400)) {
  try {
    // 强制接管时将备用实例跳到旧实例的最新位置。
    // 之后即使缓存不足，也由新实例走正常 buffering 流程。
    await standbyPlayer.seek(target);
  } catch (_) {
    // 严格模式下 seek 失败仍然中止。
    // 强制模式下允许交接，让播放器后续自行恢复。
    if (!forceHandoff) {
      rethrow;
    }
  }

  if (shouldPlay && !standbyPlayer.state.playing) {
    await standbyPlayer.play();
  }
}

      final alignmentDeadline = forceDeadline ??
    DateTime.now().add(
      const Duration(seconds: 3),
    );

var aligned = forceHandoff || activeMediaNeverLoaded;

      while (!forceHandoff &&
    !activeMediaNeverLoaded &&
    isCurrentSwitch() &&
    DateTime.now().isBefore(alignmentDeadline)) {
        if (standbyVideoCdnFailed) {
          return false;
        }
        target = activeHandoffPosition();
        drift =
            (standbyPlayer.state.position - target).inMilliseconds.abs();

        final bufferedAhead =
            (standbyPlayer.state.buffer - target).inMilliseconds /
            Duration.millisecondsPerSecond;

        // media_kit/mpv 的 position 状态并不是逐帧更新。
        // 播放状态下使用 450 ms 容差，避免状态采样延迟导致永远不交接。
        final allowedDrift = shouldPlay ? 450 : 150;

        if (!standbyPlayer.state.buffering &&
            standbyPlayer.getProperty('paused-for-cache') != 'yes' &&
            drift <= allowedDrift &&
            bufferedAhead >= min(0.25, requiredBufferAt(target))) {
          aligned = true;
          break;
        }

        final keepWaiting = await Future.any<bool>([
          Future<bool>.delayed(
            const Duration(milliseconds: 40),
            () => true,
          ),
          cancellation.future.then((_) => false),
        ]);

        if (!keepWaiting) {
          return false;
        }
      }
if (!aligned &&
    forceDeadline != null &&
    !DateTime.now().isBefore(forceDeadline)) {
  forceHandoff = true;
  aligned = true;
}
      if (!aligned || !isCurrentSwitch()) {
        return false;
      }

      final handoffPlaying = activeMediaNeverLoaded
          ? _autoPlay
          : _pausedForVideoStall
          ? _resumeAfterVideoRecovery
          : activePlayer.state.playing;
      final handoffRate = activePlayer.state.rate;
      final activeVolumeProperty = activePlayer.getProperty('volume');
      final activeMuteProperty = activePlayer.getProperty('mute');
      final handoffVolume = activeVolumeProperty.isEmpty
          ? activePlayer.state.volume.toString()
          : activeVolumeProperty;
      final handoffMute = activeMuteProperty.isEmpty
          ? (isMuted ? 'yes' : 'no')
          : activeMuteProperty;

      if (standbyPlayer.state.rate != handoffRate) {
        await standbyPlayer.setRate(handoffRate);
      }
      if (!handoffPlaying && standbyPlayer.state.playing) {
        await standbyPlayer.pause();
      } else if (handoffPlaying && !standbyPlayer.state.playing) {
        await standbyPlayer.play();
      }
      if (!isCurrentSwitch()) {
        return false;
      }

      final handoffDrift =
          (standbyPlayer.state.position - activeHandoffPosition())
              .inMilliseconds
              .abs();

      final allowedHandoffDrift = handoffPlaying ? 450 : 150;

      if (!forceHandoff &&
    (standbyPlayer.state.buffering ||
        standbyPlayer.getProperty('paused-for-cache') == 'yes' ||
        (!activeMediaNeverLoaded &&
            handoffDrift > allowedHandoffDrift))) {
  return false;
}
// 真正停止旧实例前再次确认切换仍有效。
// 强制等待期间页面、数据源或备用实例状态都可能已经发生变化。
if (!isCurrentSwitch() ||
    standbyVideoCdnFailed ||
    firstFrameFailed ||
    (!forceHandoff && !standbyOutputReady()) ||
    (forceHandoff && !canForceHandoff())) {
  return false;
}
      // 备用实例始终静音运行。先停止旧实例，再把已经挂载的备用 Texture
      // 提升到顶层；只有 Flutter 在帧后确认该实例确实成为可见输出，才切换
      // 播放控制并恢复同一实例的音频，避免画面与音频落在不同播放器上。
      resumeActiveOnFailure = handoffPlaying;
      await _removeListeners();
      activeListenersDetached = true;
      await activePlayer.pause();
      _standbyVideoOnTop = true;
      final promotedRevision = _bumpVideoOutputRevision();
      final standbyPresented = await _waitForVideoOutputPresentation(
        promotedRevision,
        standbyController,
        cancellation,
      );
      if (!standbyPresented ||
          standbyVideoCdnFailed ||
          firstFrameFailed ||
          !isCurrentSwitch()) {
        _standbyVideoOnTop = false;
        _bumpVideoOutputRevision();
        throw StateError('standby Texture was not presented');
      }

      // 再让 Flutter 暂时只绘制备用输出。此时播放控制仍属于旧实例，
      // 因而取消切换或换源不会观察到播放器与 VideoController 不一致。
      _standbyVideoOnTop = false;
      _standbyVideoOnly = true;
      final committedOutputRevision = _bumpVideoOutputRevision();
      final committedOutputPresented = await _waitForVideoOutputPresentation(
        committedOutputRevision,
        standbyController,
        cancellation,
      );
      if (!committedOutputPresented ||
          standbyVideoCdnFailed ||
          firstFrameFailed ||
          !isCurrentSwitch()) {
        _standbyVideoOnly = false;
        _bumpVideoOutputRevision();
        throw StateError('committed Texture was not presented');
      }

      _standbyVideoPlayerController = null;
      _standbyVideoController = null;
      _standbyVideoOnly = false;
      _videoPlayerController = standbyPlayer;
      _videoController = standbyController;
      _bumpVideoOutputRevision();
      dataSource = NetworkSource(
        videoSource: resolvedTargetSource.videoSource,
        audioSource: resolvedTargetSource.audioSource,
        cdnVideoSources: resolvedTargetSource.cdnVideoSources,
        cdnAudioSources: resolvedTargetSource.cdnAudioSources,
        cdnIndex: resolvedTargetSource.cdnIndex,
      );
      _currentVideoCdnIndex = resolvedTargetSource.cdnIndex;
      this.width = width;
      this.height = height;
      committed = true;

      isBuffering.value =
    standbyPlayer.state.buffering ||
    standbyPlayer.getProperty('paused-for-cache') == 'yes';
      position.value = standbyPlayer.state.position.inSeconds;
      buffered.value = standbyPlayer.state.buffer.inSeconds;
      updateDuration(standbyPlayer.state.duration);
      await standbyInitializationLogSubscription?.cancel();
      standbyInitializationLogSubscription = null;
      if (mpvLogSession != null) {
        MpvLogService.attachPlayer(
          standbyPlayer,
          session: mpvLogSession,
        );
      }
      _startListeners(standbyPlayer);
      activeListenersDetached = false;

_videoNetworkFailed = false;
_pausedForVideoStall = false;
_videoStallSince = null;
_videoStallPosition = null;

// 必须在新播放器监听器挂载后再确定最终的界面状态，
// 避免监听器订阅时的初始事件覆盖该状态。
playerStatus.value = handoffPlaying ? .playing : .paused;
      _resumeAfterVideoRecovery = false;
      videoPlayerServiceHandler
        ?..onPositionChange(standbyPlayer.state.position)
        ..onStatusChange(playerStatus.value, isBuffering.value, isLive);

      // Flutter 已确认显示的是 standbyController 后，才恢复同一 mpv
      // 实例的真实音量。旧实例保持暂停，因而不存在跨实例音画组合。
      standbyPlayer
        ..setProperty('volume', handoffVolume)
        ..setProperty('mute', handoffMute);
      try {
        await activePlayer.dispose();
      } catch (_) {
        // 新实例已经接管播放，旧实例释放失败不应回滚已完成的切换。
      }
      if (mpvLogSession != null) {
        MpvLogService.detachPlayer(
          activePlayer,
          session: mpvLogSession,
        );
      }
      return true;
    } catch (err, stackTrace) {
      final switchError = err.toString();
      if (_isExplicitVideoOpenFailure(
            resolvedTargetSource,
            switchError,
          ) ||
          (_isTlsHandshakeFailure('', switchError) &&
              !_isExternalAudioFailure(
                resolvedTargetSource,
                switchError,
              ))) {
        onVideoCdnFailure?.call();
      }
      if (kDebugMode) {
        debugPrint('switch video player failed: $err');
        debugPrint(stackTrace.toString());
      }
      if (!committed &&
          activeListenersDetached &&
          identical(activePlayer, _videoPlayerController)) {
        try {
          if (standbyCreated) {
            standbyPlayer
              ..setProperty('mute', 'yes')
              ..setProperty('volume', '0');
          }
          _standbyVideoOnTop = false;
          _standbyVideoOnly = false;
          final rollbackRevision = _bumpVideoOutputRevision();
          await _waitForVideoOutputPresentation(
            rollbackRevision,
            activeController,
            Completer<void>(),
          );
          if (!identical(activePlayer, _videoPlayerController) ||
              _playerCount == 0) {
            return committed;
          }
          _startListeners(activePlayer);
          if (resumeActiveOnFailure && !activePlayer.state.playing) {
            await activePlayer.play();
          }
          playerStatus.value = resumeActiveOnFailure ? .playing : .paused;
        } catch (_) {
          // 交接失败时尽力恢复旧实例；页面销毁路径无需继续恢复。
        }
      }
      return committed;
    } finally {
      if (!committed &&
          standbyCreated &&
          !standbyVideoCdnFailed &&
          standbyUnattributedTlsFailure &&
          generation == _videoPlayerSwitchGeneration &&
          dataSourceGeneration == _dataSourceGeneration &&
          !cancellation.isCompleted &&
          (standbyPlayer.state.width <= 0 ||
              standbyPlayer.state.height <= 0)) {
        onVideoCdnFailure?.call();
      }
      await standbyInitializationLogSubscription?.cancel();
      await standbyCdnLogSubscription?.cancel();
      await standbyCdnErrorSubscription?.cancel();
      if (!committed && standbyCreated) {
        if (mpvLogSession != null) {
          MpvLogService.detachPlayer(
            standbyPlayer,
            session: mpvLogSession,
          );
        }
        if (identical(_standbyVideoPlayerController, standbyPlayer)) {
          _standbyVideoPlayerController = null;
          _standbyVideoController = null;
          _standbyVideoOnTop = false;
          _standbyVideoOnly = false;
          final removalRevision = _bumpVideoOutputRevision();
          final visibleController = _visibleVideoController;
          if (visibleController != null) {
            await _waitForVideoOutputPresentation(
              removalRevision,
              visibleController,
              Completer<void>(),
            );
          } else {
            await _waitForVideoOutputFrame();
          }
          try {
            await standbyPlayer.dispose();
          } catch (_) {
            // 失败路径只需确保备用播放器不再占用资源。
          }
        } else if (!standbyRegistered) {
          try {
            await standbyPlayer.dispose();
          } catch (_) {
            // 创建完成但尚未挂载时直接释放。
          }
        }
      }
      if (identical(_videoPlayerSwitchCancellation, cancellation)) {
        _videoPlayerSwitchCancellation = null;
        videoPlayerSwitching.value = false;
      }
    }
  }

  // 开始播放
  Future<void> _initializePlayer(
    bool Function() isCurrentDataSource,
    _InitialPlayGate? initialPlayGate,
  ) async {
    if (_instance == null || !isCurrentDataSource()) return;
    // 设置倍速
    if (isLive) {
      await setPlaybackSpeed(1.0);
    } else {
      if (_videoPlayerController?.state.rate != _playbackSpeed.value) {
        await setPlaybackSpeed(_playbackSpeed.value);
      }
    }
    if (!isCurrentDataSource()) return;
    _initVideoFit();
    // if (_looping) {
    //   await setLooping(_looping);
    // }

    // 跳转播放
    // if (seekTo != Duration.zero) {
    //   await this.seekTo(seekTo);
    // }

    // 自动播放
    if (_autoPlay && isCurrentDataSource()) {
      final gate = initialPlayGate;
      final player = _videoPlayerController;
      if (gate == null ||
          player == null ||
          !identical(gate.player, player)) {
        await playIfExists();
        return;
      }
      await _releaseInitialPlayGate(gate, isCurrentDataSource);
    }
  }

  List<StreamSubscription>? _subscriptions;
  final Set<ValueChanged<Duration>> _positionListeners = {};
  final Set<ValueChanged<PlayerStatus>> _statusListeners = {};

  void _publishLogicalPlayingState(NativePlayer player, bool playing) {
    WakelockPlus.toggle(enable: playing);
    if (playing) {
      if (_isAutoEnterPip) {
        if (_isCurrVideoPage) {
          enterPip(autoEnter: true);
        } else {
          _disableAutoEnterPip();
        }
      }
      playerStatus.value = .playing;
      _maybeStartPlaybackHistory(player);
    } else {
      _disableAutoEnterPip();
      playerStatus.value = .paused;
    }

    if (_historySessionStarted) {
      unawaited(
        PlaybackHistoryTracker.instance.setActive(
          playing && !isBuffering.value,
        ),
      );
    }

    videoPlayerServiceHandler?.onStatusChange(
      playerStatus.value,
      isBuffering.value,
      isLive,
    );

    for (final element in _statusListeners) {
      element(playing ? .playing : .paused);
    }
  }

  /// 播放事件监听
  void _startListeners(NativePlayer player) {
    assert(_subscriptions == null);
    _startVideoStallWatchdog(player);
    final stream = player.stream;
    _subscriptions = [
      /// playing
      stream.playing.listen((bool playing) {
        // 双播放器交接后，旧实例的延迟事件不得再修改全局播放状态。
        if (!identical(player, _videoPlayerController)) {
          return;
        }

        final logicalPlaying =
            playing ||
            (_pausedForVideoStall && _resumeAfterVideoRecovery);
        _publishLogicalPlayingState(player, logicalPlaying);

        final seconds = videoPlayerController!.state.position.inSeconds;
        if (seconds != 0) {
          makeHeartBeat(seconds, type: .status);
        }
      }),

      ///completed
      stream.completed.listen((bool completed) {
        if (completed) {
          playerStatus.value = .completed;
          if (playRepeat == PlayRepeat.pause) {
            controls = true;
          }

          for (final element in _statusListeners) {
            element(.completed);
          }

          makeHeartBeat(-1, type: .completed);
          _historySessionStarted = false;
          unawaited(PlaybackHistoryTracker.instance.end());
        }
      }),

      /// position
      stream.position.listen((Duration position) {
        final posInSeconds = position.inSeconds;

        if (posInSeconds != this.position.value) {
          if (!isSeeking.value) {
            this.position.value = posInSeconds;
          }

          videoPlayerServiceHandler?.onPositionChange(position);

          makeHeartBeat(posInSeconds);
        }

        for (final element in _positionListeners) {
          element(position);
        }
        _maybeStartPlaybackHistory(player);
      }),
      stream.duration.listen(updateDuration),
      stream.buffer.listen((Duration buffer) {
        buffered.value = buffer.inSeconds;
      }),
      stream.buffering.listen((bool buffering) {
        isBuffering.value = buffering;
        if (!buffering) {
          _maybeStartPlaybackHistory(player);
        }
        if (_historySessionStarted) {
          unawaited(
            PlaybackHistoryTracker.instance.setActive(
              player.state.playing && !buffering,
            ),
          );
        }
        videoPlayerServiceHandler?.onStatusChange(
          playerStatus.value,
          buffering,
          isLive,
        );
      }),
      stream.log.listen((PlayerLog log) {
        MpvLogService.add(player, log);
        _handleVideoCdnFailure(player, log.prefix, log.text);
        _handleVideoPipelineLog(player, log);
        if (kDebugMode) {
          if (log.level == 'error' || log.level == 'fatal') {
            Utils.reportError('${log.level}: ${log.prefix}: ${log.text}', null);
          } else {
            debugPrint(log.toString());
          }
        }
      }),
      stream.error.listen((String event) {
        // 交接完成后，旧实例的延迟错误不能触发新一轮恢复。
        if (!identical(player, _videoPlayerController)) {
          return;
        }

        if (dataSource is FileSource &&
            event.startsWith("Failed to open file")) {
          return;
        }
        if (isLive) {
          if (event.startsWith('tcp: ffurl_read returned ') ||
              event.startsWith("Failed to open https://") ||
              event.startsWith("Can not open external file https://")) {
            Future.delayed(const Duration(milliseconds: 3000), refreshPlayer);
          }
          return;
        }
        final source = dataSource;
        if (source is NetworkSource &&
            _isExternalAudioFailure(source, event)) {
          return;
        }
        if (_handleVideoCdnFailure(player, '', event)) {
          return;
        }
        if (_isTlsHandshakeFailure('', event)) {
          // 存在外置音轨且错误没有 URL 时无法确定是哪条链路，
          // 继续交给视频停滞看门狗判定，不能误触发整媒体恢复。
          return;
        }
        if (source is NetworkSource &&
            _isRetryableVideoMediaError(source, event)) {
          _videoNetworkFailed = true;
          _scheduleSeamlessMediaRecovery();
          return;
        } else if (event.startsWith('Could not open codec')) {
          SmartDialog.showToast('无法加载解码器, $event，可能会切换至软解');
        } else if (!onlyPlayAudio.value) {
          if (event.startsWith("error running") ||
              event.startsWith("Failed to open .") ||
              event.startsWith("Cannot open") ||
              event.startsWith("Can not open")) {
            return;
          }
          Utils.reportError(event);
          // SmartDialog.showToast('视频加载错误, $event');
        }
      }),
    ];
  }

  void _maybeStartPlaybackHistory(Player player) {
    if (_historySessionStarted ||
        !identical(player, _videoPlayerController) ||
        isLive ||
        isFileSource) {
      return;
    }
    final state = player.state;
    if (!state.playing || state.buffering) {
      return;
    }
    if (state.position <= Duration.zero &&
        state.duration <= Duration.zero &&
        (state.width <= 0 || state.height <= 0)) {
      return;
    }

    final videoKey = playbackVideoKey(
      aid: _aid,
      epId: _epid,
      isPgc: _videoType != VideoType.ugc,
    );
    if (videoKey == null) {
      return;
    }

    _historySessionStarted = true;
    final generation = _dataSourceGeneration;
    unawaited(
      _beginPlaybackHistory(
        generation: generation,
        videoKey: videoKey,
        active: state.playing && !state.buffering,
      ),
    );
  }

  Future<void> _beginPlaybackHistory({
    required int generation,
    required String videoKey,
    required bool active,
  }) async {
    try {
      await PlaybackHistoryTracker.instance.begin(
        scopeId: currentRecommendHistoryScope(),
        videoKey: videoKey,
        active: active,
      );
      if (generation == _dataSourceGeneration && _historySessionStarted) {
        await PlaybackHistoryTracker.instance.setActive(
          playerStatus.isPlaying && !isBuffering.value,
        );
      }
    } catch (_) {
      if (generation == _dataSourceGeneration) {
        _historySessionStarted = false;
      }
    }
  }

  /// 移除事件监听
  Future<void> _removeListeners() async {
  _videoStallWatchdogTimer?.cancel();
  _videoStallWatchdogTimer = null;
  _resetVideoStallObservation();

  final subscriptions = _subscriptions;
  _subscriptions = null;

  if (subscriptions == null) {
    return;
  }

  await Future.wait<void>(
    subscriptions.map((subscription) => subscription.cancel()),
  );

  subscriptions.clear();
}

  void _cancelSubForSeek() {
    if (_subForSeek != null) {
      _subForSeek!.cancel();
      _subForSeek = null;
    }
  }

  /// 跳转至指定位置
  Future<void> seekTo(Duration position, {bool isSeek = true}) async {
    if (_playerCount == 0) {
      return;
    }
    if (position < Duration.zero) {
      position = Duration.zero;
    }
    _heartDuration = position.inSeconds;

    Future<void> seek() async {
      final player = _videoPlayerController;
      final guardGeneration = _beginPostSeekWatchdogGuard(
        player,
        position,
      );
      try {
        if (isSeek) {
          /// 拖动进度条调节时，不等待第一帧，防止抖动
          await player?.stream.buffer.first;
        }
        danmakuController?.clear();
        await player?.seek(position);
      } catch (e) {
        _clearPostSeekWatchdogGuard(generation: guardGeneration);
        if (kDebugMode) debugPrint('seek failed: $e');
      }
    }

    if (duration.value != 0) {
      seek();
    } else {
      // if (kDebugMode) debugPrint('seek duration else');
      _subForSeek?.cancel();
      _subForSeek = duration.listen((_) {
        seek();
        _cancelSubForSeek();
      });
    }
  }

  /// 设置倍速
  Future<void> setPlaybackSpeed(double speed) async {
    lastPlaybackSpeed = playbackSpeed;

    if (speed == _videoPlayerController?.state.rate) {
      return;
    }

    await _videoPlayerController?.setRate(speed);
    _playbackSpeed.value = speed;
    if (danmakuController != null) {
      try {
        DanmakuOption currentOption = danmakuController!.option;
        double defaultDuration = currentOption.duration * lastPlaybackSpeed;
        double defaultStaticDuration =
            currentOption.staticDuration * lastPlaybackSpeed;
        DanmakuOption updatedOption = currentOption.copyWith(
          duration: defaultDuration / speed,
          staticDuration: defaultStaticDuration / speed,
        );
        danmakuController!.updateOption(updatedOption);
      } catch (_) {}
    }
  }

  // 还原默认速度
  double playSpeedDefault = Pref.playSpeedDefault;
  Future<void> setDefaultSpeed() async {
    await _videoPlayerController?.setRate(playSpeedDefault);
    _playbackSpeed.value = playSpeedDefault;
  }

  /// 播放视频
  Future<void> play({bool repeat = false, bool hideControls = true}) async {
    if (_playerCount == 0) return;
    final initialGate = _initialPlayGate;
    if (initialGate != null &&
        initialGate.active &&
        _initialPlayReleaseGeneration != initialGate.generation) {
      await _releaseInitialPlayGate(
        initialGate,
        () =>
            initialGate.generation == _dataSourceGeneration &&
            identical(initialGate.player, _videoPlayerController) &&
            (_loadedVideoPageTag == null ||
                isVideoPageActive(_loadedVideoPageTag!)),
      );
      return;
    }

    if (_pausedForVideoStall) {
      _resumeAfterVideoRecovery = true;
      isBuffering.value = true;
      if (_videoPlayerController case final player?) {
        _publishLogicalPlayingState(player, true);
      }
      audioSessionHandler?.setActive(true);
      _scheduleSeamlessMediaRecovery();
      return;
    }

    // 播放时自动隐藏控制条
    controls = !hideControls;
    // repeat为true，将从头播放
    if (repeat) {
      // await seekTo(Duration.zero);
      await seekTo(Duration.zero, isSeek: false);
    }

    await _videoPlayerController?.play();

    audioSessionHandler?.setActive(true);

    playerStatus.value = PlayerStatus.playing;
    // screenManager.setOverlays(false);
  }

  /// 暂停播放
  Future<void> pause({bool notify = true, bool isInterrupt = false}) async {
    if (_pausedForVideoStall) {
      _resumeAfterVideoRecovery = false;
      if (_videoPlayerController case final player?) {
        _publishLogicalPlayingState(player, false);
      } else {
        playerStatus.value = PlayerStatus.paused;
      }

      if (!isInterrupt) {
        audioSessionHandler?.setActive(false);
      }
      return;
    }

    await _videoPlayerController?.pause();
    playerStatus.value = PlayerStatus.paused;

    // 主动暂停时让出音频焦点
    if (!isInterrupt) {
      audioSessionHandler?.setActive(false);
    }
  }

  bool tripling = false;

  /// 隐藏控制条
  void hideTaskControls() {
    _timer?.cancel();
    _timer = Timer(showControlDuration, () {
      if (!isSeeking.value && !tripling) {
        controls = false;
      }
      _timer = null;
    });
  }
void onSeekStart({bool fromGesture = false}) {
  final currentPosition =
      videoPlayerController?.state.position.inSeconds ?? position.value;

  seekStartPosition.value = duration.value > 0
      ? currentPosition.clamp(0, duration.value).toInt()
      : currentPosition < 0
      ? 0
      : currentPosition;

  isGestureSeeking.value = fromGesture;
  isSeeking.value = true;
}
  void onSeekEnd() {
    if (seekToPos != null) {
      feedBack();
    }
    if (showAnySeekPreview) {
      showPreview.value = false;
      previewGlobalX.value = null;
      _pendingPreviewSeconds = null;
    }
    hasToasted = false;
      isGestureSeeking.value = false;
    isSeeking.value = false;
    hideTaskControls();
  }

  final RxBool volumeIndicator = false.obs;
  Timer? volumeTimer;
  bool volumeInterceptEventStream = false;

  final double maxVolume = PlatformUtils.isDesktop ? Pref.maxVolume : 1.0;
  Future<void> setVolume(double volume, {bool showIndicator = true}) async {
    if (this.volume.value != volume) {
      this.volume.value = volume;
      try {
        if (PlatformUtils.isDesktop) {
          await _videoPlayerController!.setVolume(volume * 100);
        } else {
          FlutterVolumeController.updateShowSystemUI(false);
          await FlutterVolumeController.setVolume(volume);
        }
      } catch (err) {
        if (kDebugMode) debugPrint(err.toString());
      }
    }
    if (showIndicator) {
      volumeIndicator.value = true;
    }
    volumeInterceptEventStream = true;
    volumeTimer?.cancel();
    volumeTimer = Timer(const Duration(milliseconds: 200), () {
      volumeIndicator.value = false;
      volumeInterceptEventStream = false;
      if (PlatformUtils.isDesktop) {
        setting.put(SettingBoxKey.desktopVolume, volume.toPrecision(3));
      }
    });
  }

  /// Toggle Change the videofit accordingly
  void toggleVideoFit(VideoFitType value) {
    _prefFit = videoFit.value = value;
    video.put(VideoBoxKey.cacheVideoFit, value.index);
  }

  /// 读取fit
  var _prefFit = VideoFitType.values[Pref.cacheVideoFit];
  void _initVideoFit() {
    if (_prefFit == .fill && _isVertical) {
      videoFit.value = .contain;
    } else {
      videoFit.value = _prefFit;
    }
  }

  /// 设置后台播放
  void setBackgroundPlay(bool val) {
    videoPlayerServiceHandler?.enableBackgroundPlay = val;
    if (!tempPlayerConf) {
      setting.put(SettingBoxKey.enableBackgroundPlay, val);
    }
  }

  set controls(bool visible) {
    showControls.value = visible;
    _timer?.cancel();
    if (visible) {
      hideTaskControls();
    }
  }

  Timer? longPressTimer;
  void cancelLongPressTimer() {
    longPressTimer?.cancel();
    longPressTimer = null;
  }

  /// 设置长按倍速状态 live模式下禁用
  Future<void> setLongPressStatus(bool val) async {
    if (isLive) {
      return;
    }
    if (controlsLock.value) {
      return;
    }
    if (longPressStatus.value == val) {
      return;
    }
    if (val) {
      if (playerStatus.isPlaying) {
        longPressStatus.value = val;
        HapticFeedback.lightImpact();
        await setPlaybackSpeed(
          enableAutoLongPressSpeed ? playbackSpeed * 2 : longPressSpeed,
        );
      }
    } else {
      // if (kDebugMode) debugPrint('$playbackSpeed');
      longPressStatus.value = val;
      await setPlaybackSpeed(lastPlaybackSpeed);
    }
  }

  bool get isCompleted =>
      videoPlayerController!.state.completed ||
      durationInMilliseconds - positionInMilliseconds <= 50;

  // 双击播放、暂停
  Future<void> onDoubleTapCenter() async {
    if (_pausedForVideoStall) {
      if (_resumeAfterVideoRecovery) {
        await pause();
      } else {
        await play();
      }
      return;
    }

    if (!isLive && isCompleted) {
      await videoPlayerController!.seek(Duration.zero);
      videoPlayerController!.play();
    } else {
      videoPlayerController!.playOrPause();
    }
  }

  final RxBool mountSeekBackwardButton = false.obs;
  final RxBool mountSeekForwardButton = false.obs;

  void onDoubleTapSeekBackward() {
    mountSeekBackwardButton.value = true;
  }

  void onDoubleTapSeekForward() {
    mountSeekForwardButton.value = true;
  }

  void onForward(Duration duration) {
    onForwardBackward(videoPlayerController!.state.position + duration);
  }

  void onBackward(Duration duration) {
    onForwardBackward(videoPlayerController!.state.position - duration);
  }

  void onForwardBackward(Duration duration) {
    seekTo(
      duration.clamp(Duration.zero, videoPlayerController!.state.duration),
      isSeek: false,
    ).whenComplete(play);
  }

  void doubleTapFuc(DoubleTapType type) {
    if (!enableQuickDouble) {
      onDoubleTapCenter();
      return;
    }
    switch (type) {
      case DoubleTapType.left:
        // 双击左边区域 👈
        onDoubleTapSeekBackward();
        break;
      case DoubleTapType.center:
        onDoubleTapCenter();
        break;
      case DoubleTapType.right:
        // 双击右边区域 👈
        onDoubleTapSeekForward();
        break;
    }
  }

  /// 关闭控制栏
  void onLockControl(bool val) {
    feedBack();
    controlsLock.value = val;
    if (!val && showControls.value) {
      showControls.refresh();
    }
    controls = !val;
  }

  void _setFullScreen(bool val) {
    isFullScreen.value = val;
    updateSubtitleStyle();
  }

  double screenRatio = 0.0;
  bool isManualFS = true;
  late final FullScreenMode mode = Pref.fullScreenMode;
  late final horizontalScreen = Pref.horizontalScreen;
  late final removeSafeArea = Pref.removeSafeArea;
  bool get verticalFullscreenBottomBarSafeArea =>
      Pref.verticalFullscreenBottomBarSafeArea;
  double get verticalFullscreenBottomBarSafeHeight =>
      Pref.verticalFullscreenBottomBarSafeHeight;

  Future<void>? changeOrientation({
    required bool isVertical,
    DeviceOrientation? orientation,
  }) {
    if (orientation == null && (mode == .none || mode == .gravity)) {
      return null;
    }
    if (orientation == null &&
        (mode == .vertical ||
            (mode == .auto && isVertical) ||
            (mode == .ratio && (isVertical || screenRatio < kScreenRatio)))) {
      return portraitUpMode();
    } else {
      // https://github.com/flutter/flutter/issues/73651
      // https://github.com/flutter/flutter/issues/183708
      if (Platform.isAndroid) {
        if ((orientation ?? _orientation) == .landscapeRight) {
          return landscapeRightMode();
        } else {
          return landscapeLeftMode();
        }
      } else {
        if (orientation == .landscapeLeft) {
          return landscapeLeftMode();
        } else {
          return landscapeRightMode();
        }
      }
    }
  }

  // 全屏
  bool _fsProcessing = false;
  Future<void> triggerFullScreen({
    bool status = true,
    bool inAppFullScreen = false,
    DeviceOrientation? orientation,
    bool isManualFS = true,
  }) async {
    if (isDesktopPip) return;
    if (isFullScreen.value == status) return;

    if (_fsProcessing) return;
    _fsProcessing = true;
    frameSyncVideoResize.value = true;
    this.isManualFS = isManualFS;
    try {
      if (status) {
        if (PlatformUtils.isMobile) {
          hideSystemBar();
          await changeOrientation(
            isVertical: isVertical,
            orientation: orientation,
          );
        } else {
          await enterDesktopFullScreen(inAppFullScreen: inAppFullScreen);
        }
      } else {
        if (PlatformUtils.isMobile) {
          if (!removeSafeArea) {
            showSystemBar();
          }
          if (orientation == null && mode == .none) {
            return;
          }
          await resetScreenRotation();
        } else {
          await exitDesktopFullScreen();
        }
      }
    } finally {
      _setFullScreen(status);
      try {
        // Keep frame-backed resize confirmation enabled until Flutter has
        // committed the fullscreen layout and one following stabilization
        // frame. Android may report the orientation change before the final
        // viewport/inset geometry reaches the video widget.
        await WidgetsBinding.instance.endOfFrame;
        await WidgetsBinding.instance.endOfFrame;
      } finally {
        frameSyncVideoResize.value = false;
        _fsProcessing = false;
      }
    }
  }

  void addPositionListener(ValueChanged<Duration> listener) {
    if (_playerCount == 0) return;
    _positionListeners.add(listener);
  }

  void removePositionListener(ValueChanged<Duration> listener) =>
      _positionListeners.remove(listener);

  void addStatusLister(ValueChanged<PlayerStatus> listener) {
    if (_playerCount == 0) return;
    _statusListeners.add(listener);
  }

  void removeStatusLister(ValueChanged<PlayerStatus> listener) =>
      _statusListeners.remove(listener);

  // 记录播放记录
  Future<void>? makeHeartBeat(
    int progress, {
    HeartBeatType type = .playing,
    bool isManual = false,
    dynamic aid,
    dynamic bvid,
    dynamic cid,
    dynamic epid,
    dynamic seasonId,
    dynamic pgcType,
    VideoType? videoType,
  }) {
    if (isLive ||
        !enableHeart ||
        progress == 0 ||
        (playerStatus.isPaused && !isManual)) {
      return null;
    }

    Future<void> send() {
      return VideoHttp.heartBeat(
        aid: aid ?? _aid,
        bvid: bvid ?? _bvid,
        cid: cid ?? this.cid,
        progress: progress,
        epid: epid ?? _epid,
        seasonId: seasonId ?? _seasonId,
        subType: pgcType ?? _pgcType,
        videoType: videoType ?? _videoType,
      );
    }

    switch (type) {
      case .playing:
        if (progress - _heartDuration >= 5) {
          _heartDuration = progress;
          return send();
        }
      case .status:
        if (progress - _heartDuration >= 2) {
          _heartDuration = progress;
          return send();
        }
      case .completed:
        if (playerStatus.isCompleted &&
            (durationInMilliseconds - positionInMilliseconds) <= 1000) {
          progress = -1;
        }
        return send();
    }
    return null;
  }

  void setPlayRepeat(PlayRepeat type) {
    playRepeat = type;
    if (!tempPlayerConf) video.put(VideoBoxKey.playRepeat, type.index);
  }

  void putSubtitleSettings() {
    setting.putAllNE({
      SettingBoxKey.subtitleFontScale: subtitleFontScale,
      SettingBoxKey.subtitleFontScaleFS: subtitleFontScaleFS,
      SettingBoxKey.subtitlePaddingH: subtitlePaddingH,
      SettingBoxKey.subtitlePaddingB: subtitlePaddingB,
      SettingBoxKey.subtitleBgOpacity: subtitleBgOpacity,
      SettingBoxKey.subtitleStrokeWidth: subtitleStrokeWidth,
      SettingBoxKey.subtitleFontWeight: subtitleFontWeight,
    });
  }

  bool _isCloseAll = false;
  bool get isCloseAll => _isCloseAll;

  Future<void>? resetScreenRotation() {
    if (horizontalScreen) {
      return fullMode();
    } else {
      return portraitUpMode();
    }
  }

  void onCloseAll() {
    _isCloseAll = true;
    dispose();
    Get.until((route) => route.isFirst);
  }

  void dispose() {
    // 每次减1，最后销毁
    resetScreenRotation();
    cancelLongPressTimer();
    _cancelSubForSeek();
      _resetMediaOpenRetry();
    if (!_isCloseAll && _playerCount > 1) {
      _playerCount -= 1;
      _heartDuration = 0;
      return;
    }

    _playerCount = 0;
    _historySessionStarted = false;
    unawaited(PlaybackHistoryTracker.instance.end());
    _activeVideoPageTag = null;
    _loadedVideoPageTag = null;
    resetCdnForCurrentVideo();
    cancelVideoPlayerSwitch();
    _dataSourceGeneration++;
    _discardInitialPlayGate();
    if (removeSafeArea) {
      showSystemBar();
    }
    danmakuController = null;
    _stopOrientationListener();
    _disableAutoEnterPip();
    setPlayCallBack(null);
    dmState.clear();
    if (showAnySeekPreview) {
      _clearPreview();
    }
    if (Platform.isAndroid) {
      AndroidHelper$ToDart.onUserLeaveHint?.release();
      AndroidHelper$ToDart.onUserLeaveHint = null;
    }
    _timer?.cancel();
    // _position.close();
    // _playerEventSubs?.cancel();
    // _sliderPosition.close();
    // _sliderTempPosition.close();
    // _isSliderMoving.close();
    // _duration.close();
    // _buffered.close();
    // _showControls.close();
    // _controlsLock.close();

    // playerStatus.close();
    // dataStatus.close();

    if (PlatformUtils.isDesktop && isAlwaysOnTop.value) {
      windowManager.setAlwaysOnTop(false);
    }

   unawaited(_removeListeners());
    _positionListeners.clear();
    _statusListeners.clear();
    if (playerStatus.isPlaying) {
      WakelockPlus.disable();
    }
    if (kDebugMode) {
      debugPrint('dispose player');
    }
    _videoPlayerController?.dispose();
    _videoPlayerController = null;
    _videoController = null;
    _playerInitTask = null;
    _endMpvLogSession();
    _instance = null;
    videoPlayerServiceHandler?.clear();
  }

  static void updatePlayCount() {
    if (_instance?._playerCount == 1) {
      _instance?.dispose();
    } else {
      _instance?._playerCount -= 1;
    }
  }

  void setContinuePlayInBackground() {
    continuePlayInBackground.value = !continuePlayInBackground.value;
    if (!tempPlayerConf) {
      setting.put(
        SettingBoxKey.continuePlayInBackground,
        continuePlayInBackground.value,
      );
    }
  }

  void setOnlyPlayAudio() {
    onlyPlayAudio.value = !onlyPlayAudio.value;
    videoPlayerController?.setVideoTrack(
      onlyPlayAudio.value ? VideoTrack.no() : VideoTrack.auto(),
    );
  }

  late final Map<String, ui.Image> previewCache = {};
  final Map<String, Future<ui.Image?>> _previewLoadTasks = {};
  LoadingState<VideoShotData>? videoShot;
  Future<void>? _videoShotTask;
  int _previewGeneration = 0;
  int get previewGeneration => _previewGeneration;
  int? _pendingPreviewSeconds;
  late final RxBool showPreview = false.obs;
  late final showSeekPreviewOnSlider = Pref.showSeekPreviewOnSlider;
  late final showSeekPreviewOnGesture = Pref.showSeekPreviewOnGesture;
  bool get seekTimeInPreview => Pref.seekTimeInPreview;
  bool get showAnySeekPreview =>
      showSeekPreviewOnSlider || showSeekPreviewOnGesture;
  bool get seekPreviewFollowSlider => Pref.seekPreviewFollowSlider;
bool get seekPreviewFollowGesture => Pref.seekPreviewFollowGesture;

late final seekPreviewScale = Pref.seekPreviewScale;
  late final seekPreviewProgressBarGap = Pref.seekPreviewProgressBarGap;
  late final showSeekPreviewInNonFullscreen =
      Pref.showSeekPreviewInNonFullscreen;
  late final previewIndex = RxnInt();
  late final previewGlobalX = RxnDouble();

  void updatePreviewIndex(int seconds, {double? globalX}) {
    previewGlobalX.value = globalX;
    _pendingPreviewSeconds = seconds;
    showPreview.value = true;

    if (videoShot case Success(:final response)) {
      _applyPreviewIndex(response, seconds);
    } else if (videoShot == null || videoShot is Error) {
      _loadVideoShot();
    }
  }

  void _applyPreviewIndex(VideoShotData data, int seconds) {
    if (!isSeeking.value) return;

    previewIndex.value = max(
      0,
      data.index.where((item) => item <= seconds).length - 2,
    );
    showPreview.value = true;
  }

  void _loadVideoShot({bool preloadImages = false}) {
    if (_videoShotTask != null ||
        isLive ||
        isFileSource ||
        _bvid?.isNotEmpty != true ||
        cid == null) {
      return;
    }

    final generation = _previewGeneration;
    final requestBvid = _bvid!;
    final requestCid = cid!;
    videoShot = LoadingState.loading();
    _videoShotTask = _fetchVideoShot(
      generation,
      requestBvid,
      requestCid,
      preloadImages: preloadImages,
    );
  }

  Future<void> _fetchVideoShot(
    int generation,
    String requestBvid,
    int requestCid, {
    required bool preloadImages,
  }) async {
    try {
      final result = await VideoHttp.videoshot(
        bvid: requestBvid,
        cid: requestCid,
      );
      if (generation != _previewGeneration ||
          _bvid != requestBvid ||
          cid != requestCid) {
        return;
      }

      videoShot = result;
      if (result case Success(:final response)) {
        final seconds = _pendingPreviewSeconds;
        if (seconds != null && isSeeking.value) {
          _applyPreviewIndex(response, seconds);
        }
        if (preloadImages) {
          await _preloadVideoShotImages(response, generation);
        }
      }
    } catch (err) {
      if (generation == _previewGeneration &&
          _bvid == requestBvid &&
          cid == requestCid) {
        videoShot = Error(err.toString());
      }
    } finally {
      if (generation == _previewGeneration &&
          _bvid == requestBvid &&
          cid == requestCid) {
        _videoShotTask = null;
      }
    }
  }

  Future<void> _preloadVideoShotImages(
    VideoShotData data,
    int generation,
  ) async {
    const batchSize = 4;
    for (var start = 0; start < data.image.length; start += batchSize) {
      if (generation != _previewGeneration) return;
      final end = min(start + batchSize, data.image.length);
      await Future.wait(
        data.image
            .sublist(start, end)
            .map((url) => loadVideoShotImage(url, generation)),
      );
    }
  }

  Future<ui.Image?> loadVideoShotImage(String url, int generation) {
    if (generation != _previewGeneration) {
      return Future<ui.Image?>.value();
    }

    final cachedImage = previewCache[url];
    if (cachedImage != null) {
      return Future<ui.Image?>.value(cachedImage);
    }

    final activeTask = _previewLoadTasks[url];
    if (activeTask != null) {
      return activeTask;
    }

    late final Future<ui.Image?> task;
    task = _decodeVideoShotImage(url).then((image) {
      if (image == null) return null;
      if (generation != _previewGeneration) {
        image.dispose();
        return null;
      }

      final cachedImage = previewCache[url];
      if (cachedImage != null) {
        image.dispose();
        return cachedImage;
      }

      previewCache[url] = image;
      return image;
    }).whenComplete(() {
      if (identical(_previewLoadTasks[url], task)) {
        _previewLoadTasks.remove(url);
      }
    });
    _previewLoadTasks[url] = task;
    return task;
  }

  Future<ui.Image?> _decodeVideoShotImage(String url) async {
    try {
      final file = await CacheManager.manager.getSingleFile(
        ImageUtils.safeThumbnailUrl(url),
        key: Utils.getFileName(url, fileExt: false),
        headers: Constants.baseHeaders,
      );
      final codec = await ui.instantiateImageCodecFromBuffer(
        await ui.ImmutableBuffer.fromFilePath(file.path),
      );
      try {
        return (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
    } catch (_) {
      return null;
    }
  }

  void _clearPreview() {
    _previewGeneration++;
    _videoShotTask = null;
    _pendingPreviewSeconds = null;
    showPreview.value = false;
    previewIndex.value = null;
    previewGlobalX.value = null;
    videoShot = null;
    for (final i in previewCache.values) {
      i.dispose();
    }
    previewCache.clear();
    _previewLoadTasks.clear();
  }

  Future<void> takeScreenshot() async {
    SmartDialog.showToast('截图中');
    final time = DurationUtils.formatDuration(
      positionInMilliseconds / 1000,
    ).replaceAll(':', '-');
    final image = await videoPlayerController?.screenshot();
    if (image != null) {
      SmartDialog.showToast('点击弹窗保存截图');
      showDialog(
        context: Get.context!,
        builder: (context) => GestureDetector(
          onTap: () async {
            final bytes = await image.toByteData(format: .png);
            if (bytes != null) {
              ImageUtils.saveByteImg(
                bytes: bytes.buffer.asUint8List(),
                fileName: 'screenshot_${cid}_$time',
              );
            }
            Get.back();
          },
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: min(MediaQuery.widthOf(context) / 3, 350),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      width: 5,
                      color: ColorScheme.of(context).surface,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: RawImage(image: image),
                  ),
                ),
              ),
            ),
          ),
        ),
      ).whenComplete(image.dispose);
    } else {
      SmartDialog.showToast('截图失败');
    }
  }

  void onPopInvokedWithResult(bool didPop, Object? result) {
    if (didPop) {
      if (playerStatus.isPlaying) {
        pause();
      }

      setPlayCallBack(null);

      if (Platform.isAndroid && _playerCount <= 1) {
        _disableAutoEnterPip();
        if (!setSystemBrightness) {
          ScreenBrightnessPlatform.instance.resetApplicationScreenBrightness();
        }
      }

      return;
    }

    if (controlsLock.value) {
      onLockControl(false);
      return;
    }
    if (isDesktopPip) {
      exitDesktopPip();
      return;
    }
    if (isFullScreen.value) {
      triggerFullScreen(status: false);
      return;
    }
    Get.back();
  }
}
