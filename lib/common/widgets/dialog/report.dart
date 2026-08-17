import 'package:PiliPlus/common/widgets/radio_widget.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/utils/extension/string_ext.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

Future<void> autoWrapReportDialog(
  BuildContext context,
  Map<String, Map<int, String>> options,
  Future<LoadingState> Function(int reasonType, String? reasonDesc, bool banUid)
  onSuccess, {
  bool ban = true,
}) {
  int? reasonType;
  String? reasonDesc;
  bool banUid = false;
  late final key = GlobalKey<FormFieldState<String>>();
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('赛博递状纸'),
      titlePadding: const .only(left: 22, top: 16, right: 22),
      contentPadding: const .symmetric(vertical: 5),
      actionsPadding: const .only(left: 16, right: 16, bottom: 10),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: Builder(
                  builder: (context) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: .only(left: 22, right: 22, bottom: 5),
                        child: Text('请抓一个赛博递状纸的理由：'),
                      ),
                      RadioGroup(
                        onChanged: (value) {
                          reasonType = value;
                          (context as Element).markNeedsBuild();
                        },
                        groupValue: reasonType,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: options.entries.map((entry) {
                            return WrapRadioOptionsGroup<int>(
                              groupTitle: entry.key,
                              options: entry.value,
                            );
                          }).toList(),
                        ),
                      ),
                      if (reasonType == 0)
                        Padding(
                          padding: const .only(left: 22, top: 5, right: 22),
                          child: TextFormField(
                            key: key,
                            autofocus: true,
                            minLines: 2,
                            maxLines: 4,
                            initialValue: reasonDesc,
                            decoration: const InputDecoration(
                              labelText: '为帮助赛博判官人员更快处理，请补充问题类型和出现位置等详细信息',
                              border: OutlineInputBorder(),
                              contentPadding: .all(10),
                              labelStyle: TextStyle(fontSize: 14),
                              floatingLabelStyle: TextStyle(fontSize: 14),
                            ),
                            onChanged: (value) => reasonDesc = value,
                            validator: (value) =>
                                value.isNullOrEmpty ? '理由不能为空，优势在我' : null,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (ban)
            Padding(
              padding: const EdgeInsets.only(left: 14, top: 6),
              child: CheckBoxText(
                text: '拉黑该赛博居民',
                onChanged: (value) => banUid = value,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: Get.back,
          child: Text(
            '不整了，撤！',
            style: TextStyle(color: ColorScheme.of(context).outline),
          ),
        ),
        TextButton(
          onPressed: () async {
            if (reasonType == null ||
                (reasonType == 0 && key.currentState?.validate() != true)) {
              return;
            }
            SmartDialog.showLoading();
            try {
              final res = await onSuccess(reasonType!, reasonDesc, banUid);
              SmartDialog.dismiss();
              if (res.isSuccess) {
                Get.back();
                SmartDialog.showToast('赛博递状纸成了，包的');
              } else {
                res.toast();
              }
            } catch (e, s) {
              SmartDialog.dismiss();
              SmartDialog.showToast('提交寄了：$e');
              Utils.reportError(e, s);
            }
          },
          child: const Text('包的，就这么整'),
        ),
      ],
    ),
  );
}

class CheckBoxText extends StatefulWidget {
  final String text;
  final ValueChanged<bool> onChanged;
  final bool selected;

  const CheckBoxText({
    super.key,
    required this.text,
    required this.onChanged,
    this.selected = false,
  });

  @override
  State<CheckBoxText> createState() => _CheckBoxTextState();
}

class _CheckBoxTextState extends State<CheckBoxText> {
  late bool _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selected;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    return InkWell(
      onTap: () {
        setState(() {
          _selected = !_selected;
          widget.onChanged(_selected);
        });
      },
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              size: 22,
              _selected
                  ? Icons.check_box_outlined
                  : Icons.check_box_outline_blank,
              color: _selected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            Text(
              ' ${widget.text}',
              style: TextStyle(color: _selected ? colorScheme.primary : null),
            ),
          ],
        ),
      ),
    );
  }
}

abstract final class ReportOptions {
  // from https://s1.hdslb.com/bfs/seed/jinkela/comment-h5/static/js/605.chunks.js
  static Map<String, Map<int, String>> get commentReport => const {
    '违反法律法规，功德+1': {9: '违法踩红线', 2: '色情，属实绷不住', 10: '低俗，功德+1', 12: '赌博诈骗，我嘞个豆', 23: '违法信息外链，CPU 都看沉默了'},
    '谣言类不实信息，包的': {19: '涉政谣言，启动！', 22: '虚假不实信息，优势在我', 20: '涉社会事件谣言，优势在我'},
    '侵犯个人权益，这把高端局': {7: '人身攻击，包的', 15: '侵犯赛博隐身'},
    '有害社区环境，已老实': {
      1: '赛博牛皮癣',
      4: '引战，曼波',
      5: '剧透，已老实',
      3: '刷屏，这把高端局',
      8: '电子榨菜不相关',
      18: '踩红线抽奖',
      17: '青少年不良信息，包的',
    },
    '剩下那坨': {0: '剩下那坨'},
  };

  static Map<String, Map<int, String>> get dynamicReport => const {
    '': {
      4: '赛博牛皮癣',
      8: '引战，曼波',
      1: '色情，属实绷不住',
      5: '人身攻击，包的',
      3: '违法信息，我嘞个豆',
      9: '涉政谣言，启动！',
      10: '涉社会事件谣言，优势在我',
      12: '虚假不实信息，优势在我',
      13: '违法信息外链，CPU 都看沉默了',
      0: '剩下那坨',
    },
  };

  static Map<String, Map<int, String>> get danmakuReport => const {
    '': {
      1: '违法违禁，属实绷不住',
      2: '色情低俗，功德+1',
      3: '赌博诈骗，我嘞个豆',
      4: '人身攻击，包的',
      5: '侵犯赛博隐身',
      6: '赛博牛皮癣',
      7: '引战，曼波',
      8: '剧透，已老实',
      9: '恶意刷屏，功德+1',
      10: '电子榨菜无关',
      12: '青少年不良信息，包的',
      13: '违法信息外链，CPU 都看沉默了',
      0: '剩下那坨', // 11
    },
  };

  static Map<String, Map<int, String>> get liveDanmakuReport => const {
    '': {
      1: '违法踩红线',
      2: '低俗色情，属实绷不住',
      3: '赛博牛皮癣',
      4: '辱骂引战，功德+1',
      5: '政治敏感，优势在我',
      6: '青少年不良信息，包的',
      7: '剩下那坨', // avoid show form
    },
  };

  static Map<String, Map<int, String>> get imMsgReport => const {
    '': {
      1: '色情低俗，功德+1',
      2: '政治敏感，优势在我',
      3: '违法有害，CPU 都看沉默了',
      4: '牛皮癣骚扰',
      5: '人身攻击，包的',
      6: '诈骗，CPU 都看沉默了',
      0: '剩下那坨问题',
    },
  };
}
