import 'package:flutter/widgets.dart';

/// The actions the app runs on, for `MaterialApp.actions`: Flutter's
/// defaults, with a tap off a focused text field putting the keyboard away on
/// a touch screen too (#4813).
///
/// Flutter's own default drops a field's focus on a tap outside it for a
/// mouse and on every desktop and browser, but not for a finger on a phone
/// or tablet. There the keyboard stays up over the bottom bar, with nothing
/// on a page to close it; this brings touch in line with the mouse. A
/// control that belongs to a field (its completions, a formatting bar, a
/// row shown only while it has focus) must sit in a [TextFieldTapRegion] to
/// count as part of the field, or a tap on it drops the focus first.
///
/// The same map every call: `Actions` compares its map by value, so a fresh
/// action on each rebuild of the app would rebuild everything that looked an
/// action up.
Map<Type, Action<Intent>> appActions() => _appActions;

final Map<Type, Action<Intent>> _appActions = Map.unmodifiable({
  ...WidgetsApp.defaultActions,
  EditableTextTapOutsideIntent: _UnfocusOnTapOutside(),
});

class _UnfocusOnTapOutside extends ContextAction<EditableTextTapOutsideIntent> {
  @override
  void invoke(EditableTextTapOutsideIntent intent, [BuildContext? context]) =>
      intent.focusNode.unfocus();
}
