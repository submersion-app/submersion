import 'package:intl/intl.dart';

import 'package:submersion/features/trips/domain/services/trip_day_notes.dart';

/// The card a trip page opened unlocked opens at (#2880, issue #4527),
/// named in the URL's `section` query parameter.
enum TripEditSection {
  planning,

  /// The Notes field, at a day's note when the URL names one (#4625).
  notes;

  /// The section a `section` query parameter names; null when there is none
  /// or the name is unknown.
  static TripEditSection? fromQuery(String? name) =>
      name == null ? null : values.asNameMap()[name];
}

/// The query keys naming the day a note is opened at (#4625).
const _noteDateKey = 'noteDate';
const _noteDayKey = 'noteDay';

final RegExp _isoDate = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
final RegExp _dayNumber = RegExp(r'^\d{1,4}$');

/// [day] as edit-route query parameters.
Map<String, String> tripNoteDayQuery(TripNoteDay day) => {
  _noteDateKey: _queryDate.format(day.date),
  _noteDayKey: '${day.dayNumber}',
};

/// The query's date, in the shape [_isoDate] reads back.
final DateFormat _queryDate = DateFormat('yyyy-MM-dd');

/// The day a note is opened at, from [query]; null when either half is
/// missing or malformed, including a date that does not exist (DateTime
/// would roll 2026-02-31 over to 3 March) and a day number below 1.
TripNoteDay? tripNoteDayFromQuery(Map<String, String> query) {
  final match = _isoDate.firstMatch(query[_noteDateKey] ?? '');
  final number = _dayNumber.firstMatch(query[_noteDayKey] ?? '');
  if (match == null || number == null) return null;
  final year = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final day = int.parse(match[3]!);
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    return null;
  }
  final dayNumber = int.parse(number[0]!);
  if (dayNumber < 1) return null;
  return TripNoteDay(date: date, dayNumber: dayNumber);
}
