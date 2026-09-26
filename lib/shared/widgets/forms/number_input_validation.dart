import 'package:flutter/widgets.dart';

import 'package:submersion/core/utils/locale_number_symbols.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What a numeric text field holds: nothing, a number, or text that cannot
/// be read in the active locale.
///
/// The parsers return null for both blank and unreadable text, and treating
/// the two alike is how a mistyped depth used to be saved as 0 (#1900).
/// Switching on this sealed type makes every caller state what blank means
/// for its field and what happens to unreadable text, and the compiler
/// rejects a switch that forgets either.
sealed class NumberRead {
  const NumberRead();
}

final class NumberBlank extends NumberRead {
  const NumberBlank();

  @override
  bool operator ==(Object other) => other is NumberBlank;

  @override
  int get hashCode => (NumberBlank).hashCode;

  @override
  String toString() => 'NumberBlank()';
}

final class NumberValue extends NumberRead {
  const NumberValue(this.value);

  final double value;

  @override
  bool operator ==(Object other) =>
      other is NumberValue && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'NumberValue($value)';
}

final class NumberInvalid extends NumberRead {
  const NumberInvalid();

  @override
  bool operator ==(Object other) => other is NumberInvalid;

  @override
  int get hashCode => (NumberInvalid).hashCode;

  @override
  String toString() => 'NumberInvalid()';
}

/// Reads [text] with the smart parsers, which correct one unambiguous
/// wrong-separator keystroke (#1876). With [integer], a fractional value is
/// [NumberInvalid] rather than rounded.
NumberRead readNumber(String text, {bool integer = false}) {
  if (text.trim().isEmpty) return const NumberBlank();
  final value = integer
      ? smartParseUserInt(text)?.toDouble()
      : smartParseUserDecimal(text);
  return value == null ? const NumberInvalid() : NumberValue(value);
}

/// The message for unreadable [text], or null when [text] is blank or
/// readable. For the few places that show an error outside a form field.
String? invalidNumberText(
  BuildContext context,
  String text, {
  bool integer = false,
}) {
  if (readNumber(text, integer: integer) is! NumberInvalid) return null;
  return integer
      ? context.l10n.numberInput_invalidWholeNumber
      : context.l10n.numberInput_invalidNumber(
          localeNumberFormat().symbols.DECIMAL_SEP,
        );
}

/// A validator for any `validator:` slot (TextFormField, FormRow.text,
/// SuggestionFormRow). Blank passes unless [required]. Unreadable text gets
/// the shared message. [check] then applies a field's own rule to a readable
/// value and keeps that field's own message.
FormFieldValidator<String> numberValidator(
  BuildContext context, {
  bool integer = false,
  bool required = false,
  String? Function(double value)? check,
}) {
  return (text) {
    final input = text ?? '';
    return switch (readNumber(input, integer: integer)) {
      NumberBlank() => required ? context.l10n.numberInput_required : null,
      NumberInvalid() => invalidNumberText(context, input, integer: integer),
      NumberValue(:final value) => check?.call(value),
    };
  };
}
