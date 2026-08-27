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
  }) : _date = DateFormat(dateFormat.pattern),
       _time = DateFormat(timeFormat.pattern);

  final DateFormat _date;
  final DateFormat _time;

  /// Date alone, for example "15/01/2026".
  String date(DateTime value) => _date.format(value);

  /// Time alone, for example "2:30 PM".
  String time(DateTime value) => _time.format(value);

  /// Date and time, space separated so it still fits a table cell.
  String dateTime(DateTime value) => '${date(value)} ${time(value)}';
}
