import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/trips/domain/services/trip_day_notes.dart';
import 'package:submersion/features/trips/domain/services/trip_draft.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_edit_navigation.dart';
import 'package:submersion/features/trips/presentation/pages/trip_detail_page.dart';
import 'package:submersion/features/trips/presentation/pages/trip_edit_page.dart';
import 'package:submersion/shared/widgets/record_editing/open_new_record.dart';
import 'package:submersion/shared/widgets/record_editing/unlock_record_editing_flag.dart';

/// Where the old trip edit address (`/trips/<id>/edit`) goes (issue #4527,
/// phase 3): with [unlockEditing], the trip page opened unlocked, at the
/// same [section] and day's note ([noteDay]) the form would have opened
/// at; null, keeping the edit form, otherwise.
String? tripEditLocation(
  String tripId, {
  TripEditSection? section,
  TripNoteDay? noteDay,
  bool unlockEditing = kUnlockRecordEditing,
}) {
  if (!unlockEditing) return null;
  return Uri(
    path: '/trips/$tripId',
    queryParameters: _editQuery(section, noteDay),
  ).toString();
}

/// The query asking for a trip unlocked at [section] or at [noteDay]'s note.
Map<String, String> _editQuery(
  TripEditSection? section,
  TripNoteDay? noteDay,
) => {
  'mode': 'edit',
  'section': ?(noteDay != null ? TripEditSection.notes : section)?.name,
  if (noteDay != null) ...tripNoteDayQuery(noteDay),
};

/// Where a full trip page reached directly moves to on a wide screen: the
/// list's pane, still asking to open unlocked, at the same card, when it was
/// ([openUnlocked]), so the edit address is not lost in the move.
String tripPaneLocation(
  String tripId, {
  required bool openUnlocked,
  TripEditSection? section,
  TripNoteDay? noteDay,
}) => Uri(
  path: '/trips',
  queryParameters: {
    'selected': tripId,
    if (openUnlocked) ..._editQuery(section, noteDay),
  },
).toString();

/// The edit route's redirect: [tripEditLocation] for its address, keeping
/// its section and day.
String? tripEditRedirect(BuildContext context, GoRouterState state) {
  final query = state.uri.queryParameters;
  return tripEditLocation(
    state.pathParameters['tripId']!,
    section: TripEditSection.fromQuery(query['section']),
    noteDay: tripNoteDayFromQuery(query),
  );
}

/// The trip page for the trip detail route: unlocked, at a section or a
/// day's note, when its address asks (`?mode=edit`).
Widget tripDetailRoutePage(BuildContext context, GoRouterState state) {
  final query = state.uri.queryParameters;
  return TripDetailPage(
    tripId: state.pathParameters['tripId']!,
    openUnlocked: query['mode'] == 'edit',
    openSection: TripEditSection.fromQuery(query['section']),
    openNoteDay: tripNoteDayFromQuery(query),
  );
}

/// The trips list's edit pane, as the master-detail scaffold's and table
/// mode's `editBuilder`: with [unlockEditing], the trip page opened
/// unlocked, at [section] or [noteDay], back to the trip in view mode
/// ([onCancel]) once its sitting ends; else the edit form as before.
Widget tripEditPane(
  BuildContext context,
  String id,
  void Function(String savedId) onSaved,
  VoidCallback onCancel, {
  VoidCallback? onDeleted,
  TripEditSection? section,
  TripNoteDay? noteDay,
  bool unlockEditing = kUnlockRecordEditing,
}) {
  if (unlockEditing) {
    return TripDetailPage(
      tripId: id,
      embedded: true,
      unlockEditing: unlockEditing,
      openUnlocked: true,
      openSection: section,
      openNoteDay: noteDay,
      onSittingEnded: onCancel,
      // A delete from the pane returns it to the list, as from view mode.
      onDeleted: onDeleted,
    );
  }
  return TripEditPage(
    tripId: id,
    embedded: true,
    onSaved: onSaved,
    onCancel: onCancel,
    initialSection: section,
    noteDay: noteDay,
  );
}

/// The new-trip address (`/trips/new`, with a [TripDraft] from selected
/// dives or a dive's edit as [extra]; issue #4527, phase 3, plan 11): with
/// [unlockEditing], the trip page opened unlocked on a new trip, which pops
/// the id of the trip it created; else the form, as before.
Widget newTripPage(Object? extra, {bool unlockEditing = kUnlockRecordEditing}) {
  final draft = extra is TripDraft ? extra : null;
  if (unlockEditing) return TripDetailPage.newTrip(draft: draft);
  return TripEditPage(draft: draft);
}

/// The trips list's new-trip pane (`?mode=new`), as the master-detail
/// scaffold's and table mode's `createBuilder`: with [unlockEditing], the
/// trip page on a new trip, whose created id is handed to [onSaved]; else
/// the form.
Widget newTripPane(
  BuildContext context,
  void Function(String savedId) onSaved,
  VoidCallback onCancel, {
  bool unlockEditing = kUnlockRecordEditing,
}) {
  if (unlockEditing) {
    return TripDetailPage.newTrip(
      embedded: true,
      onCreated: onSaved,
      onCreateCancelled: onCancel,
    );
  }
  return TripEditPage(embedded: true, onSaved: onSaved, onCancel: onCancel);
}

/// Opens a new trip from the trips list on a phone or its empty state:
/// with [unlockEditing], the trip opens, locked, once created, as a new
/// site does (plan 11, Question 3); else the form, as before.
Future<void> openNewTrip(
  BuildContext context, {
  bool unlockEditing = kUnlockRecordEditing,
}) => openNewRecord(
  context,
  newLocation: '/trips/new',
  recordLocation: (id) => '/trips/$id',
  openCreated: unlockEditing,
);
