import 'package:intl/intl.dart';

import 'package:submersion/core/constants/units.dart';

/// Renders dates and times inside generated PDFs.
///
/// A PDF export is a document a diver prints or hands to a buddy, so it has to
/// read in the diver's own date and time conventions rather than ISO (#964).
/// Export FILE NAMES are the deliberate exception and stay ISO, so a folder of
/// exports still sorts chronologically.
///
/// Templates and export services receive one of these instead of reaching for
/// [DateFormat] themselves, which is what let the hardcoded `yyyy-MM-dd` /
/// `HH:mm` patterns spread across every template in the first place.
class PdfDateFormatter {
  PdfDateFormatter({
    required DateFormatPreference dateFormat,
    required TimeFormat timeFormat,
  }) : this._(dateFormat.pattern, timeFormat.pattern, null);

  PdfDateFormatter._(this._datePattern, this._timePattern, String? locale)
    : _date = DateFormat(_datePattern, locale),
      _time = DateFormat(_timePattern, locale);

  final String _datePattern;
  final String _timePattern;
  final DateFormat _date;
  final DateFormat _time;

  /// The same patterns, with month names and AM/PM in [languageCode] (#2252).
  ///
  /// Without this a French logbook exported from an English app read
  /// "Aug 17, 2026": [DateFormat] otherwise follows `Intl.defaultLocale`,
  /// which is the app language, not the PDF's. A language whose date
  /// symbols are not loaded keeps this formatter unchanged: an export that
  /// throws would be worse than month names in the app language.
  PdfDateFormatter inLanguage(String languageCode) {
    try {
      final localized = PdfDateFormatter._(
        _datePattern,
        _timePattern,
        languageCode,
      );
      // Formatting once here, inside the try, catches a locale-data failure
      // intl defers to the first format() call, so no page of the export
      // can meet it later.
      localized.dateTime(DateTime(2000, 1, 1, 13));
      return localized;
    } catch (_) {
      // LocaleDataException (symbols not loaded) or ArgumentError (unknown
      // locale); localeExists() reports true for `en` in both cases.
      return this;
    }
  }

  /// Date alone, for example "15/01/2026".
  String date(DateTime value) => _date.format(value);

  /// Time alone, for example "2:30 PM".
  String time(DateTime value) => _time.format(value);

  /// Date and time, space separated so it still fits a table cell.
  String dateTime(DateTime value) => '${date(value)} ${time(value)}';
}
