import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/core/utils/locale_number_symbols.dart';

import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// Input filter for numeric fields: digits, both ASCII separators (the smart
/// parser corrects a wrong one), and the active locale's own decimal and
/// grouping characters, plus '-' and the locale's minus sign only where a
/// value can be negative (temperatures, time offsets).
///
/// The locale's characters matter because a field is seeded with them: an
/// ar_EG seed of "1٫3" run through an ASCII-only filter on the first
/// edit would become "13" before validation could see it, and he/ar prefix
/// the minus with a direction mark (#1900 review).
List<TextInputFormatter> numberInputFormatters({bool allowNegative = false}) {
  final symbols = localeNumberFormat().symbols;
  final allowed = <String>{
    '.',
    ',',
    ...symbols.DECIMAL_SEP.split(''),
    ...symbols.GROUP_SEP.split(''),
    if (allowNegative) ...['-', ...symbols.MINUS_SIGN.split('')],
  };
  final escaped = allowed.map((c) => r'\]^-['.contains(c) ? '\\$c' : c);
  return [FilteringTextInputFormatter.allow(RegExp('[0-9${escaped.join()}]'))];
}

/// A numeric text field that shows why its text cannot be read, as the diver
/// types, and makes an enclosing Form refuse to validate while it cannot.
///
/// It reports every change as a [NumberRead] and remembers no value itself.
/// A live caller decides in its own switch what [NumberInvalid] does, which
/// is keep the last readable value the diver typed: that rule stays visible
/// where the value is stored instead of hiding inside the widget.
class NumberField extends StatelessWidget {
  const NumberField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.decoration = const InputDecoration(),
    this.integer = false,
    this.allowNegative = false,
    this.required = false,
    this.check,
    this.focusNode,
    this.enabled = true,
    this.textAlign = TextAlign.start,
    this.textInputAction,
    this.onEditingComplete,
    this.onFieldSubmitted,
    this.style,
  });

  final TextEditingController controller;
  final ValueChanged<NumberRead> onChanged;
  final InputDecoration decoration;
  final bool integer;
  final bool allowNegative;
  final bool required;
  final String? Function(double value)? check;
  final FocusNode? focusNode;
  final bool enabled;
  final TextAlign textAlign;
  final TextInputAction? textInputAction;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onFieldSubmitted;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      style: style,
      textAlign: textAlign,
      textInputAction: textInputAction,
      // Numeric fields often sit two or three to a row; one line would cut
      // the message off before the separator hint, its most useful part.
      decoration: decoration.copyWith(
        errorMaxLines: decoration.errorMaxLines ?? 3,
      ),
      keyboardType: TextInputType.numberWithOptions(
        decimal: !integer,
        signed: allowNegative,
      ),
      inputFormatters: numberInputFormatters(allowNegative: allowNegative),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: numberValidator(
        context,
        integer: integer,
        required: required,
        check: check,
      ),
      onChanged: (text) => onChanged(readNumber(text, integer: integer)),
      onEditingComplete: onEditingComplete,
      onFieldSubmitted: onFieldSubmitted,
    );
  }
}
