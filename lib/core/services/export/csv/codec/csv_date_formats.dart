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

/// Parses a date cell written with [format] (ISO when null) into a UTC
/// midnight, or null when the text does not match.
DateTime? parseCsvDate(String text, DateFormatPreference? format) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  try {
    final parsed = DateFormat(
      format?.pattern ?? _isoDatePattern,
      csvDateLocale,
    ).parseStrict(trimmed);
    return DateTime.utc(parsed.year, parsed.month, parsed.day);
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
