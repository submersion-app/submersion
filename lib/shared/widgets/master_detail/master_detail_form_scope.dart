import 'package:flutter/widgets.dart';

/// Tells a master-detail list whether a create or edit form is open in the
/// detail pane beside it.
///
/// [MasterDetailScaffold] provides it around the master pane. A list's own
/// create button (an empty state's "Add your first ..." button) reads it and
/// hides itself while a form is open: beside the form it reads as the form's
/// submit button, but it only reopens the create form, so nothing gets saved
/// (issue #3192). The scaffold hides its create FAB for the same span
/// (issue #3174).
class MasterDetailFormScope extends InheritedWidget {
  const MasterDetailFormScope({
    super.key,
    required this.isFormOpen,
    required super.child,
  });

  /// Whether a create or edit form is shown in the detail pane.
  final bool isFormOpen;

  /// Whether a form is open beside [context]'s list. False outside a
  /// master-detail layout (a phone, or a full-width table).
  static bool isFormOpenOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<MasterDetailFormScope>()
          ?.isFormOpen ??
      false;

  @override
  bool updateShouldNotify(MasterDetailFormScope oldWidget) =>
      oldWidget.isFormOpen != isFormOpen;
}
