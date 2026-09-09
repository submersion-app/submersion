import 'package:submersion/core/utils/locale_number_symbols.dart';

/// Locale-aware rendering of numbers the app DISPLAYS, as opposed to the
/// numbers a diver types, which `number_input.dart` handles.
///
/// The split is deliberate and load-bearing. `formatDecimalForInput` drops a
/// trailing ".0" because a text field wants "1250", not "1250.0"; a displayed
/// "200.0 bar" says the reading was taken to a tenth, and dropping that zero
/// loses information. Reaching for the input helper to fix a display separator
/// has already silently changed rendered text once, so the two live apart.
///
/// Neither helper here inserts grouping separators. Grouping is a separate
/// decision from the decimal separator, and the surfaces that want it
/// (altitude) format through their own `NumberFormat` pattern.

/// [value] rendered with exactly [fractionDigits] decimals in the active
/// locale's convention, keeping trailing zeros.
///
/// The digits come from [double.toStringAsFixed] and only the separators are
/// localised. See [localiseNumberSeparators] on why this is not a NumberFormat.
String formatFixedForDisplay(double value, int fractionDigits) =>
    localiseNumberSeparators(value.toStringAsFixed(fractionDigits));

/// [text] - an ASCII number Dart already formatted - re-rendered in the active
/// locale's convention.
///
/// For callers that post-process the digits before display, above all
/// `UnitFormatter`'s trailing-zero trim. That trim matches a literal '.', so it
/// has to run on ASCII text and hand the result here afterwards; run the other
/// way round, the '.' it matches under de is the grouping separator.
String localiseDecimalText(String text) => localiseNumberSeparators(text);

/// [value] rendered for display in the active locale, keeping whatever
/// precision the value itself carries: 200.0 renders "200,0" under de, not
/// "200".
///
/// The display twin of `formatDecimalForInput`. The two differ only in that
/// trailing ".0", and the difference is load bearing: the input form strips it
/// because a field seeded "1250.0" reads as a half-finished edit, while a
/// recorded reading is not an edit. A diver who logged 200.0 bar logged one
/// decimal of precision, so dropping it changes what the value claims.
///
/// Use this where the value's own precision is the message and there is no
/// unit-driven number of decimals to pin; use [formatFixedForDisplay] where
/// there is. Unlike that one, this renders a non-finite value as empty text
/// rather than "NaN", matching its input twin.
String formatDecimalForDisplay(double value) {
  if (!value.isFinite) return '';
  return localiseDoubleText(value, stripTrailingZero: false);
}
