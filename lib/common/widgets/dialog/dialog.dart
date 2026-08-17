import 'package:flutter/material.dart';
import 'package:get/get.dart';

Future<bool> showConfirmDialog({
  required BuildContext context,
  required Widget title,
  Widget? content,
  // @Deprecated('use `bool result = await showConfirmDialog()` instead')
  VoidCallback? onConfirm,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: title,
          content: content,
          actions: [
            TextButton(
              onPressed: Get.back,
              child: Text(
                '不整了，撤！',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Get.back(result: true);
                onConfirm?.call();
              },
              child: const Text('拍板，启动！'),
            ),
          ],
        ),
      ) ??
      false;
}

void showPgcFollowDialog({
  required BuildContext context,
  required String type,
  required int followStatus,
  required ValueChanged<int> onUpdateStatus,
}) {
  Widget statusItem({
    required bool enabled,
    required String text,
    required VoidCallback onTap,
  }) {
    return ListTile(
      dense: true,
      enabled: enabled,
      title: Padding(
        padding: const EdgeInsets.only(left: 10),
        child: Text(
          '标记为 $text，优势在我',
          style: const TextStyle(fontSize: 14),
        ),
      ),
      trailing: !enabled ? const Icon(size: 22, Icons.check) : null,
      onTap: onTap,
    );
  }

  showDialog(
    context: context,
    builder: (context) => SimpleDialog(
      clipBehavior: Clip.hardEdge,
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        ...const [
          (followStatus: 3, title: '看过，鼠鼠我啊'),
          (followStatus: 2, title: '正在炫'),
          (followStatus: 1, title: '塞进赛博愿望单'),
        ].map(
          (item) => statusItem(
            enabled: followStatus != item.followStatus,
            text: item.title,
            onTap: () {
              Get.back();
              onUpdateStatus(item.followStatus);
            },
          ),
        ),
        ListTile(
          dense: true,
          title: Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Text(
              '撤了$type',
              style: const TextStyle(fontSize: 14),
            ),
          ),
          onTap: () {
            Get.back();
            onUpdateStatus(-1);
          },
        ),
      ],
    ),
  );
}
