import 'package:flutter/widgets.dart';

/// The actions the app runs on, for `MaterialApp.actions`: Flutter's
/// defaults, with a tap off a focused text field putting the keyboard away on
/// a touch screen too (#4813).
///
/// Flutter's own default drops a field's focus on a tap outside it for a
/// mouse and on every desktop and browser, but not for a finger on a phone
/// or tablet. There the keyboard stays up over the bottom bar, with nothing
/// on a page to close it. The app's fields already work with the desktop
/// behaviour, so this brings touch in line with it. A control that belongs
/// to a field (its completions, a formatting bar) sits in a
/// [TextFieldTapRegion] to count as part of the field.
Map<Type, Action<Intent>> appActions() => {
  ...WidgetsApp.defaultActions,
  EditableTextTapOutsideIntent: _UnfocusOnTapOutside(),
};

class _UnfocusOnTapOutside extends ContextAction<EditableTextTapOutsideIntent> {
  @override
  void invoke(EditableTextTapOutsideIntent intent, [BuildContext? context]) =>
      intent.focusNode.unfocus();
}
