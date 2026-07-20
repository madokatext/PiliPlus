import 'package:PiliPlus/utils/extension/num_ext.dart';
import 'package:flutter/material.dart';

class DualSliderDialog extends StatefulWidget {
  final double value1;
  final double value2;
  final Widget title;
  final Widget description1;
  final Widget description2;
  final double min;
final double max;
final int? divisions;

final double? min1;
final double? max1;
final int? divisions1;

final double? min2;
final double? max2;
final int? divisions2;

final String suffix;
final int precise;

  const DualSliderDialog({
  super.key,
  required this.value1,
  required this.value2,
  required this.description1,
  required this.description2,
  required this.title,
  required this.min,
  required this.max,
  this.divisions,
  this.min1,
  this.max1,
  this.divisions1,
  this.min2,
  this.max2,
  this.divisions2,
  this.suffix = '',
  this.precise = 1,
});

  @override
  State<DualSliderDialog> createState() => _DualSliderDialogState();
}

class _DualSliderDialogState extends State<DualSliderDialog> {
  late double _tempValue1;
  late double _tempValue2;

  @override
  void initState() {
    super.initState();
    _tempValue1 = widget.value1;
    _tempValue2 = widget.value2;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: widget.title,
      contentPadding: const EdgeInsets.only(
        top: 20,
        left: 8,
        right: 8,
        bottom: 8,
      ),
      content: Column(
        mainAxisSize: .min,
        children: [
          widget.description1,
          Builder(
            builder: (context) {
              return Slider(
  value: _tempValue1,
  min: widget.min1 ?? widget.min,
  max: widget.max1 ?? widget.max,
  divisions: widget.divisions1 ?? widget.divisions,
                label:
                    '${_tempValue1.toStringAsFixed(widget.precise)}${widget.suffix}',
                onChanged: (double value) {
                  _tempValue1 = value.toPrecision(widget.precise);
                  (context as Element).markNeedsBuild();
                },
              );
            },
          ),
          widget.description2,
          Builder(
            builder: (context) {
              return Slider(
  value: _tempValue2,
  min: widget.min2 ?? widget.min,
  max: widget.max2 ?? widget.max,
  divisions: widget.divisions2 ?? widget.divisions,
                label:
                    '${_tempValue2.toStringAsFixed(widget.precise)}${widget.suffix}',
                onChanged: (double value) {
                  _tempValue2 = value.toPrecision(widget.precise);
                  (context as Element).markNeedsBuild();
                },
              );
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: Navigator.of(context).pop,
          child: Text(
            '取消',
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, (_tempValue1, _tempValue2)),
          child: const Text('确定'),
        ),
      ],
    );
  }
}
