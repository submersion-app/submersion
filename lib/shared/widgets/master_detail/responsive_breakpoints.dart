import 'package:flutter/widgets.dart';

/// Centralized responsive breakpoint constants and helpers for the app.
///
/// Breakpoint hierarchy:
/// - 800px: Desktop mode (NavigationRail replaces bottom nav)
/// - 1100px: Master-detail layouts activate (split view with list + detail)
/// - 1200px: Extended NavigationRail with labels
class ResponsiveBreakpoints {
  ResponsiveBreakpoints._();

  /// Width at which desktop layout activates (NavigationRail)
  static const double desktop = 800.0;

  /// Width at which master-detail layouts activate (split view)
  /// Higher than desktop to ensure detail panes have adequate width
  static const double masterDetail = 1100.0;

  /// Width at which extended mode activates (NavigationRail with labels)
  static const double desktopExtended = 1200.0;

  /// Check if the current screen is desktop width (>=800px)
  /// Use for NavigationRail vs bottom nav decisions
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktop;
  }

  /// Check if the current screen is wide enough for master-detail (>=1100px)
  /// Use for split-view layouts (list + detail pane)
  static bool isMasterDetail(BuildContext context) {
    return MediaQuery.of(context).size.width >= masterDetail;
  }

  /// Check if the current screen is extended desktop width (>=1200px)
  static bool isDesktopExtended(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktopExtended;
  }

  /// Check if the current screen is mobile width (<800px)
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < desktop;
  }

  /// Get the screen width
  static double screenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }
}
