import 'package:intl/intl.dart';

import 'package:submersion/core/constants/units.dart';

/// Month names in a My units file are always English, so a file written on
/// a French device parses on a German one.
const csvDateLocale = 'en_US';

const _isoDatePattern = 'yyyy-MM-dd';
const _isoTimePattern = 'HH:mm';

/// The date format a header suffix names (`DD/MM/YYYY`), or null for no or
/// an unknown suffix. Suffixes are `DateFormatPreference.displayName`.
DateFormatPreference? dateFormatForSuffix(String? suffix) {
  for (final format in DateFormatPreference.values) {
    if (format.displayName == suffix?.trim()) return format;
  }
  return null;
}

/// The time format a header suffix names (`12-hour`), or null.
TimeFormat? timeFormatForSuffix(String? suffix) {
  for (final format in TimeFormat.values) {
    if (format.displayName == suffix?.trim()) return format;
  }
  return null;
}

String formatCsvDate(DateTime date, DateFormatPreference format) =>
    DateFormat(format.pattern, csvDateLocale).format(date);

String formatCsvTime(DateTime time, TimeFormat format) =>
    DateFormat(format.pattern, csvDateLocale).format(time);

/// Formats tried when a cell does not match the format its header names.
///
/// A spreadsheet redisplays a date column in its own format when the file is
/// saved, so the `MMM D, YYYY` column Submersion wrote comes back as
/// `29-Aug-26` and every row of the file reads as undated (#2152).
///
/// Every pattern here spells the month, so none of them can read a day as a
/// month: which of `03` and `04` is the day in `03/04/1991` is still decided
/// by the header alone. `yy` accepts a four-digit year too, and reads a
/// two-digit one into the century around today, so `9-Sep-07` is 2007 rather
/// than 1907.
const _monthNamePatterns = [
  'd-MMM-yy',
  'd MMM yy',
  'MMM d, yy',
  'd MMMM yy',
  'MMMM d, yy',
];

/// An ISO date whose year really is four digits. intl does not hold a field
/// to its pattern's width, so `yyyy-MM-dd` reads `29-08-26` as the year 29;
/// the width is checked here rather than trusted to the pattern.
final _isoDate = RegExp(r'^\d{4}-\d{1,2}-\d{1,2}$');

/// Parses a date cell written with [format] (ISO when null) into a UTC
/// midnight, or null when the text matches neither [format] nor any of the
/// spreadsheet spellings a saved file comes back in.
DateTime? parseCsvDate(String text, DateFormatPreference? format) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  final declared = format?.pattern ?? _isoDatePattern;
  final patterns = <String>{
    // The header's own format first, so a file that was never edited reads
    // exactly as it always did.
    if (declared != _isoDatePattern) declared,
    if (_isoDate.hasMatch(trimmed)) _isoDatePattern,
    ..._monthNamePatterns,
  };
  for (final pattern in patterns) {
    if (_parseStrict(pattern, trimmed) case final parsed?) {
      return DateTime.utc(parsed.year, parsed.month, parsed.day);
    }
  }
  return null;
}

/// [text] read as [pattern], or null when it does not match. Strict parsing
/// rejects a field that cannot exist, so a pattern never silently rolls an
/// impossible month over into the next year.
DateTime? _parseStrict(String pattern, String text) {
  try {
    return DateFormat(pattern, csvDateLocale).parseStrict(text);
  } on FormatException {
    return null;
  }
}

/// Parses a time cell written with [format] (24-hour when null).
({int hour, int minute})? parseCsvTime(String text, TimeFormat? format) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  try {
    final parsed = DateFormat(
      format?.pattern ?? _isoTimePattern,
      csvDateLocale,
    ).parseStrict(trimmed);
    return (hour: parsed.hour, minute: parsed.minute);
  } on FormatException {
    return null;
  }
}
