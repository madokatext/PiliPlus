import 'dart:convert';

import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/user.dart';
import 'package:PiliPlus/models_new/history/data.dart';
import 'package:PiliPlus/models_new/history/list.dart';
import 'package:PiliPlus/utils/accounts/account.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/utils.dart';

class HistoryArchiveSyncResult {
  const HistoryArchiveSyncResult({
    required this.changed,
    required this.fetched,
    required this.pages,
  });

  final int changed;
  final int fetched;
  final int pages;
}

/// Persists the unmodified history item JSON returned by Bilibili.
///
/// The box is deliberately shared by every account. Account-specific cutoffs
/// are metadata only: using one global cutoff would skip older records when a
/// different account is archived for the first time.
final class HistoryArchiveRepository {
  HistoryArchiveRepository._();

  static final instance = HistoryArchiveRepository._();
  static const _schema = 'piliplus_history_archive';
  static const _version = 1;
  static const _cloudPageSize = 20;

  int? get lastArchiveAt {
    final value = GStorage.localCache.get(LocalCacheKey.historyArchiveLastAt);
    return value is num ? value.toInt() : null;
  }

  int? get latestViewAt {
    final value = GStorage.localCache.get(
      LocalCacheKey.historyArchiveLatestViewAt,
    );
    return value is num ? value.toInt() : null;
  }

  int get length => GStorage.historyArchive.length;

  int? lastArchiveAtForAccount(int mid) => _readIntMap(
    LocalCacheKey.historyArchiveAccountLastAts,
  )['$mid'];

  bool contains(HistoryItemModel item) =>
      GStorage.historyArchive.containsKey(recordKeyForItem(item));

  void markCloudItems(Iterable<HistoryItemModel> items) {
    for (final item in items) {
      item
        ..localOnly = false
        ..hasLocalCopy = contains(item);
    }
  }

  String recordKeyForItem(HistoryItemModel item) =>
      recordKeyForJson(item.toJson());

  String recordKeyForJson(Map<String, dynamic> data) {
    final history = data['history'];
    final historyMap = history is Map ? history : const <String, dynamic>{};
    final business = historyMap['business']?.toString() ?? 'unknown';
    final identity = data['kid'] ??
        historyMap['epid'] ??
        historyMap['oid'] ??
        historyMap['bvid'] ??
        historyMap['cid'];
    if (identity != null) {
      return '$business:$identity';
    }
    return '$business:${data['view_at']}:${data['title'] ?? ''}';
  }

  Future<HistoryArchiveSyncResult> archiveIncremental(
    Account account, {
    bool Function()? shouldContinue,
  }) async {
    if (!account.isLogin) {
      throw StateError('眼下这坨没有可赛博入土的上号赛博户口');
    }

    final cutoffs = _accountCutoffs;
    final cutoff = cutoffs['${account.mid}'] ?? 0;
    final pending = <Map<String, dynamic>>[];
    final seenCursors = <String>{};
    int? max;
    int? viewAt;
    int? newestRemoteViewAt;
    var pages = 0;

    while (true) {
      if (shouldContinue?.call() == false) {
        throw StateError('赛博入土条件已变化，将在下次空闲时再赌一把');
      }
      final response = await UserHttp.historyList(
        type: 'all',
        max: max,
        viewAt: viewAt,
        account: account,
        pageSize: _cloudPageSize,
      );
      final HistoryData pageData;
      switch (response) {
        case Success(:final response):
          pageData = response;
        case Error(:final errMsg):
          throw StateError(errMsg ?? '获取云端电子案底电子脚印寄了，不是哥们');
        default:
          throw StateError('获取云端电子案底电子脚印寄了，不是哥们');
      }
      final pageItems = pageData.list ?? const <HistoryItemModel>[];

      pages++;
      if (pageItems.isEmpty) break;

      var reachedCutoff = false;
      for (final item in pageItems) {
        final itemViewAt = item.viewAt ?? 0;
        if (newestRemoteViewAt == null || itemViewAt > newestRemoteViewAt) {
          newestRemoteViewAt = itemViewAt;
        }
        if (cutoff > 0 && itemViewAt <= cutoff) {
          reachedCutoff = true;
        } else {
          pending.add(item.toJson());
        }
      }

      if (reachedCutoff || pageItems.length < _cloudPageSize) break;

      final last = pageItems.last;
      final nextMax = (pageData.cursorMax ?? 0) > 0
          ? pageData.cursorMax
          : last.history.oid;
      final nextViewAt = (pageData.cursorViewAt ?? 0) > 0
          ? pageData.cursorViewAt
          : last.viewAt;
      if (nextMax == null || nextViewAt == null) {
        throw StateError('云端电子案底电子脚印分页游标无效，已老实');
      }
      final cursor = '$nextMax:$nextViewAt';
      if (!seenCursors.add(cursor)) {
        throw StateError('云端电子案底电子脚印分页游标未推进，曼波');
      }
      max = nextMax;
      viewAt = nextViewAt;
    }

    if (shouldContinue?.call() == false) {
      throw StateError('赛博入土条件已变化，将在下次空闲时再赌一把');
    }
    final changed = await _upsertRawItems(
      pending,
      sourceMid: account.mid,
    );
    if (newestRemoteViewAt != null && newestRemoteViewAt > cutoff) {
      cutoffs['${account.mid}'] = newestRemoteViewAt;
      await GStorage.localCache.put(
        LocalCacheKey.historyArchiveAccountCutoffs,
        cutoffs,
      );
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await GStorage.localCache.put(
      LocalCacheKey.historyArchiveLastAt,
      now,
    );
    final accountLastAts = _readIntMap(
      LocalCacheKey.historyArchiveAccountLastAts,
    );
    accountLastAts['${account.mid}'] = now;
    await GStorage.localCache.put(
      LocalCacheKey.historyArchiveAccountLastAts,
      accountLastAts,
    );
    return HistoryArchiveSyncResult(
      changed: changed,
      fetched: pending.length,
      pages: pages,
    );
  }

  List<HistoryItemModel> localItems({
    String? type,
    String? keyword,
    Set<String> excludeKeys = const {},
  }) {
    final normalizedKeyword = keyword?.trim().toLowerCase();
    final result = <HistoryItemModel>[];
    for (final entry in GStorage.historyArchive.toMap().entries) {
      final key = entry.key.toString();
      if (excludeKeys.contains(key)) continue;
      final wrapper = entry.value;
      if (wrapper is! Map || wrapper['data'] is! Map) continue;
      final data = Map<String, dynamic>.from(wrapper['data'] as Map);
      if (!_matchesType(data, type)) continue;
      if (normalizedKeyword?.isNotEmpty == true &&
          !jsonEncode(data).toLowerCase().contains(normalizedKeyword!)) {
        continue;
      }
      try {
        result.add(
          HistoryItemModel.fromJson(data)
            ..localOnly = true
            ..hasLocalCopy = true,
        );
      } catch (_) {
        // A damaged imported entry must not make the whole history page fail.
      }
    }
    result.sort((a, b) => (b.viewAt ?? 0).compareTo(a.viewAt ?? 0));
    return result;
  }

  Future<void> deleteItems(Iterable<HistoryItemModel> items) async {
    final keys = items.map(recordKeyForItem).toSet();
    if (keys.isEmpty) return;
    await GStorage.historyArchive.deleteAll(keys);
    await _refreshLatestViewAt();
  }

  String exportJson() => Utils.jsonEncoder.convert({
    'schema': _schema,
    'version': _version,
    'exported_at': DateTime.now().millisecondsSinceEpoch,
    'last_archive_at': lastArchiveAt,
    'latest_view_at': latestViewAt,
    'account_cutoffs': _accountCutoffs,
    'account_last_archive_at': _readIntMap(
      LocalCacheKey.historyArchiveAccountLastAts,
    ),
    'records': GStorage.historyArchive.toMap().entries
        .map(
          (entry) => {
            'key': entry.key.toString(),
            ...Map<String, dynamic>.from(entry.value as Map),
          },
        )
        .toList(),
  });

  Future<void> importJson(Map<String, dynamic> json) async {
    final schema = json['schema'];
    if (schema != null && schema != _schema) {
      throw const FormatException('不是 PiliPlus 电子案底电子脚印赛博存档，不是哥们');
    }
    final version = json['version'];
    if (version is num && version.toInt() > _version) {
      throw FormatException('不支持的赛博存档版本：$version');
    }
    final records = json['records'];
    if (records is! List) {
      throw const FormatException('赛博存档缺少 records 列表');
    }

    for (final value in records) {
      if (value is! Map) {
        throw const FormatException('赛博存档包含无效电子脚印');
      }
      final wrapper = Map<String, dynamic>.from(value);
      final raw = wrapper['data'];
      if (raw is! Map || raw['history'] is! Map) {
        throw const FormatException('赛博存档电子脚印缺少完整电子案底信息');
      }
      try {
        final item = HistoryItemModel.fromJson(
          Map<String, dynamic>.from(raw),
        );
        if (item.title == null ||
            item.history.oid == null ||
            item.history.business == null ||
            item.viewAt == null ||
            item.videos == null ||
            item.kid == null) {
          throw const FormatException('缺少卡片必需字段，鼠鼠我啊');
        }
      } catch (e) {
        throw FormatException('赛博存档包含无效电子脚印：$e');
      }
    }

    await _upsertImportedRecords(records);

    final importedCutoffs = json['account_cutoffs'];
    if (importedCutoffs is Map) {
      final cutoffs = _accountCutoffs;
      for (final entry in importedCutoffs.entries) {
        final value = entry.value;
        if (value is num) {
          final key = entry.key.toString();
          final intValue = value.toInt();
          if (intValue > (cutoffs[key] ?? 0)) cutoffs[key] = intValue;
        }
      }
      await GStorage.localCache.put(
        LocalCacheKey.historyArchiveAccountCutoffs,
        cutoffs,
      );
    }

    final importedLastAt = json['last_archive_at'];
    if (importedLastAt is num &&
        importedLastAt.toInt() > (lastArchiveAt ?? 0)) {
      await GStorage.localCache.put(
        LocalCacheKey.historyArchiveLastAt,
        importedLastAt.toInt(),
      );
    }
    await _mergeImportedIntMap(
      json['account_last_archive_at'],
      LocalCacheKey.historyArchiveAccountLastAts,
    );
    await _refreshLatestViewAt();
  }

  Future<void> clear() async {
    await Future.wait([
      GStorage.historyArchive.clear(),
      GStorage.localCache.delete(LocalCacheKey.historyArchiveLatestViewAt),
      GStorage.localCache.delete(LocalCacheKey.historyArchiveAccountCutoffs),
    ]);
  }

  Map<String, int> get _accountCutoffs {
    return _readIntMap(LocalCacheKey.historyArchiveAccountCutoffs);
  }

  Map<String, int> _readIntMap(String storageKey) {
    final value = GStorage.localCache.get(storageKey);
    if (value is! Map) return <String, int>{};
    return {
      for (final entry in value.entries)
        if (entry.value is num)
          entry.key.toString(): (entry.value as num).toInt(),
    };
  }

  Future<void> _mergeImportedIntMap(dynamic value, String storageKey) async {
    if (value is! Map) return;
    final current = _readIntMap(storageKey);
    for (final entry in value.entries) {
      if (entry.value is num) {
        final key = entry.key.toString();
        final imported = (entry.value as num).toInt();
        if (imported > (current[key] ?? 0)) current[key] = imported;
      }
    }
    await GStorage.localCache.put(storageKey, current);
  }

  Future<int> _upsertRawItems(
    Iterable<Map<String, dynamic>> items, {
    required int sourceMid,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final writes = <String, dynamic>{};
    var changed = 0;
    for (final data in items) {
      final key = recordKeyForJson(data);
      final existing = writes[key] ?? GStorage.historyArchive.get(key);
      final merged = _mergeRecord(
        existing,
        data,
        sourceMids: {sourceMid},
        archivedAt: now,
      );
      if (existing == null ||
          _viewAt(data) > _viewAt(_readData(existing))) {
        changed++;
      }
      writes[key] = merged;
    }
    if (writes.isNotEmpty) {
      await GStorage.historyArchive.putAll(writes);
      final incomingLatest = items
          .map(_viewAt)
          .fold<int>(0, (previous, value) => value > previous ? value : previous);
      if (incomingLatest > (latestViewAt ?? 0)) {
        await GStorage.localCache.put(
          LocalCacheKey.historyArchiveLatestViewAt,
          incomingLatest,
        );
      }
    }
    return changed;
  }

  Future<void> _upsertImportedRecords(List records) async {
    final writes = <String, dynamic>{};
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final value in records) {
      final wrapper = Map<String, dynamic>.from(value as Map);
      final data = Map<String, dynamic>.from(wrapper['data'] as Map);
      final key = recordKeyForJson(data);
      final existing = writes[key] ?? GStorage.historyArchive.get(key);
      writes[key] = _mergeRecord(
        existing,
        data,
        sourceMids: _readSourceMids(wrapper['source_accounts']).toSet(),
        archivedAt: wrapper['archived_at'] is num
            ? (wrapper['archived_at'] as num).toInt()
            : now,
      );
    }
    if (writes.isNotEmpty) await GStorage.historyArchive.putAll(writes);
  }

  Map<String, dynamic> _mergeRecord(
    dynamic existing,
    Map<String, dynamic> incoming, {
    required Set<int> sourceMids,
    required int archivedAt,
  }) {
    final existingData = _readData(existing);
    final existingSources = existing is Map
        ? _readSourceMids(existing['source_accounts']).toSet()
        : <int>{};
    final existingArchivedAt = existing is Map && existing['archived_at'] is num
        ? (existing['archived_at'] as num).toInt()
        : 0;
    return {
      'data': existingData == null || _viewAt(incoming) >= _viewAt(existingData)
          ? incoming
          : existingData,
      'source_accounts': (existingSources..addAll(sourceMids)).toList()..sort(),
      'archived_at': archivedAt > existingArchivedAt
          ? archivedAt
          : existingArchivedAt,
    };
  }

  Map<String, dynamic>? _readData(dynamic wrapper) {
    if (wrapper is Map && wrapper['data'] is Map) {
      return Map<String, dynamic>.from(wrapper['data'] as Map);
    }
    return null;
  }

  List<int> _readSourceMids(dynamic value) => value is Iterable
      ? value
            .map((e) => e is num ? e.toInt() : int.tryParse('$e'))
            .whereType<int>()
            .toList()
      : const [];

  int _viewAt(Map<String, dynamic>? data) {
    final value = data?['view_at'];
    return value is num ? value.toInt() : 0;
  }

  bool _matchesType(Map<String, dynamic> data, String? type) {
    if (type == null || type == 'all') return true;
    final history = data['history'];
    if (history is! Map) return false;
    final business = history['business']?.toString() ?? '';
    return switch (type) {
      'archive' => business != 'live' && !business.contains('article'),
      'live' => business == 'live',
      'article' => business.contains('article'),
      _ => business == type,
    };
  }

  Future<void> _refreshLatestViewAt() async {
    var latest = 0;
    for (final value in GStorage.historyArchive.values) {
      final current = _viewAt(_readData(value));
      if (current > latest) latest = current;
    }
    if (latest == 0) {
      await GStorage.localCache.delete(
        LocalCacheKey.historyArchiveLatestViewAt,
      );
    } else {
      await GStorage.localCache.put(
        LocalCacheKey.historyArchiveLatestViewAt,
        latest,
      );
    }
  }
}
