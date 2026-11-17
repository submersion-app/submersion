import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/router/section_navigation.dart';
import 'package:submersion/features/trips/domain/services/trip_day_notes.dart';

/// A section of the trip edit form that it can open at (#2880), named in
/// the URL's `section` query parameter.
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

/// Opens trip [tripId]'s edit form, at [section] when one is given, or at
/// the note of [noteDay] (in the notes section) when that is.
///
/// A trip shown [embedded] in the master-detail pane edits in that pane, the
/// way the pane's own edit button does; anywhere else the edit page is pushed.
void openTripEdit(
  BuildContext context,
  String tripId, {
  required bool embedded,
  TripEditSection? section,
  TripNoteDay? noteDay,
}) {
  final opened = noteDay == null ? section : TripEditSection.notes;
  final sectionQuery = {
    if (opened != null) 'section': opened.name,
    if (noteDay != null) ...tripNoteDayQuery(noteDay),
  };
  if (embedded) {
    final path = GoRouterState.of(context).uri.path;
    context.goInPlace(
      Uri(
        path: path,
        queryParameters: {'selected': tripId, 'mode': 'edit', ...sectionQuery},
      ).toString(),
    );
  } else {
    context.push(
      Uri(
        path: '/trips/$tripId/edit',
        // An empty map would leave a bare '?' on the location.
        queryParameters: sectionQuery.isEmpty ? null : sectionQuery,
      ).toString(),
    );
  }
}
