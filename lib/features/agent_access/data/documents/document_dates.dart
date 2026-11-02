/// The three ways a document writes a date. A key's name says which one it
/// used, and the tool descriptions tell the agent so ([kDocumentDateRule]).
library;

/// The rule every tool that emits dates states to the agent.
const kDocumentDateRule =
    'Dates: date_time and keys ending in _time are the local wall clock of '
    'the dive or event, as ISO 8601 with a nominal Z suffix; they are not UTC '
    'instants, so do not shift them to another time zone. Keys ending in '
    '_date are calendar dates (2025-03-14). Keys ending in _at are true UTC '
    'instants.';

/// A dive clock value: wall-clock time flagged UTC. Printed as held, without
/// `toLocal()`, so the `Z` it carries is nominal.
String wallClock(DateTime value) => value.toIso8601String();

/// [wallClock] for an optional value.
String? wallClockOrNull(DateTime? value) => value?.toIso8601String();

/// A calendar date. Read from the value as held and never through `toUtc()`,
/// because most of these are stored as local midnight and a zone shift would
/// move them to the day before.
String? calendarDate(DateTime? value) {
  if (value == null) return null;
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

/// A true moment in time, as UTC.
String? instant(DateTime? value) => value?.toUtc().toIso8601String();
