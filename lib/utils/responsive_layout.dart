import 'package:flutter/material.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget mobileLayout;
  final Widget tabletLayout;
  final Widget desktopLayout;

  /// Defaults: 600 for tablet, 900 for desktop
  final double tabletBreakpoint;
  final double desktopBreakpoint;

  const ResponsiveLayout({
    Key? key,
    required this.mobileLayout,
    required this.tabletLayout,
    required this.desktopLayout,
    this.tabletBreakpoint = 600,
    this.desktopBreakpoint = 900,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width >= desktopBreakpoint) {
      return desktopLayout;
    } else if (width >= tabletBreakpoint) {
      return tabletLayout;
    } else {
      return mobileLayout;
    }
  }
}
