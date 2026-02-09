import 'package:flutter/material.dart';
import 'responsive_info.dart';

class ResponsiveTokens {
  static double spacingXs(ResponsiveInfo info) {
    return info.value(compact: 4, medium: 6, expanded: 8);
  }

  static double spacingS(ResponsiveInfo info) {
    return info.value(compact: 8, medium: 10, expanded: 12);
  }

  static double spacingM(ResponsiveInfo info) {
    return info.value(compact: 12, medium: 16, expanded: 20);
  }

  static double spacingL(ResponsiveInfo info) {
    return info.value(compact: 20, medium: 24, expanded: 32);
  }

  static double screenPaddingHorizontal(ResponsiveInfo info) {
    return info.value(compact: 16, medium: 24, expanded: 32);
  }

  static double screenPaddingVertical(ResponsiveInfo info) {
    return info.value(compact: 16, medium: 20, expanded: 24);
  }

  static EdgeInsets screenPadding(ResponsiveInfo info) {
    return EdgeInsets.symmetric(
      horizontal: screenPaddingHorizontal(info),
      vertical: screenPaddingVertical(info),
    );
  }

  static double maxContentWidth(ResponsiveInfo info) {
    return info.value(compact: 520, medium: 720, expanded: 840);
  }

  static double gridMinTileWidth(ResponsiveInfo info) {
    return info.value(compact: 160, medium: 200, expanded: 240);
  }

  static double chartHeight(ResponsiveInfo info) {
    return info.value(compact: 220, medium: 260, expanded: 300);
  }
}
