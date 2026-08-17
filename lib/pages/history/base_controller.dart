import 'package:PiliPlus/http/user.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

class HistoryBaseController extends GetxController {
  RxBool pauseStatus = false.obs;

  RxBool enableMultiSelect = false.obs;
  RxInt checkedCount = 0.obs;

  final account = Accounts.history;

  // 清空观看历史
  void onClearHistory(BuildContext context, VoidCallback onSuccess) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('赛博小喇叭'),
        content: const Text('啊叻？你要一键扬了电子案底电子脚印功能吗？'),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: Text(
              '不整了，撤！',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          TextButton(
            onPressed: () async {
              Get.back();
              SmartDialog.showLoading(msg: '正在敲机房大爹家门');
              final res = await UserHttp.clearHistory(account: account);
              SmartDialog.dismiss();
              if (res.isSuccess) {
                SmartDialog.showToast('一键扬了观看电子案底');
                onSuccess();
              } else {
                res.toast();
              }
            },
            child: const Text('拍板一键扬了'),
          ),
        ],
      ),
    );
  }

  // 暂停观看历史
  void onPauseHistory(BuildContext context) {
    final pauseStatus = !this.pauseStatus.value;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('赛博小喇叭'),
        content: Text(pauseStatus ? '啊叻？你要按住别动电子案底电子脚印功能吗？' : '啊叻？要复活电子案底电子脚印功能吗？，包的'),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: Text(
              '不整了，撤！',
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          TextButton(
            onPressed: () async {
              SmartDialog.showLoading(msg: '正在敲机房大爹家门');
              final res = await UserHttp.pauseHistory(
                pauseStatus,
                account: account,
              );
              SmartDialog.dismiss();
              if (res.isSuccess) {
                SmartDialog.showToast(pauseStatus ? '按住别动观看电子案底，包的' : '复活观看电子案底，我嘞个豆');
                this.pauseStatus.value = pauseStatus;
                await GStorage.localCache.putAll({
                  LocalCacheKey.historyPause: pauseStatus,
                  LocalCacheKey.historyPauseAccountMid: account.mid,
                });
              } else {
                res.toast();
              }
              Get.back();
            },
            child: Text(pauseStatus ? '拍板按住别动' : '拍板复活'),
          ),
        ],
      ),
    );
  }
}
