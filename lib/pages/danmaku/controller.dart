import 'dart:collection';
import 'dart:io' show File;
import 'package:PiliPlus/models/common/danmaku_merge_mode.dart';
import 'package:PiliPlus/grpc/bilibili/community/service/dm/v1.pb.dart';
import 'package:PiliPlus/grpc/dm.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/models/data_source.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/path_utils.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:path/path.dart' as path;

class PlDanmakuController {
  PlDanmakuController(
  this._cid,
  this._plPlayerController,
  this._isFileSource,
);

final int _cid;
final PlPlayerController _plPlayerController;
final bool _isFileSource;

  late final _isLogin = Accounts.main.isLogin;

  // 完整原始弹幕，用于“不合并”和“高频置顶合并”。
final Map<int, List<DanmakuElem>> _rawDmSegMap = HashMap();

// 按旧逻辑预合并后的弹幕。
final Map<int, List<DanmakuElem>> _segmentMergedDmSegMap = HashMap();
  // 已请求的段落标记
  late final Set<int> _requestedSeg = HashSet();

  static const int segmentLength = 60 * 6 * 1000;

  void dispose() {
  _rawDmSegMap.clear();
  _segmentMergedDmSegMap.clear();
  _requestedSeg.clear();
}
  static int calcSegment(int progress) {
    return progress ~/ segmentLength;
  }

  Future<void> queryDanmaku(int segmentIndex) async {
    if (_isFileSource) {
      return;
    }
    if (_requestedSeg.contains(segmentIndex)) {
      return;
    }
    _requestedSeg.add(segmentIndex);
    final res = await DmGrpc.dmSegMobile(
      cid: _cid,
      segmentIndex: segmentIndex + 1,
    );

    if (res case Success(:final response)) {
      if (response.state == 1) {
        _plPlayerController.dmState.add(_cid);
      }
      handleDanmaku(response.elems);
    } else {
      _requestedSeg.remove(segmentIndex);
    }
  }

  void handleDanmaku(List<DanmakuElem> elems) {
  if (elems.isEmpty) {
    return;
  }

  // 每次 handleDanmaku 对应一个弹幕分段，因此这里仍保持
  // 原有“每个分段内按正文合并”的旧功能语义。
  final mergedByContent = HashMap<String, DanmakuElem>();

  final filters = _plPlayerController.filters;
  final shouldFilter = filters.count != 0;

  for (final element in elems) {
    if (_isLogin) {
      element.isSelf =
          element.midHash == _plPlayerController.midHash;
    }

    if (!element.isSelf &&
        shouldFilter &&
        filters.remove(element)) {
      continue;
    }

    _addToMap(_rawDmSegMap, element);

    // 自己发送的弹幕不参与重复合并。
    if (element.isSelf) {
      _addToMap(_segmentMergedDmSegMap, element);
      continue;
    }

    final merged = mergedByContent[element.content];

    if (merged == null) {
      // 必须复制，不能直接修改原始 element.count，
      // 否则 raw 表也会变成旧式合并数据。
      final first = element.deepCopy()
        ..count = 1;

      mergedByContent[element.content] = first;
      _addToMap(_segmentMergedDmSegMap, first);
    } else {
      merged.count++;
    }
  }
}

void _addToMap(
  Map<int, List<DanmakuElem>> target,
  DanmakuElem element,
) {
  final positionKey = element.progress ~/ 100;
  (target[positionKey] ??= <DanmakuElem>[]).add(element);
}

  List<DanmakuElem>? getCurrentDanmaku(
  int progress,
  DanmakuMergeMode mergeMode,
) {
  if (_isFileSource) {
    initFileDmIfNeeded();
  } else {
    final int segmentIndex = calcSegment(progress);

    if (!_requestedSeg.contains(segmentIndex)) {
      queryDanmaku(segmentIndex);
      return null;
    }
  }

  final sourceMap = mergeMode == DanmakuMergeMode.segment
      ? _segmentMergedDmSegMap
      : _rawDmSegMap;

  return sourceMap[progress ~/ 100];
}

  bool _fileDmLoaded = false;

  void initFileDmIfNeeded() {
    if (_fileDmLoaded) return;
    _fileDmLoaded = true;
    _initFileDm();
  }

  @pragma('vm:notify-debugger-on-exception')
  Future<void> _initFileDm() async {
    try {
      final file = File(
        path.join(
          (_plPlayerController.dataSource as FileSource).dir,
          PathUtils.danmakuName,
        ),
      );
      if (!file.existsSync()) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return;
      final elem = DmSegMobileReply.fromBuffer(bytes).elems;
      handleDanmaku(elem);
    } catch (e, s) {
      Utils.reportError(e, s);
    }
  }
}
