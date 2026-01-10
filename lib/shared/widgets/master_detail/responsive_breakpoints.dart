import 'package:flutter/widgets.dart';

/// Centralized responsive breakpoint constants and helpers for the app.
///
/// These values align with the existing MainScaffold breakpoints:
/// - 800px: Desktop mode (NavigationRail)
/// - 1200px: Extended NavigationRail with labels
class ResponsiveBreakpoints {
  ResponsiveBreakpoints._();

  /// Width at which desktop layout activates (NavigationRail, master-detail)
  static const double desktop = 800.0;

  /// Width at which extended mode activates (NavigationRail with labels)
  static const double desktopExtended = 1200.0;

  /// Check if the current screen is desktop width (>=800px)
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktop;
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
