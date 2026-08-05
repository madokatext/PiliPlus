import 'package:flutter/material.dart';

class ReplyDivider extends StatelessWidget {
  const ReplyDivider({super.key, this.fullWidth = false});

  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    return Divider(
      indent: fullWidth ? 0 : 55,
      endIndent: fullWidth ? 0 : 15,
      height: 0.3,
      color: colorScheme.outline.withValues(alpha: 0.08),
    );
  }
}
