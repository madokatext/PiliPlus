import 'dart:io' show Platform;

import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/models/play_status.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:audio_session/audio_session.dart';

class AudioSessionHandler {
  late AudioSession session;
  bool _playInterrupted = false;
  bool _hasBluetoothOutput = false;
  bool _backgroundBluetoothStateSaved = false;
  bool _hadBluetoothOutputBeforeBackground = false;
  int _backgroundBluetoothCheckGeneration = 0;
  Future<bool>? _backgroundBluetoothCheck;

  bool get bluetoothDisconnectProtectionEnabled =>
      Platform.isAndroid && Pref.audioTrackIsPrimaryOutput;

  static bool _isBluetoothOutput(AudioDevice device) {
    return device.isOutput &&
        const {
          AudioDeviceType.bluetoothA2dp,
          AudioDeviceType.bluetoothSco,
          AudioDeviceType.bluetoothLe,
        }.contains(device.type);
  }

  void _exitToHomeOnBluetoothDisconnect() {
    if (!bluetoothDisconnectProtectionEnabled) return;
    _playInterrupted = false;
    PlPlayerController.exitToHomeIfExists();
  }

  void _clearBackgroundBluetoothState() {
    _backgroundBluetoothStateSaved = false;
    _hadBluetoothOutputBeforeBackground = false;
    _backgroundBluetoothCheckGeneration++;
    _backgroundBluetoothCheck = null;
  }

  /// 保存进入后台前的输出状态，避免依赖后台可能丢失的设备变更事件。
  void saveBluetoothStateBeforeBackground() {
    if (!bluetoothDisconnectProtectionEnabled) {
      _clearBackgroundBluetoothState();
      return;
    }
    if (_backgroundBluetoothStateSaved) return;
    _backgroundBluetoothStateSaved = true;
    _hadBluetoothOutputBeforeBackground = _hasBluetoothOutput;
    _backgroundBluetoothCheckGeneration++;
    _backgroundBluetoothCheck = null;
  }

  Future<bool> checkBluetoothStateAfterBackground() {
    if (!bluetoothDisconnectProtectionEnabled) {
      _clearBackgroundBluetoothState();
      return Future<bool>.value(true);
    }
    final activeCheck = _backgroundBluetoothCheck;
    if (activeCheck != null) return activeCheck;
    if (!_backgroundBluetoothStateSaved) return Future<bool>.value(true);

    _backgroundBluetoothStateSaved = false;
    final hadBluetoothOutput = _hadBluetoothOutputBeforeBackground;
    final generation = _backgroundBluetoothCheckGeneration;
    final check = _checkBluetoothStateAfterBackground(
      hadBluetoothOutput,
      generation,
    );
    _backgroundBluetoothCheck = check;
    return check.whenComplete(() {
      if (identical(_backgroundBluetoothCheck, check)) {
        _backgroundBluetoothCheck = null;
      }
    });
  }

  Future<bool> _checkBluetoothStateAfterBackground(
    bool hadBluetoothOutput,
    int generation,
  ) async {
    bool hasBluetoothOutput;
    try {
      hasBluetoothOutput =
          (await session.getDevices()).any(_isBluetoothOutput);
    } catch (_) {
      if (generation != _backgroundBluetoothCheckGeneration) return false;
      if (!bluetoothDisconnectProtectionEnabled) return true;
      if (hadBluetoothOutput) {
        // 无法确认蓝牙仍连接时禁止续播，避免恢复瞬间从扬声器泄漏声音。
        _exitToHomeOnBluetoothDisconnect();
        return false;
      }
      return true;
    }

    if (generation != _backgroundBluetoothCheckGeneration) return false;
    if (!bluetoothDisconnectProtectionEnabled) return true;
    _hasBluetoothOutput = hasBluetoothOutput;
    if (hadBluetoothOutput && !hasBluetoothOutput) {
      _exitToHomeOnBluetoothDisconnect();
      return false;
    }
    return true;
  }

  Future<bool> setActive(bool active) {
    return session.setActive(active);
  }

  AudioSessionHandler() {
    initSession();
  }

  Future<void> initSession() async {
    session = await AudioSession.instance;
    session.configure(const AudioSessionConfiguration.music());

    try {
      _hasBluetoothOutput =
          (await session.getDevices()).any(_isBluetoothOutput);
    } catch (_) {
      // 设备枚举失败不应阻止音频焦点与中断监听初始化。
    }

    session.devicesChangedEventStream.listen((event) async {
      final removedBluetooth = event.devicesRemoved.any(_isBluetoothOutput);
      final hadBluetoothOutput = _hasBluetoothOutput;

      if (removedBluetooth) {
        _exitToHomeOnBluetoothDisconnect();
      }

      try {
        _hasBluetoothOutput =
            (await session.getDevices()).any(_isBluetoothOutput);
      } catch (_) {
        // 保留上一次设备状态，仍可依据 devicesRemoved 判断断开。
      }

      if (!removedBluetooth && hadBluetoothOutput && !_hasBluetoothOutput) {
        _exitToHomeOnBluetoothDisconnect();
      }
    });

    session.interruptionEventStream.listen((event) {
      final playerStatus = PlPlayerController.getPlayerStatusIfExists();
      // final player = PlPlayerController.getInstance();
      if (event.begin) {
        if (playerStatus != PlayerStatus.playing) return;
        // if (!player.playerStatus.playing) return;
        switch (event.type) {
          case AudioInterruptionType.duck:
            PlPlayerController.setVolumeIfExists(
              (PlPlayerController.getVolumeIfExists() ?? 0) * 0.5,
              showIndicator: false,
            );
            // player.setVolume(player.volume.value * 0.5);
            break;
          case AudioInterruptionType.pause:
            PlPlayerController.pauseIfExists(isInterrupt: true);
            // player.pause(isInterrupt: true);
            _playInterrupted = true;
            break;
          case AudioInterruptionType.unknown:
            PlPlayerController.pauseIfExists(isInterrupt: true);
            // player.pause(isInterrupt: true);
            _playInterrupted = true;
            break;
        }
      } else {
        switch (event.type) {
          case AudioInterruptionType.duck:
            PlPlayerController.setVolumeIfExists(
              (PlPlayerController.getVolumeIfExists() ?? 0) * 2,
              showIndicator: false,
            );
            // player.setVolume(player.volume.value * 2);
            break;
          case AudioInterruptionType.pause:
            if (_playInterrupted) PlPlayerController.playIfExists();
            //player.play();
            break;
          case AudioInterruptionType.unknown:
            break;
        }
        _playInterrupted = false;
      }
    });

    // 蓝牙断开退出首页；有线耳机拔出仍只暂停。
    session.becomingNoisyEventStream.listen((_) {
      if (bluetoothDisconnectProtectionEnabled && _hasBluetoothOutput) {
        _exitToHomeOnBluetoothDisconnect();
      } else {
        PlPlayerController.pauseIfExists();
      }
      // final player = PlPlayerController.getInstance();
      // if (player.playerStatus.playing) {
      //   player.pause();
      // }
    });
  }
}
