import 'package:intl/intl.dart';

/// The active locale's number symbols, shared by the two halves of the app's
/// numeric text handling: `number_input.dart` (what a diver types) and
/// `number_display.dart` (what the app renders back).
///
/// Both halves must resolve against one instance. A field seeded through one
/// convention and read through another is the #1091 failure - under de/es/it
/// '.' is the GROUPING separator, so "12.5" reads back as 125 - and keeping
/// two private caches would be a slow way to reintroduce it.

/// The active locale's decimal format, rebuilt only when the locale changes.
///
/// These helpers run from `onChanged`, so they are on the keystroke path, and
/// building a NumberFormat means a locale lookup plus a pattern parse every
/// time. The cache is keyed on the locale because `Intl.defaultLocale` is a
/// MUTABLE process global: the app sets it when the diver switches language
/// (`lib/app.dart`), and tests reassign it freely, so a cache that ignored it
/// would silently format and parse against the previous locale.
///
/// Callers must treat the returned instance as read-only. `parse` and `symbols`
/// do not mutate it; anything that needs `turnOffGrouping` or a different digit
/// count must build its own.
String? _cachedLocale;
NumberFormat? _cachedFormat;

NumberFormat localeNumberFormat() {
  final locale = Intl.getCurrentLocale();
  final cached = _cachedFormat;
  if (cached != null && _cachedLocale == locale) return cached;
  final format = NumberFormat.decimalPattern(locale);
  _cachedLocale = locale;
  _cachedFormat = format;
  return format;
}

/// Swaps the ASCII '.' and '-' produced by Dart's own number formatting for the
/// active locale's decimal separator and minus sign.
///
/// Deliberately a substitution rather than a reformat. NumberFormat renders the
/// exact binary value, so raising its three-digit fraction cap far enough to
/// stop it rounding makes it emit noise instead: 12.05 becomes
/// "12.050000000000001". Taking the digits from `toString`/`toStringAsFixed`
/// and localising only the separators keeps the value the caller chose.
///
/// Only the FIRST '.' is replaced, and no grouping separator is inserted, so
/// [text] must be a bare number that Dart produced. Text that already carries
/// grouping must not come through here.
String localiseNumberSeparators(String text) {
  final symbols = localeNumberFormat().symbols;
  return text
      .replaceFirst('.', symbols.DECIMAL_SEP)
      .replaceFirst('-', symbols.MINUS_SIGN);
}

/// [value] as locale-aware text at whatever precision the value itself carries.
///
/// The shared body of `formatDecimalForInput` and `formatDecimalForDisplay`,
/// which differ only in [stripTrailingZero]. That strip happens here rather
/// than in either caller because it matches on the ASCII '.' that
/// [double.toString] emits; once the text has been localised it carries the
/// locale's separator instead, and under de the '.' it would then match is the
/// grouping separator.
String localiseDoubleText(double value, {required bool stripTrailingZero}) {
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
  return localiseNumberSeparators(text);
}
