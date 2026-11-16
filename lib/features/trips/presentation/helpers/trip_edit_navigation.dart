import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

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

/// [day] as edit-route query parameters.
Map<String, String> tripNoteDayQuery(TripNoteDay day) {
  final date = day.date;
  String two(int n) => n.toString().padLeft(2, '0');
  return {
    _noteDateKey: '${date.year}-${two(date.month)}-${two(date.day)}',
    _noteDayKey: '${day.dayNumber}',
  };
}

/// The day a note is opened at, from [query]; null when either half is
/// missing or malformed.
TripNoteDay? tripNoteDayFromQuery(Map<String, String> query) {
  final date = _isoDate.firstMatch(query[_noteDateKey] ?? '');
  final number = int.tryParse(query[_noteDayKey] ?? '');
  if (date == null || number == null) return null;
  return TripNoteDay(
    date: DateTime(
      int.parse(date[1]!),
      int.parse(date[2]!),
      int.parse(date[3]!),
    ),
    dayNumber: number,
  );
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
