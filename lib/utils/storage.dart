import 'dart:convert';
import 'dart:typed_data';

import 'package:PiliPlus/models/model_owner.dart';
import 'package:PiliPlus/models/user/danmaku_rule_adapter.dart';
import 'package:PiliPlus/models/user/info.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/accounts/account_adapter.dart';
import 'package:PiliPlus/utils/accounts/account_type_adapter.dart';
import 'package:PiliPlus/utils/accounts/cookie_jar_adapter.dart';
import 'package:PiliPlus/utils/default_settings.dart';
import 'package:PiliPlus/utils/path_utils.dart';
import 'package:PiliPlus/utils/recommend_history.dart';
import 'package:PiliPlus/utils/set_int_adapter.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as path;

abstract final class GStorage {
  static late final Box<UserInfoData> userInfo;
  static late final Box<dynamic> historyWord;
  static late final Box<dynamic> historyArchive;
  static late final Box<dynamic> localCache;
  static late final Box<dynamic> setting;
  static late final Box<dynamic> video;
  static late final Box<int> watchProgress;
  static late final Box<dynamic> interactiveVideoProgress;
  static late final Box<dynamic> recommendExposureHistory;
  static late final Box<dynamic> recommendWatchHistory;
  static late final Box<Uint8List>? reply;

  static Future<void> init() async {
    Hive.init(path.join(appSupportDirPath, 'hive'));
    regAdapter();

    await Future.wait([
      // 登录用户信息
      Hive.openBox<UserInfoData>(
        'userInfo',
        compactionStrategy: (int entries, int deletedEntries) {
          return deletedEntries > 2;
        },
      ).then((res) => userInfo = res),
      // 本地缓存
      Hive.openBox(
        'localCache',
        compactionStrategy: (int entries, int deletedEntries) {
          return deletedEntries > 4;
        },
      ).then((res) => localCache = res),
      // 设置
      Hive.openBox('setting').then((res) => setting = res),
      // 搜索历史
      Hive.openBox(
        'historyWord',
        compactionStrategy: (int entries, int deletedEntries) {
          return deletedEntries > 10;
        },
      ).then((res) => historyWord = res),
      // 官方观看历史的本地总归档库（所有账号共享）
      Hive.openBox(
        'historyArchive',
        compactionStrategy: (entries, deletedEntries) =>
            deletedEntries > 100 && deletedEntries > entries,
      ).then((res) => historyArchive = res),
      // 视频设置
      Hive.openBox('video').then((res) => video = res),
      Accounts.init(),
      Hive.openBox<int>(
        'watchProgress',
        keyComparator: _intStrDescKeyComparator,
        compactionStrategy: (entries, deletedEntries) {
          return deletedEntries > 4;
        },
      ).then((res) => watchProgress = res),
      Hive.openBox(
        'interactiveVideoProgress',
        compactionStrategy: (entries, deletedEntries) {
          return deletedEntries > 20 && deletedEntries > entries;
        },
      ).then((res) => interactiveVideoProgress = res),
      Hive.openBox(
        'recommendExposureHistory',
        compactionStrategy: (entries, deletedEntries) =>
            deletedEntries > 1000 && deletedEntries > entries,
      ).then((res) => recommendExposureHistory = res),
      Hive.openBox(
        'recommendWatchHistory',
        compactionStrategy: (entries, deletedEntries) =>
            deletedEntries > 1000 && deletedEntries > entries,
      ).then((res) => recommendWatchHistory = res),
    ]);

    await _migrateLegacySettings();

    await Future.wait([
      _putMissingDefaults(setting, defaultSettingValues),
      _putMissingDefaults(video, defaultVideoValues),
    ]);

    RecommendHistoryRepository.initialize(
      exposureBox: recommendExposureHistory,
      watchBox: recommendWatchHistory,
    );
    await RecommendHistoryRepository.instance.maybeCleanup();

    if (Pref.saveReply) {
      reply = await Hive.openBox<Uint8List>(
        'reply',
        keyComparator: _intStrDescKeyComparator,
        compactionStrategy: (entries, deletedEntries) {
          return deletedEntries > 10;
        },
      );
    } else {
      reply = null;
    }
  }

  static Future<void> _putMissingDefaults(
    Box<dynamic> box,
    Map<String, Object> defaults,
  ) async {
    final missingDefaults = <String, Object>{
      for (final entry in defaults.entries)
        if (!box.containsKey(entry.key)) entry.key: entry.value,
    };
    if (missingDefaults.isNotEmpty) {
      await box.putAll(missingDefaults);
    }
  }

  static Future<void> _migrateLegacySettings() async {
    if (setting.containsKey('showSteinProgressDebug')) {
      await setting.delete('showSteinProgressDebug');
    }
    if (!setting.containsKey(SettingBoxKey.danmakuMergeMode) &&
        setting.containsKey(SettingBoxKey.mergeDanmaku)) {
      await setting.put(
        SettingBoxKey.danmakuMergeMode,
        setting.get(SettingBoxKey.mergeDanmaku) == true ? 1 : 0,
      );
    }
  }

  static String exportAllSettings() {
    return Utils.jsonEncoder.convert({
      setting.name: setting.toMap(),
      video.name: video.toMap(),
    });
  }

  static Future<void> importAllSettings(String data) =>
      importAllJsonSettings(jsonDecode(data));

  static Future<void> importAllJsonSettings(
    Map<String, dynamic> map,
  ) async {
    final settingData = _readSettingsMap(map, setting.name);
    final videoData = _readSettingsMap(map, video.name);
    final settingBackup = setting.toMap();
    final videoBackup = video.toMap();

    try {
      await Future.wait([setting.clear(), video.clear()]);
      await Future.wait([
        setting.putAll(settingData),
        video.putAll(videoData),
      ]);
    } catch (_) {
      await Future.wait([setting.clear(), video.clear()]);
      await Future.wait([
        setting.putAll(settingBackup),
        video.putAll(videoBackup),
      ]);
      rethrow;
    }
  }

  static Map<dynamic, dynamic> _readSettingsMap(
    Map<String, dynamic> map,
    String boxName,
  ) {
    final data = map[boxName];
    if (data is! Map) {
      throw FormatException('缺少或无效的 $boxName 赛博调参');
    }
    if (data.keys.any((key) => key is! String)) {
      throw FormatException('$boxName 赛博调参包含无效键名');
    }
    return Map<dynamic, dynamic>.from(data);
  }

  static void regAdapter() {
    Hive
      ..registerAdapter(OwnerAdapter())
      ..registerAdapter(UserInfoDataAdapter())
      ..registerAdapter(LevelInfoAdapter())
      ..registerAdapter(BiliCookieJarAdapter())
      ..registerAdapter(LoginAccountAdapter())
      ..registerAdapter(AccountTypeAdapter())
      ..registerAdapter(SetIntAdapter())
      ..registerAdapter(RuleFilterAdapter());
  }

  static Future<List<void>> compact() {
    return Future.wait([
      userInfo.compact(),
      historyWord.compact(),
      historyArchive.compact(),
      localCache.compact(),
      setting.compact(),
      video.compact(),
      Accounts.account.compact(),
      watchProgress.compact(),
      interactiveVideoProgress.compact(),
      recommendExposureHistory.compact(),
      recommendWatchHistory.compact(),
      ?reply?.compact(),
    ]);
  }

  static Future<List<void>> close() {
    return Future.wait([
      userInfo.close(),
      historyWord.close(),
      historyArchive.close(),
      localCache.close(),
      setting.close(),
      video.close(),
      Accounts.account.close(),
      watchProgress.close(),
      interactiveVideoProgress.close(),
      recommendExposureHistory.close(),
      recommendWatchHistory.close(),
      ?reply?.close(),
    ]);
  }

  static Future<List<void>> clear() {
    return Future.wait([
      userInfo.clear(),
      historyWord.clear(),
      historyArchive.clear(),
      localCache.clear(),
      setting.clear(),
      video.clear(),
      Accounts.clear(),
      watchProgress.clear(),
      interactiveVideoProgress.clear(),
      recommendExposureHistory.clear(),
      recommendWatchHistory.clear(),
      ?reply?.clear(),
    ]);
  }

  static int _intStrDescKeyComparator(dynamic k1, dynamic k2) {
    if (k1 is int) {
      if (k2 is int) {
        return k2.compareTo(k1);
      } else {
        return -1;
      }
    } else if (k2 is String) {
      final lenCompare = k2.length.compareTo((k1 as String).length);
      if (lenCompare == 0) {
        return k2.compareTo(k1);
      } else {
        return lenCompare;
      }
    } else {
      return 1;
    }
  }
}
