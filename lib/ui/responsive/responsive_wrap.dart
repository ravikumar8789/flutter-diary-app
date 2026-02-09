import 'package:flutter/widgets.dart';
import 'responsive_info.dart';
import 'responsive_tokens.dart';

class ResponsiveWrapRow extends StatelessWidget {
  final ResponsiveInfo info;
  final List<Widget> children;
  final double? spacing;
  final double? runSpacing;
  final MainAxisAlignment rowMainAxisAlignment;
  final WrapAlignment wrapAlignment;
  final WrapCrossAlignment wrapCrossAlignment;
  final MainAxisSize rowMainAxisSize;

  const ResponsiveWrapRow({
    super.key,
    required this.info,
    required this.children,
    this.spacing,
    this.runSpacing,
    this.rowMainAxisAlignment = MainAxisAlignment.start,
    this.wrapAlignment = WrapAlignment.start,
    this.wrapCrossAlignment = WrapCrossAlignment.start,
    this.rowMainAxisSize = MainAxisSize.max,
  });

  @override
  Widget build(BuildContext context) {
    final gap = spacing ?? ResponsiveTokens.spacingS(info);
    final runGap = runSpacing ?? ResponsiveTokens.spacingS(info);

    if (info.isCompact) {
      return Wrap(
        spacing: gap,
        runSpacing: runGap,
        alignment: wrapAlignment,
        crossAxisAlignment: wrapCrossAlignment,
        children: children,
      );
    }

    return Row(
      mainAxisSize: rowMainAxisSize,
      mainAxisAlignment: rowMainAxisAlignment,
      children: children,
    );
  }
}
