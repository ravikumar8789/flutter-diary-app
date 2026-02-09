import 'package:flutter/material.dart';

enum ResponsiveBreakpoint {
  compact,
  medium,
  expanded,
}

class ResponsiveBreakpoints {
  static const double compactMaxWidth = 600;
  static const double mediumMaxWidth = 900;

  static ResponsiveBreakpoint fromWidth(double width) {
    if (width < compactMaxWidth) {
      return ResponsiveBreakpoint.compact;
    }
    if (width < mediumMaxWidth) {
      return ResponsiveBreakpoint.medium;
    }
    return ResponsiveBreakpoint.expanded;
  }

  static ResponsiveBreakpoint of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return fromWidth(width);
  }

  static bool isCompact(BuildContext context) {
    return of(context) == ResponsiveBreakpoint.compact;
  }

  static bool isMedium(BuildContext context) {
    return of(context) == ResponsiveBreakpoint.medium;
  }

  static bool isExpanded(BuildContext context) {
    return of(context) == ResponsiveBreakpoint.expanded;
  }
}
