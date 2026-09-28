import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// A [ShortcutActivator] that stands down while an editable text field has
/// focus, so a printable shortcut key reaches the field as typed text.
///
/// Shortcut bindings mounted around the app shell see every key event that
/// bubbles up from a focused text field, and a text field does not claim
/// printable keys at the focus level: it relies on the event going unhandled
/// so the engine forwards it to the text input system. A bare "?" binding
/// therefore swallowed the character in notes and every other field (#2145).
///
/// Declining to match here, rather than returning early from the callback,
/// is what lets the event go unhandled: once a `CallbackShortcuts` activator
/// matches, the event counts as handled whatever the callback does.
///
/// Read-only text (such as `SelectableText`, also built on [EditableText])
/// does not count as typing, so the shortcut still works there.
class NotWhileTypingActivator extends ShortcutActivator {
  const NotWhileTypingActivator(this.activator);

  /// The activator that decides the key combination itself.
  final ShortcutActivator activator;

  @override
  Iterable<LogicalKeyboardKey>? get triggers => activator.triggers;

  @override
  bool accepts(KeyEvent event, HardwareKeyboard state) =>
      activator.accepts(event, state) && !isEditingText();

  @override
  String debugDescribeKeys() =>
      '${activator.debugDescribeKeys()} (not while typing)';

  /// Whether the primary focus is inside a text field that accepts input.
  static bool isEditingText() {
    // The focus node's context is the Focus widget EditableText builds
    // beneath itself, so the field is always an ancestor, never the widget.
    final editable = FocusManager.instance.primaryFocus?.context
        ?.findAncestorWidgetOfExactType<EditableText>();
    return editable != null && !editable.readOnly;
  }
}
