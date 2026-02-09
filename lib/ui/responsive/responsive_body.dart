import 'package:flutter/material.dart';
import 'responsive_info.dart';
import 'responsive_tokens.dart';

class ResponsiveBody extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Alignment alignment;
  final double? maxWidth;
  final bool useSafeArea;
  final bool useScrollbar;
  final bool useScrollView;
  final ScrollController? scrollController;

  const ResponsiveBody({
    super.key,
    required this.child,
    this.padding,
    this.alignment = Alignment.topCenter,
    this.maxWidth,
    this.useSafeArea = true,
    this.useScrollbar = false,
    this.useScrollView = false,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = LayoutBuilder(
      builder: (context, constraints) {
        final info = ResponsiveInfo.fromConstraints(
          constraints,
          screenSize: MediaQuery.sizeOf(context),
        );
        final resolvedPadding = padding ?? ResponsiveTokens.screenPadding(info);
        final resolvedMaxWidth =
            maxWidth ?? ResponsiveTokens.maxContentWidth(info);

        return Align(
          alignment: alignment,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: resolvedMaxWidth),
            child: Padding(
              padding: resolvedPadding,
              child: child,
            ),
          ),
        );
      },
    );

    if (useScrollView) {
      content = SingleChildScrollView(
        controller: scrollController,
        child: content,
      );
    }

    if (useScrollbar) {
      content = Scrollbar(child: content);
    }

    if (useSafeArea) {
      content = SafeArea(child: content);
    }

    return content;
  }
}

class ResponsiveScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;
  final EdgeInsets? padding;
  final double? maxWidth;
  final bool useSafeArea;
  final bool useScrollbar;
  final bool bodyScroll;

  const ResponsiveScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.backgroundColor,
    this.padding,
    this.maxWidth,
    this.useSafeArea = true,
    this.useScrollbar = false,
    this.bodyScroll = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      backgroundColor: backgroundColor,
      bottomNavigationBar: bottomNavigationBar,
      body: ResponsiveBody(
        padding: padding,
        maxWidth: maxWidth,
        useSafeArea: useSafeArea,
        useScrollbar: useScrollbar,
        useScrollView: bodyScroll,
        child: body,
      ),
    );
  }
}
