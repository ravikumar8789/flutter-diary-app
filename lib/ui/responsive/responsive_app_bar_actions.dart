import 'package:flutter/material.dart';
import 'responsive_info.dart';

class ResponsiveAppBarActions extends StatelessWidget {
  final List<Widget> regularActions;
  final List<Widget> compactActions;

  const ResponsiveAppBarActions({
    super.key,
    required this.regularActions,
    required this.compactActions,
  });

  @override
  Widget build(BuildContext context) {
    final info = ResponsiveInfo.of(context);
    final actions = info.isCompact ? compactActions : regularActions;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: actions,
    );
  }
}
