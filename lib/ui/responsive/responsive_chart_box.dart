import 'package:flutter/widgets.dart';
import 'responsive_info.dart';
import 'responsive_tokens.dart';

class ResponsiveChartBox extends StatelessWidget {
  final Widget child;
  final double? aspectRatio;
  final double? compactHeight;
  final double? mediumHeight;
  final double? expandedHeight;

  const ResponsiveChartBox({
    super.key,
    required this.child,
    this.aspectRatio,
    this.compactHeight,
    this.mediumHeight,
    this.expandedHeight,
  });

  @override
  Widget build(BuildContext context) {
    if (aspectRatio != null) {
      return AspectRatio(
        aspectRatio: aspectRatio!,
        child: child,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final info = ResponsiveInfo.fromConstraints(
          constraints,
          screenSize: MediaQuery.sizeOf(context),
        );
        final height = info.value(
          compact: compactHeight ?? ResponsiveTokens.chartHeight(info),
          medium: mediumHeight ?? ResponsiveTokens.chartHeight(info),
          expanded: expandedHeight ?? ResponsiveTokens.chartHeight(info),
        );

        return SizedBox(
          height: height,
          child: child,
        );
      },
    );
  }
}
