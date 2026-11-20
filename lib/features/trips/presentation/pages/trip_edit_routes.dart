import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/trips/domain/services/trip_day_notes.dart';
import 'package:submersion/features/trips/domain/services/trip_draft.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_edit_navigation.dart';
import 'package:submersion/features/trips/presentation/pages/trip_detail_page.dart';
import 'package:submersion/shared/widgets/record_editing/open_new_record.dart';

/// Where the old trip edit address (`/trips/<id>/edit`) goes (issue #4527,
/// phase 3): the trip page opened unlocked, at the same [section] and day's
/// note ([noteDay]) the form would have opened at.
String tripEditLocation(
  String tripId, {
  TripEditSection? section,
  TripNoteDay? noteDay,
}) {
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
/// mode's `editBuilder`: the trip page opened unlocked, at [section] or
/// [noteDay], back to the trip in view mode ([onCancel]) once its sitting
/// ends. [onSaved] is the scaffold's, and unused: a sitting saves in place.
Widget tripEditPane(
  BuildContext context,
  String id,
  void Function(String savedId) onSaved,
  VoidCallback onCancel, {
  VoidCallback? onDeleted,
  TripEditSection? section,
  TripNoteDay? noteDay,
}) => TripDetailPage(
  tripId: id,
  embedded: true,
  openUnlocked: true,
  openSection: section,
  openNoteDay: noteDay,
  onSittingEnded: onCancel,
  // A delete from the pane returns it to the list, as from view mode.
  onDeleted: onDeleted,
);

/// The new-trip address (`/trips/new`, with a [TripDraft] from selected
/// dives or a dive's edit as [extra]; issue #4527, phase 3, plan 11): the
/// trip page opened unlocked on a new trip, which pops the id of the trip
/// it created.
Widget newTripPage(Object? extra) =>
    TripDetailPage.newTrip(draft: extra is TripDraft ? extra : null);

/// The trips list's new-trip pane (`?mode=new`), as the master-detail
/// scaffold's and table mode's `createBuilder`: the trip page on a new
/// trip, whose created id is handed to [onSaved].
Widget newTripPane(
  BuildContext context,
  void Function(String savedId) onSaved,
  VoidCallback onCancel,
) => TripDetailPage.newTrip(
  embedded: true,
  onCreated: onSaved,
  onCreateCancelled: onCancel,
);

/// Opens a new trip from the trips list on a phone or its empty state: the
/// trip opens, locked, once created, as a new site does (plan 11,
/// Question 3).
Future<void> openNewTrip(BuildContext context) => openNewRecord(
  context,
  newLocation: '/trips/new',
  recordLocation: (id) => '/trips/$id',
);
