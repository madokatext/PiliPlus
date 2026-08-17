import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/user.dart';
import 'package:PiliPlus/models_new/coin_log/data.dart';
import 'package:PiliPlus/models_new/coin_log/list.dart';
import 'package:PiliPlus/pages/log_table/controller.dart';

class CoinLogController extends LogController<CoinLogData, CoinLogItem> {
  @override
  List<CoinLogItem>? getDataList(CoinLogData response) {
    return response.list;
  }

  @override
  Future<LoadingState<CoinLogData>> customGetData() => UserHttp.coinLog();

  @override
  List<(int, String)> getFlexAndText(CoinLogItem item) {
    return [(3, item.time), (1, item.delta), (4, item.reason)];
  }

  @override
  final CoinLogItem header = const CoinLogItem(
    time: '时间线',
    delta: '变化，CPU 都看沉默了',
    reason: '原因，我嘞个豆',
  );

  @override
  final String title = '硬币电子脚印';
}
