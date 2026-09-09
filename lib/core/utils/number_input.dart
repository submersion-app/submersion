import 'package:intl/intl.dart';

/// Locale-aware conversion between a number and the text a diver types into a
/// form field.
///
/// `double.tryParse` implements the Dart literal grammar, so it only ever
/// accepts '.' as the decimal separator. Reading a form field with it discards
/// everything a diver in a comma-decimal locale types ("12,50" -> null), and
/// because the repositories write `Value(null)` rather than `Value.absent()`,
/// that null erases the stored value instead of leaving it alone (#1091).
///
/// The same separator problem applies to numbers a diver only reads, so the
/// display-side twin [formatDecimalForDisplay] lives here too, sharing the
/// locale cache and separator swap rather than growing a second copy of them.
///
/// The seeded text and the parser must share one convention. Seeding a field
/// with `double.toString()` and reading it back through a locale-aware parser
/// is worse than the original bug: under de/es/it, '.' is the GROUPING
/// separator, so "12.5" parses as 125. Always pair [formatDecimalForInput]
/// with [parseUserDecimal].

/// The active locale's decimal format, rebuilt only when the locale changes.
///
/// These helpers run from `onChanged`, so they are on the keystroke path, and
/// building a NumberFormat means a locale lookup plus a pattern parse every
/// time. The cache is keyed on the locale because `Intl.defaultLocale` is a
/// MUTABLE process global: the app sets it when the diver switches language,
/// and tests reassign it freely, so a cache that ignored it would silently
/// format and parse against the previous locale.
///
/// Callers must treat the returned instance as read-only. `parse` and `symbols`
/// do not mutate it; anything that needs `turnOffGrouping` or a different digit
/// count must build its own.
String? _cachedLocale;
NumberFormat? _cachedFormat;

NumberFormat _localeFormat() {
  final locale = Intl.getCurrentLocale();
  final cached = _cachedFormat;
  if (cached != null && _cachedLocale == locale) return cached;
  final format = NumberFormat.decimalPattern(locale);
  _cachedLocale = locale;
  _cachedFormat = format;
  return format;
}

/// The number [text] represents in the active locale, or null when [text] is
/// blank or cannot be read as a finite number.
///
/// Callers must distinguish the two null cases themselves: a blank field means
/// "no value", while unreadable text means the diver typed something that needs
/// correcting, and silently storing null there is data loss.
double? parseUserDecimal(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  if (!_groupingIsWellFormed(trimmed)) return null;
  try {
    final value = _localeFormat().parse(trimmed);
    // intl parses "NaN" and "Infinity" under some locales; neither survives a
    // round trip through the database as a meaningful quantity.
    return value.isFinite ? value.toDouble() : null;
  } on FormatException {
    return null;
  }
}

/// Whether any grouping separators in [text] sit where grouping could actually
/// put them (leading group of 1 to 3 digits, every later group exactly 3).
///
/// intl's parser is lenient about this, so it reads en_US "6,4" as 64. That
/// silently records a number the diver never typed, which is the failure this
/// whole file exists to stop, so ambiguous input is treated as unreadable
/// instead of guessed. A diver in a comma-decimal locale using an
/// English-language device would otherwise log 64 m of visibility for "6,4".
bool _groupingIsWellFormed(String text) {
  final symbols = _localeFormat().symbols;
  final groupSep = symbols.GROUP_SEP;
  if (groupSep.isEmpty) return true;

  final decimalIndex = text.indexOf(symbols.DECIMAL_SEP);
  var integerPart = decimalIndex >= 0 ? text.substring(0, decimalIndex) : text;

  // Where the locale groups with a space it is a narrow no-break one, but a
  // keyboard or a paste produces any of the space-like characters and intl
  // accepts them all. Dart's \s covers the Unicode Zs category, which
  // normalises every variant before the positions are checked.
  if (groupSep.trim().isEmpty) {
    integerPart = integerPart.replaceAll(RegExp(r'\s'), groupSep);
  }
  if (!integerPart.contains(groupSep)) return true;

  final groups = integerPart
      .replaceAll(symbols.MINUS_SIGN, '')
      .replaceAll('-', '')
      .split(groupSep);
  if (groups.first.isEmpty || groups.first.length > 3) return false;
  return groups.skip(1).every((group) => group.length == 3);
}

/// The whole number [text] represents in the active locale, or null when
/// [text] is blank, unreadable, or carries a fractional part.
///
/// A fraction is rejected rather than rounded: the fields that use this hold
/// counts and durations, and rounding a diver's "12,5" would store a number
/// they never typed.
int? parseUserInt(String text) {
  final value = parseUserDecimal(text);
  if (value == null || value != value.roundToDouble()) return null;
  return value.toInt();
}

/// [value] rendered for seeding an editable field, in the active locale's
/// decimal convention and without grouping separators.
///
/// Grouping is omitted deliberately: a seeded "1 250,75" carries a narrow
/// no-break space that is awkward to edit and easy to break by hand.
///
/// The digits come from [double.toString], which yields the shortest decimal
/// that reads back as the same double, and only the separator is localised.
/// NumberFormat is the wrong tool for the digits here: it renders the exact
/// binary value, so raising its 3-digit cap far enough to stop it rounding
/// 12.345678 to 12.346 makes it start emitting noise instead (12.05 becomes
/// "12.050000000000001"). Callers wanting fewer decimals round before calling.
String formatDecimalForInput(double value) {
  if (!value.isFinite) return '';
  return _localiseDouble(value, stripTrailingZero: true);
}

/// [value] rendered for display in the active locale, keeping whatever
/// precision the value itself carries: 200.0 renders "200,0" under de, not
/// "200".
///
/// The display twin of [formatDecimalForInput]. The two differ only in that
/// trailing ".0", and the difference is load bearing: the input form strips it
/// because a field seeded "1250.0" reads as a half-finished edit, while a
/// recorded reading is not an edit. A diver who logged 200.0 bar logged one
/// decimal of precision, so dropping it changes what the value claims.
///
/// Use this for anything a diver only reads. Callers wanting a pinned number
/// of decimals should round before calling.
String formatDecimalForDisplay(double value) {
  if (!value.isFinite) return '';
  return _localiseDouble(value, stripTrailingZero: false);
}

/// [value] rounded to [fractionDigits] and rendered for seeding, with trailing
/// zeros dropped (12.0 seeds as "12", not "12.0").
///
/// Most converted fields want this: a unit conversion such as kg to lbs leaves
/// a long fractional tail that would otherwise leak into the field.
String formatRoundedForInput(double value, int fractionDigits) {
  if (!value.isFinite) return '';
  return formatDecimalForInput(
    double.parse(value.toStringAsFixed(fractionDigits)),
  );
}

/// [value] rendered for seeding with exactly [fractionDigits] decimals, keeping
/// trailing zeros (2 seeds as "2.0" at one digit).
///
/// Distinct from [formatRoundedForInput] on purpose. The two differ only in
/// trailing zeros, which is precisely why they belong side by side: the dive
/// log seeds at a pinned precision and its displayed "2.0" is load-bearing,
/// while every other field drops the zero. Keeping both here stops per-widget
/// copies from drifting apart.
String formatFixedForInput(double value, int fractionDigits) {
  if (!value.isFinite) return '';
  return _localiseSeparators(value.toStringAsFixed(fractionDigits));
}

/// The shared body of [formatDecimalForInput] and [formatDecimalForDisplay].
///
/// [stripTrailingZero] is applied here rather than by either caller because it
/// matches on the ASCII '.' that [double.toString] emits; once the text has
/// been localised it carries the locale's separator instead, and under de the
/// '.' it would then match is the grouping separator.
String _localiseDouble(double value, {required bool stripTrailingZero}) {
  var text = value.toString();
  // Very large or very small magnitudes stringify in exponent notation, which
  // no diver can meaningfully read or edit and no parser here reads back.
  if (text.contains('e') || text.contains('E')) {
    final format = NumberFormat.decimalPattern()
      ..turnOffGrouping()
      ..maximumFractionDigits = 15;
    return format.format(value);
  }
  if (stripTrailingZero && text.endsWith('.0')) {
    text = text.substring(0, text.length - 2);
  }
  return _localiseSeparators(text);
}

/// Swaps the ASCII '.' and '-' produced by Dart's own number formatting for the
/// active locale's decimal separator and minus sign.
String _localiseSeparators(String text) {
  final symbols = _localeFormat().symbols;
  return text
      .replaceFirst('.', symbols.DECIMAL_SEP)
      .replaceFirst('-', symbols.MINUS_SIGN);
}
