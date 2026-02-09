import 'package:flutter/widgets.dart';
import 'responsive_info.dart';
import 'responsive_tokens.dart';

SliverGridDelegateWithMaxCrossAxisExtent responsiveGridDelegate({
  required ResponsiveInfo info,
  double? maxTileWidth,
  double? spacing,
  double? childAspectRatio,
}) {
  final tileWidth = maxTileWidth ?? ResponsiveTokens.gridMinTileWidth(info);
  final gap = spacing ?? ResponsiveTokens.spacingM(info);

  return SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: tileWidth,
    mainAxisSpacing: gap,
    crossAxisSpacing: gap,
    childAspectRatio: childAspectRatio ?? 1.4,
  );
}

int responsiveCardCrossAxisCount(ResponsiveInfo info) {
  return info.isExpanded ? 4 : 2;
}

SliverGridDelegateWithFixedCrossAxisCount responsiveCardGridDelegate({
  required ResponsiveInfo info,
  double? spacing,
  double? childAspectRatio,
}) {
  final gap = spacing ?? ResponsiveTokens.spacingM(info);
  final double ratio =
      childAspectRatio ?? info.value(compact: 1.4, medium: 1.6, expanded: 1.8);

  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: responsiveCardCrossAxisCount(info),
    mainAxisSpacing: gap,
    crossAxisSpacing: gap,
    childAspectRatio: ratio,
  );
}
