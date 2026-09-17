import 'package:flutter/services.dart';

/// Limits a decimal field to [maxIntDigits] digits before the separator and
/// [maxFractionDigits] after it, whichever of '.' or ',' the diver types
/// (issue #1876). Every value the mixer's fields hold (percentages, prices,
/// volumes, and pressure once converted to the diver's unit) fits inside a
/// small, known range, so this catches a stray extra digit at the keystroke
/// rather than after the fact.
///
/// Deliberately locale-agnostic about which character is "the" separator:
/// that is [smartParseUserDecimal]'s job once the diver is done typing. This
/// formatter only stops a second separator and stops either side from
/// growing past its digit budget.
///
/// Known, accepted limitation: under a comma-decimal locale, a locale-valid
/// grouped integer like "4.350" (meaning 4350, e.g. a psi pressure) has the
/// same shape as three rejected fraction digits, so this formatter blocks
/// that keystroke even though [smartParseUserDecimal] would read it
/// correctly. A diver hitting this can still type the digits without the
/// grouping separator (e.g. "4350"); making the cap locale-aware to lift it
/// would conflict with the digit budget every other field on the same
/// contract depends on (see blender_decimal_digits_formatter_test.dart).
class BlenderDecimalDigitsFormatter extends TextInputFormatter {
  const BlenderDecimalDigitsFormatter({
    this.maxIntDigits = 3,
    this.maxFractionDigits = 2,
  });

  final int maxIntDigits;
  final int maxFractionDigits;

  static final _separator = RegExp('[.,]');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    if (_separator.allMatches(text).length > 1) return oldValue;

    final sepIndex = text.indexOf(_separator);
    if (sepIndex == -1) {
      return text.length > maxIntDigits ? oldValue : newValue;
    }
    final intDigits = sepIndex;
    final fractionDigits = text.length - sepIndex - 1;
    if (intDigits > maxIntDigits || fractionDigits > maxFractionDigits) {
      return oldValue;
    }
    return newValue;
  }
}
