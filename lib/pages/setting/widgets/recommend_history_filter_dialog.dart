import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/models/common/recommend_history_filter_settings.dart';
import 'package:flutter/material.dart';

class RecommendHistoryFilterDialog extends StatefulWidget {
  final RecommendHistoryFilterSettings initialValue;

  const RecommendHistoryFilterDialog({super.key, required this.initialValue});

  @override
  State<RecommendHistoryFilterDialog> createState() =>
      _RecommendHistoryFilterDialogState();
}

class _RecommendHistoryFilterDialogState
    extends State<RecommendHistoryFilterDialog> {
  late bool _enabled;
  late int _days;
  late int _hours;
  late int _minutes;
  late int _exposureThreshold;
  late int _watchThreshold;
  late int _watchMinutes;
  late int _watchSeconds;

  @override
  void initState() {
    super.initState();
    final value = widget.initialValue;
    _enabled = value.enabled;
    _days = value.lookbackMinutes ~/ (24 * 60);
    final remaining = value.lookbackMinutes % (24 * 60);
    _hours = remaining ~/ 60;
    _minutes = remaining % 60;
    _exposureThreshold = value.exposureThreshold;
    _watchThreshold = value.watchThreshold;
    _watchMinutes = value.minWatchSeconds ~/ 60;
    _watchSeconds = value.minWatchSeconds % 60;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      constraints: Style.dialogFixedConstraints,
      title: const Text('近期推荐历史过滤'),
      content: SizedBox(
        width: 430,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('过滤近期已推荐或看过的视频'),
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
              ),
              const Divider(),
              const Text('过去时间'),
              const SizedBox(height: 8),
              Row(
                children: [
                  _numberSelect(
                    value: _days,
                    values: List.generate(31, (index) => index),
                    suffix: '天',
                    onChanged: (value) {
                      setState(() {
                        _days = value;
                        if (_days == 30) {
                          _hours = 0;
                          _minutes = 0;
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  _numberSelect(
                    value: _days == 30 ? 0 : _hours,
                    values: _days == 30
                        ? const [0]
                        : List.generate(24, (index) => index),
                    suffix: '小时',
                    onChanged: _days == 30
                        ? null
                        : (value) => setState(() => _hours = value),
                  ),
                  const SizedBox(width: 8),
                  _numberSelect(
                    value: _days == 30 ? 0 : _minutes,
                    values: _days == 30
                        ? const [0]
                        : List.generate(60, (index) => index),
                    suffix: '分',
                    onChanged: _days == 30
                        ? null
                        : (value) => setState(() => _minutes = value),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _thresholdRow(
                label: '推荐次数',
                value: _exposureThreshold,
                onChanged: (value) =>
                    setState(() => _exposureThreshold = value),
              ),
              const SizedBox(height: 12),
              _thresholdRow(
                label: '观看次数',
                value: _watchThreshold,
                onChanged: (value) => setState(() => _watchThreshold = value),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(child: Text('每次至少观看')),
                  SizedBox(
                    width: 92,
                    child: _plainSelect(
                      value: _watchMinutes,
                      values: List.generate(6, (index) => index),
                      suffix: '分',
                      onChanged: (value) {
                        setState(() {
                          _watchMinutes = value;
                          if (_watchMinutes == 5) {
                            _watchSeconds = 0;
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 92,
                    child: _plainSelect(
                      value: _watchMinutes == 5 ? 0 : _watchSeconds,
                      values: _watchMinutes == 5
                          ? const [0]
                          : List.generate(60, (index) => index),
                      suffix: '秒',
                      onChanged: _watchMinutes == 5
                          ? null
                          : (value) => setState(() => _watchSeconds = value),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _save, child: const Text('保存')),
      ],
    );
  }

  Widget _thresholdRow({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      children: [
        Expanded(child: Text('同一视频$label达到')),
        SizedBox(
          width: 92,
          child: _plainSelect(
            value: value,
            values: List.generate(5, (index) => index + 1),
            suffix: '次',
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _numberSelect({
    required int value,
    required List<int> values,
    required String suffix,
    required ValueChanged<int>? onChanged,
  }) {
    return Expanded(
      child: _plainSelect(
        value: value,
        values: values,
        suffix: suffix,
        onChanged: onChanged,
      ),
    );
  }

  Widget _plainSelect({
    required int value,
    required List<int> values,
    required String suffix,
    required ValueChanged<int>? onChanged,
  }) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      items: values
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text('$item $suffix', maxLines: 1),
            ),
          )
          .toList(),
      onChanged: onChanged == null
          ? null
          : (value) {
              if (value != null) {
                onChanged(value);
              }
            },
    );
  }

  void _save() {
    final lookbackMinutes = (_days * 24 * 60 + _hours * 60 + _minutes)
        .clamp(1, RecommendHistoryFilterSettings.maxLookbackMinutes)
        .toInt();
    final minWatchSeconds = (_watchMinutes * 60 + _watchSeconds)
        .clamp(0, 300)
        .toInt();
    Navigator.pop(
      context,
      RecommendHistoryFilterSettings(
        enabled: _enabled,
        lookbackMinutes: lookbackMinutes,
        exposureThreshold: _exposureThreshold,
        watchThreshold: _watchThreshold,
        minWatchSeconds: minWatchSeconds,
      ),
    );
  }
}
