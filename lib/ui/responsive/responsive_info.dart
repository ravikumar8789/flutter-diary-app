import 'package:flutter/material.dart';
import 'breakpoints.dart';

class ResponsiveInfo {
  final double width;
  final double height;
  final ResponsiveBreakpoint breakpoint;

  const ResponsiveInfo({
    required this.width,
    required this.height,
    required this.breakpoint,
  });

  factory ResponsiveInfo.of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return ResponsiveInfo(
      width: size.width,
      height: size.height,
      breakpoint: ResponsiveBreakpoints.fromWidth(size.width),
    );
  }

  factory ResponsiveInfo.fromConstraints(
    BoxConstraints constraints, {
    Size? screenSize,
  }) {
    final resolvedWidth = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : (screenSize?.width ?? constraints.biggest.width);
    final resolvedHeight = constraints.maxHeight.isFinite
        ? constraints.maxHeight
        : (screenSize?.height ?? constraints.biggest.height);
    return ResponsiveInfo(
      width: resolvedWidth,
      height: resolvedHeight,
      breakpoint: ResponsiveBreakpoints.fromWidth(resolvedWidth),
    );
  }

  bool get isCompact => breakpoint == ResponsiveBreakpoint.compact;
  bool get isMedium => breakpoint == ResponsiveBreakpoint.medium;
  bool get isExpanded => breakpoint == ResponsiveBreakpoint.expanded;

  T value<T>({
    required T compact,
    T? medium,
    T? expanded,
  }) {
    switch (breakpoint) {
      case ResponsiveBreakpoint.compact:
        return compact;
      case ResponsiveBreakpoint.medium:
        return medium ?? compact;
      case ResponsiveBreakpoint.expanded:
        return expanded ?? medium ?? compact;
    }
  }
}
