import 'package:flutter/widgets.dart';

/// Whether the subtree below is the tab on screen, for pages that keep
/// hidden tabs mounted, such as Training's Certifications and Courses
/// (#3437).
///
/// A kept-alive tab stays in its route's tree, so anything it registers with
/// the route still acts while the diver looks at the other tab. A widget that
/// intercepts Back (a selection's exit, an unsaved form's discard dialog)
/// checks [isVisible] and lets Back through while its tab is hidden.
class TabVisibility extends InheritedWidget {
  const TabVisibility({super.key, required this.visible, required super.child});

  /// Whether this tab is the one on screen.
  final bool visible;

  /// Whether [context] is in the tab on screen; true outside any tab.
  static bool isVisible(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TabVisibility>()?.visible ??
      true;

  @override
  bool updateShouldNotify(TabVisibility oldWidget) =>
      visible != oldWidget.visible;
}
