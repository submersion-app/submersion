import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/services/imported_dive_trip.dart';

/// Pure. The name of the trip each reviewed dive will be saved in (issue
/// #3022), keyed by row index in [dives]; a row with no entry joins none.
///
/// It predicts what the save does, by the rule the importers share
/// ([tripForImportedDive]), so the review never names a trip the dive does
/// not land in:
///
/// - Only a row saved as a new dive is named: selected, and either not a
///   duplicate with no action yet, or marked import as new. A dive merged
///   into, replacing or filling an existing one keeps that dive's trip.
/// - A file trip row is imported when selected and not skipped, merged or
///   replaced (as `UniversalAdapter._resolveSelections` reads it); a merged
///   one links its dives to the matched existing trip, as the importer's
///   pre-resolved trip ids do.
/// - A dive in an imported or linked file trip joins it. Otherwise, by
///   date, among [existingTripsFor] that dive's owner plus the file trips
///   being imported, since those exist by the time dives are saved.
///
/// [now] dates an imported file trip that has no dates, as the importer
/// does.
Map<int, String> reviewTripNames({
  required EntityGroup dives,
  EntityGroup? trips,
  required Set<int> diveSelections,
  required Map<int, DuplicateAction> diveActions,
  Set<int> tripSelections = const {},
  Map<int, DuplicateAction> tripActions = const {},
  required List<Trip> Function(EntityItem dive) existingTripsFor,
  required DateTime now,
}) {
  final importedFileTrips = <Trip>[];
  final ownTripByRef = <String, Trip? Function(EntityItem dive)>{};
  final tripItems = trips?.items ?? const <EntityItem>[];
  for (var j = 0; j < tripItems.length; j++) {
    final item = tripItems[j];
    final action = tripActions[j];
    final ref = item.tripRef;
    if (action == DuplicateAction.consolidate) {
      final match = trips?.entityMatches?[j];
      if (ref != null && match != null) {
        ownTripByRef[ref] = (dive) =>
            existingTripsFor(
              dive,
            ).where((t) => t.id == match.existingId).firstOrNull ??
            _namedTrip(match.existingId, match.existingName, now);
      }
      continue;
    }
    final imported =
        tripSelections.contains(j) &&
        action != DuplicateAction.skip &&
        action != DuplicateAction.replaceSource;
    if (!imported) continue;
    final trip = _namedTrip(
      'import-trip-$j',
      item.title,
      now,
      dates: item.tripDates,
    );
    importedFileTrips.add(trip);
    if (ref != null) ownTripByRef[ref] = (_) => trip;
  }

  final names = <int, String>{};
  for (var i = 0; i < dives.items.length; i++) {
    if (!_savedAsNew(i, dives, diveSelections, diveActions)) continue;
    final dive = dives.items[i];
    final ref = dive.tripRef;
    final trip = tripForImportedDive(
      ownTrip: ref == null ? null : ownTripByRef[ref]?.call(dive),
      hasTripRef: ref != null,
      sourceHasTrips: dive.sourceHasTrips,
      diveDateTime: dive.diveData?.startTime,
      trips: [...existingTripsFor(dive), ...importedFileTrips],
    );
    if (trip != null) names[i] = trip.name;
  }
  return names;
}

bool _savedAsNew(
  int index,
  EntityGroup dives,
  Set<int> selections,
  Map<int, DuplicateAction> actions,
) {
  if (!selections.contains(index)) return false;
  final action = actions[index];
  if (action == null) return !dives.duplicateIndices.contains(index);
  return action == DuplicateAction.importAsNew;
}

Trip _namedTrip(
  String id,
  String name,
  DateTime now, {
  ({DateTime start, DateTime end})? dates,
}) => Trip(
  id: id,
  name: name,
  startDate: dates?.start ?? now,
  endDate: dates?.end ?? now,
  createdAt: now,
  updatedAt: now,
);
