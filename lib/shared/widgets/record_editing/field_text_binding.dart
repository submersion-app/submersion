import 'package:flutter/widgets.dart';

import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/text_keeping_caret.dart';

/// What a field's text reads as: a value, or text that is not one.
///
/// Blank is a value like any other (usually null), so each field says what
/// blank means for it in its `parse`.
sealed class FieldInput<V> {
  const FieldInput();
}

final class FieldValue<V> extends FieldInput<V> {
  const FieldValue(this.value);

  final V value;
}

final class FieldUnreadable<V> extends FieldInput<V> {
  const FieldUnreadable();
}

/// Keeps a text controller in step with one field of an [EditSession].
///
/// The session holds values; the controller holds what the diver typed. The
/// two are compared by what the text reads as, never as text, using the
/// field's own [EditField.same]:
///
/// - When the diver edits the text and it reads as a value, the value goes to
///   the session. Text that is not a value leaves the session alone and is
///   reported through [onUnreadableChanged].
/// - When the session changes, the text is replaced only if it no longer
///   reads as the session's value. So `100.` survives while the diver is
///   still typing, a value shown in another unit is not written back as a
///   change, and unreadable text is left for the diver to fix.
///
/// A change of selection alone, and text this binding set itself, are not
/// edits.
class FieldTextBinding<T, V> {
  FieldTextBinding({
    required this.session,
    required this.field,
    required this.format,
    required this.parse,
    this.onUnreadableChanged,
    this.onEdited,
    this.apply,
  }) : controller = TextEditingController(
         text: format(session.valueOf(field)),
       ) {
    _lastText = controller.text;
    controller.addListener(_onTextChanged);
    session.addListener(resync);
  }

  /// A binding of a text value: any text is the value, a blank one too (a
  /// field stores a blank optional value as none).
  FieldTextBinding.plain({
    required EditSession<T> session,
    required EditField<T, V> field,
    required String Function(V value) format,
  }) : this(
         session: session,
         field: field,
         format: format,
         parse: (text) => FieldValue<V>(text as V),
       );

  final EditSession<T> session;
  final EditField<T, V> field;

  /// The text to show for a value.
  final String Function(V value) format;

  /// What a text reads as.
  final FieldInput<V> Function(String text) parse;

  /// Told when the text becomes, or stops being, unreadable.
  final ValueChanged<bool>? onUnreadableChanged;

  /// Told after the diver's own edit has reached the session: text they
  /// typed that reads as a value. Not told of text this binding put there
  /// from the session, so a rule that follows from the diver's edit does
  /// not run for a value that arrived from elsewhere.
  final VoidCallback? onEdited;

  /// Writes a value the diver typed. Null is `session.set(field, value)`.
  /// For a value whose change moves others, such as a runtime that moves
  /// the exit.
  final void Function(V value)? apply;

  final TextEditingController controller;

  late String _lastText;
  bool _isUnreadable = false;
  bool _disposed = false;

  /// Whether the text cannot be read as a value.
  bool get isUnreadable => _isUnreadable;

  void _onTextChanged() {
    final text = controller.text;
    // The caret moved, or this binding set the text itself.
    if (text == _lastText) return;
    _lastText = text;
    switch (parse(text)) {
      case FieldValue<V>(:final value):
        _setUnreadable(false);
        final apply = this.apply;
        if (apply != null) {
          apply(value);
        } else {
          session.set(field, value);
        }
        onEdited?.call();
      case FieldUnreadable<V>():
        _setUnreadable(true);
    }
  }

  /// Shows the session's value again unless the text already reads as it.
  ///
  /// Runs on every session change. Call it as well when [format] or [parse]
  /// would now give a different answer, such as after a change of unit.
  void resync() {
    if (_disposed || _isUnreadable) return;
    final value = session.valueOf(field);
    final shown = parse(controller.text);
    if (shown is FieldValue<V> && field.same(shown.value, value)) return;
    final text = format(value);
    _lastText = text;
    // The diver can be in the field when its value arrives from elsewhere.
    controller.replaceTextKeepingCaret(text);
  }

  /// Shows the session's value as [format] gives it now, even when the text
  /// already reads as that value: for a [format] that has started to give
  /// another text for the same value, such as a title shown blank once it
  /// only repeats a name that has since loaded. Not an edit.
  void reformat() {
    if (_disposed || _isUnreadable) return;
    final text = format(session.valueOf(field));
    if (text == controller.text) return;
    _lastText = text;
    controller.replaceTextKeepingCaret(text);
  }

  void _setUnreadable(bool unreadable) {
    if (unreadable == _isUnreadable) return;
    _isUnreadable = unreadable;
    onUnreadableChanged?.call(unreadable);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    session.removeListener(resync);
    controller.dispose();
  }
}
