import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

/// Gives the Material date pickers a compact (numeric) date format of our
/// choosing without touching anything else about them.
///
/// The obvious lever, `showDatePicker`'s `locale` argument, is the wrong one:
/// Flutter implements it as a whole-tree `Localizations.override`, so
/// borrowing `de` for its `dd.MM.yyyy` input format translated the dialog
/// title, buttons, and month names into German along with it (#1510).
///
/// [CalendarDelegate] is the narrow hook. The pickers route compact-date
/// formatting, parsing, and the field hint through it, so overriding those
/// three methods leaves every string in the app's own language.
class CompactDateCalendarDelegate extends GregorianCalendarDelegate {
  /// [pattern] is an `intl` date pattern such as `dd.MM.yyyy` describing how
  /// the diver wants to type and read dates.
  ///
  /// [locale] is the app's locale, not one borrowed for the pattern's sake. It
  /// never decides field order, only digit shape, and then only for the
  /// locales `intl` substitutes digits for: Persian and Bengali render
  /// `۳۱.۰۱.۲۰۲۶`, while Arabic and German both render `31.01.2026`. No locale
  /// Submersion ships today substitutes, so this is correctness by
  /// construction rather than a behavior anyone can see yet.
  CompactDateCalendarDelegate({required String pattern, required Locale locale})
    : _format = _dateFormat(pattern, locale),
      _helpText = pattern.toLowerCase();

  final intl.DateFormat _format;
  final String _helpText;

  @override
  String formatCompactDate(
    DateTime date,
    MaterialLocalizations localizations,
  ) => _format.format(date);

  @override
  DateTime? parseCompactDate(
    String? inputString,
    MaterialLocalizations localizations,
  ) {
    if (inputString == null) return null;
    try {
      return _format.parseStrict(inputString);
    } on FormatException {
      return null;
    }
  }

  /// The pattern itself, lowercased (`dd.mm.yyyy`), rather than the ambient
  /// locale's wording. It has to describe the order this field actually
  /// parses, and it matches how Manage > Units names the same preference.
  @override
  String dateHelpText(MaterialLocalizations localizations) => _helpText;

  /// Falls back the way `GlobalMaterialLocalizations` does when `intl` has no
  /// data for the exact locale: full name, then language, then intl's default.
  static intl.DateFormat _dateFormat(String pattern, Locale locale) {
    final localeName = intl.Intl.canonicalizedLocale(locale.toString());
    if (intl.DateFormat.localeExists(localeName)) {
      return intl.DateFormat(pattern, localeName);
    }
    final language = localeName.split('_').first;
    if (intl.DateFormat.localeExists(language)) {
      return intl.DateFormat(pattern, language);
    }
    return intl.DateFormat(pattern);
  }
}
