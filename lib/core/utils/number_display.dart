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

/// A dive site's or dive center's star [rating] as display text, wherever it
/// appears (beside a star icon, in "3 out of 5", or in a table column): "3"
/// for three stars, the way a dive's whole-star rating reads.
///
/// Sites and centers store the rating as a double, so the editor's whole
/// stars came out as "3.0" (issue #4573). A fraction is real data rather than
/// float noise (UDDF, MacDive and CSV imports can carry 3.5), so it keeps one
/// decimal in the locale's convention; only a trailing ".0" is dropped, after
/// rounding, so 4.96 reads "5". A non-finite value renders as empty text.
String formatRatingForDisplay(double rating) {
  if (!rating.isFinite) return '';
  return localiseDoubleText(
    double.parse(rating.toStringAsFixed(1)),
    stripTrailingZero: true,
  );
}

/// [value] floored to [fractionDigits] decimals, the safe side for a limit
/// such as a MOD, or a best-mix oxygen percentage.
///
/// A tolerance of 1e-9 on the scaled value keeps a number that float noise
/// put just below a grid line on that line: 40 m computed as 39.99999999999
/// still shows as 40, not 39.
double floorToFractionDigits(double value, int fractionDigits) {
  var factor = 1.0;
  for (var i = 0; i < fractionDigits; i++) {
    factor *= 10;
  }
  return (value * factor + 1e-9).floorToDouble() / factor;
}
