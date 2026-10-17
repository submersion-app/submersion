import 'package:flutter/widgets.dart';

/// Ties the [MasterDetailScaffold]s below it to one list address.
///
/// A page that keeps two master-detail lists mounted at once, such as
/// Training's Certifications and Courses tabs (#3437), shows only one of them
/// at a time, but both read the selection from the URL. Under this scope a
/// scaffold reads the URL only while its path is exactly [path], and keeps
/// what it last read while the address is elsewhere. The hidden tab then
/// never tries to open the other tab's `?selected=` id, and keeps its own
/// open item, edit form included, for when the diver comes back.
class MasterDetailRouteScope extends InheritedWidget {
  const MasterDetailRouteScope({
    super.key,
    required this.path,
    required super.child,
  });

  /// The list address the scaffolds below belong to, such as
  /// `/certifications`.
  final String path;

  /// The nearest scope's path, or null when there is none.
  static String? pathOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<MasterDetailRouteScope>()
      ?.path;

  @override
  bool updateShouldNotify(MasterDetailRouteScope oldWidget) =>
      path != oldWidget.path;
}
