import 'dart:async';

import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/user.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/models/play_status.dart';
import 'package:PiliPlus/services/history_archive_repository.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

class HistoryArchiveRunResult {
  const HistoryArchiveRunResult({
    required this.success,
    required this.message,
    this.syncResult,
    this.attempted = false,
  });

  final bool success;
  final String message;
  final HistoryArchiveSyncResult? syncResult;
  final bool attempted;
}

/// Runs automatic history synchronization only at conservative idle points.
///
/// Automatic work is limited to the foreground root page. This avoids the
/// history/search boxes, account operations, file pickers, downloads and
/// player initialization without requiring those unrelated features to share
/// a global lock.
final class HistoryArchiveService with WidgetsBindingObserver {
  HistoryArchiveService._();

  static final instance = HistoryArchiveService._();

  final repository = HistoryArchiveRepository.instance;
  Timer? _timer;
  bool _started = false;
  bool _foreground = true;
  bool _busy = false;

  bool get isBusy => _busy;

  void start() {
    if (_started) return;
    _started = true;
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycleState == null || lifecycleState == .resumed;
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => scheduleOpportunity(),
    );
    Future<void>.delayed(
      const Duration(seconds: 2),
      scheduleOpportunity,
    );
  }

  void stop() {
    if (!_started) return;
    _started = false;
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == .resumed;
    if (_foreground) scheduleOpportunity();
  }

  void scheduleOpportunity() {
    if (!_started) return;
    unawaited(_maybeArchiveAutomatically());
  }

  void setWindowForeground(bool foreground) {
    _foreground = foreground;
    if (foreground) scheduleOpportunity();
  }

  Future<HistoryArchiveRunResult> archiveNow() async {
    if (_busy) {
      return const HistoryArchiveRunResult(
        success: false,
        message: '已有归档或存档维护操作正在进行',
      );
    }
    if (!_foreground) {
      return const HistoryArchiveRunResult(
        success: false,
        message: 'App 不在前台，暂不能归档',
      );
    }
    if (!_playerIdle) {
      return const HistoryArchiveRunResult(
        success: false,
        message: '正在播放或播放器正忙，请稍后再归档',
      );
    }
    return _archive();
  }

  String exportJson() {
    if (_busy) throw StateError('已有归档或存档维护操作正在进行');
    return repository.exportJson();
  }

  Future<void> importJson(Map<String, dynamic> json) async {
    await _maintenance(() => repository.importJson(json));
  }

  Future<void> clear() async {
    await _maintenance(repository.clear);
  }

  Future<void> _maintenance(Future<void> Function() operation) async {
    if (_busy) throw StateError('已有归档或存档维护操作正在进行');
    _busy = true;
    try {
      await operation();
    } finally {
      _busy = false;
    }
  }

  Future<void> _maybeArchiveAutomatically() async {
    if (_busy ||
        !Pref.autoHistoryArchive ||
        !_isDue ||
        !_canRunAutomatically) {
      return;
    }
    final result = await _archive(automatic: true);
    if (!Pref.silentHistoryArchive && result.attempted) {
      SmartDialog.showToast(result.message);
    }
  }

  bool get _isDue {
    final account = Accounts.history;
    if (!account.isLogin) return false;
    final lastAt = repository.lastArchiveAtForAccount(account.mid);
    if (lastAt == null) return true;
    final interval = Duration(days: Pref.historyArchiveIntervalDays);
    return DateTime.now().millisecondsSinceEpoch - lastAt >=
        interval.inMilliseconds;
  }

  bool get _canRunAutomatically =>
      _foreground &&
      Get.currentRoute == '/' &&
      !SmartDialog.checkExist() &&
      _playerIdle;

  bool get _playerIdle {
    final player = PlPlayerController.instance;
    return player == null ||
        (!player.playerStatus.isPlaying &&
            !player.processing &&
            !player.isBuffering.value);
  }

  Future<HistoryArchiveRunResult> _archive({bool automatic = false}) async {
    final account = Accounts.history;
    if (!account.isLogin) {
      return const HistoryArchiveRunResult(
        success: false,
        message: '当前没有可归档的登录账号',
      );
    }
    final pauseAccountMid = Pref.historyPauseAccountMid;
    if (Pref.historyPause &&
        (pauseAccountMid == null || pauseAccountMid == account.mid)) {
      return const HistoryArchiveRunResult(
        success: false,
        message: '历史记录功能已关闭，本地归档同步已停止',
      );
    }

    _busy = true;
    try {
      final status = await UserHttp.historyStatus(account: account);
      switch (status) {
        case Success(:final response):
          await GStorage.localCache.putAll({
            LocalCacheKey.historyPause: response,
            LocalCacheKey.historyPauseAccountMid: account.mid,
          });
          if (response) {
            return const HistoryArchiveRunResult(
              success: false,
              message: '历史记录功能已关闭，本地归档同步已停止',
              attempted: true,
            );
          }
        case Error(:final errMsg):
          return HistoryArchiveRunResult(
            success: false,
            message: errMsg ?? '无法确认历史记录开关状态，已取消归档',
            attempted: true,
          );
        default:
          return const HistoryArchiveRunResult(
            success: false,
            message: '无法确认历史记录开关状态，已取消归档',
            attempted: true,
          );
      }

      if (!identical(account, Accounts.history)) {
        return const HistoryArchiveRunResult(
          success: false,
          message: '归档期间账号已切换，已取消归档',
          attempted: true,
        );
      }
      if (!_archiveCanContinue(account, automatic: automatic)) {
        return const HistoryArchiveRunResult(
          success: false,
          message: '归档条件已变化，将在下次空闲时重试',
          attempted: true,
        );
      }

      final result = await repository.archiveIncremental(
        account,
        shouldContinue: () =>
            _archiveCanContinue(account, automatic: automatic),
      );
      return HistoryArchiveRunResult(
        success: true,
        message: result.changed == 0
            ? '历史记录归档完成，没有新增记录'
            : '历史记录归档完成，新增或更新 ${result.changed} 条',
        syncResult: result,
        attempted: true,
      );
    } catch (e) {
      return HistoryArchiveRunResult(
        success: false,
        message: '历史记录归档失败：$e',
        attempted: true,
      );
    } finally {
      _busy = false;
    }
  }

  bool _archiveCanContinue(
    Object account, {
    required bool automatic,
  }) =>
      _foreground &&
      _playerIdle &&
      identical(account, Accounts.history) &&
      (!automatic ||
          (Get.currentRoute == '/' && !SmartDialog.checkExist()));
}
