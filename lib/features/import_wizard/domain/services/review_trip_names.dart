import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/services/imported_dive_trip.dart';
import 'package:submersion/features/trips/domain/services/trip_for_dive_date.dart';

/// Pure. The name of the trip each reviewed dive will be saved in (issue
/// #3022), keyed by row index in [dives]; a row with no entry joins none.
///
/// It predicts what the save does, by the rule the importers share
/// ([tripForImportedDive]), so the review never names a trip the dive does
/// not land in:
///
/// - A row is named when its dive is saved with a trip: one marked import as
///   new (selected or not, as `UniversalAdapter._resolveSelections` reads
///   it), a selected row that is not a duplicate, or a merge into a dive
///   that has no trip ([mergesIntoTripless]): a merge saves the dive on its
///   own first, then copies its trip onto the matched dive when that one has
///   none. Any other merge, a replace or a fill keeps the dive's own trip.
/// - A multi-profile import saves each profile's slice on its own, so a
///   dive sees only the trip rows of its own profile (its target), and its
///   source "has trips" when that profile's rows do, unless a merged batch
///   said so for its own file.
/// - A file trip row is imported when it names a trip the importer creates
///   (see [EntityItem.sourceTrip]) and is selected and not skipped, merged or
///   replaced, or is marked import as new; a merged one links its dives to
///   the matched existing trip, as the importer's pre-resolved trip ids do.
/// - A dive in an imported or linked file trip joins it. Otherwise, by
///   date, among [existingTripsFor] that dive's owner plus its profile's
///   file trips being imported, since those exist when dives are saved. A
///   dive with no time of its own is placed in none.
///
/// [existingTripsFor] must answer the same for every dive of one profile
/// (one target): it is asked once per profile. [now] dates a file trip
/// missing a date, as the importer does.
Map<int, String> reviewTripNames({
  required EntityGroup dives,
  EntityGroup? trips,
  required Set<int> diveSelections,
  required Map<int, DuplicateAction> diveActions,
  Set<int> tripSelections = const {},
  Map<int, DuplicateAction> tripActions = const {},
  Set<int> mergesIntoTripless = const {},
  required List<Trip> Function(EntityItem dive) existingTripsFor,
  required DateTime now,
}) {
  final tripItems = trips?.items ?? const <EntityItem>[];
  final tripRowsByProfile = <String?, List<int>>{
    for (final key in {for (final t in tripItems) t.target?.key})
      key: [
        for (var j = 0; j < tripItems.length; j++)
          if (tripItems[j].target?.key == key) j,
      ],
  };
  // One dive of each profile stands for it when its trips are read.
  final diveOfProfile = {for (final d in dives.items) d.target?.key: d};
  final existingByProfile = {
    for (final entry in diveOfProfile.entries)
      entry.key: existingTripsFor(entry.value),
  };
  final profiles = {
    for (final entry in tripRowsByProfile.entries)
      entry.key: _profileTrips(
        rows: entry.value,
        trips: trips!,
        tripSelections: tripSelections,
        tripActions: tripActions,
        existing: existingByProfile[entry.key] ?? const [],
        now: now,
      ),
  };
  final candidatesByProfile = {
    for (final key in diveOfProfile.keys)
      key: [
        ...existingByProfile[key] ?? const <Trip>[],
        ...?profiles[key]?.imported,
      ],
  };

  return {
    for (var i = 0; i < dives.items.length; i++)
      if (_savedWithTrip(
        i,
        dives,
        diveSelections,
        diveActions,
        mergesIntoTripless,
      ))
        if (_tripOf(dives.items[i], profiles, candidatesByProfile)
            case final trip?)
          i: trip.name,
  };
}

Trip? _tripOf(
  EntityItem dive,
  Map<String?, _ProfileTrips> profiles,
  Map<String?, List<Trip>> candidatesByProfile,
) {
  final key = dive.target?.key;
  final profile = profiles[key];
  final ref = dive.tripRef;
  final ownTrip = ref == null ? null : profile?.ownTripByRef[ref];
  final date = dive.hasSourceTime ? dive.diveData?.startTime : null;
  final candidates = candidatesByProfile[key] ?? const <Trip>[];
  final trip = tripForImportedDive(
    ownTrip: ownTrip,
    hasTripRef: ref != null,
    sourceHasTrips: dive.sourceHasTrips ?? profile != null,
    diveDateTime: date,
    trips: candidates,
  );
  if (trip == null || ownTrip != null || date == null) return trip;
  // Placed by date. Two covering trips starting at the same moment are
  // told apart by id, and the importer gives each file trip a random one,
  // so a tie involving a file trip (with an existing trip or another file
  // trip) cannot be predicted: name none rather than guess. A tie between
  // existing trips is settled by their real ids, as the save settles it.
  final tied = [
    for (final t in candidates)
      if (t.startDate.isAtSameMomentAs(trip.startDate) &&
          tripForDiveDate(date, [t]) != null)
        t,
  ];
  final imported = profile?.imported ?? const <Trip>[];
  final unpredictable = tied.length > 1 && tied.any(imported.contains);
  return unpredictable ? null : trip;
}

/// One profile's file trips: the ones it imports, and the trip each source
/// ref links its dives to. A profile with trip rows has one, imported or not.
class _ProfileTrips {
  const _ProfileTrips({required this.imported, required this.ownTripByRef});

  final List<Trip> imported;
  final Map<String, Trip> ownTripByRef;
}

_ProfileTrips _profileTrips({
  required List<int> rows,
  required EntityGroup trips,
  required Set<int> tripSelections,
  required Map<int, DuplicateAction> tripActions,
  required List<Trip> existing,
  required DateTime now,
}) {
  bool imports(int j) {
    final action = tripActions[j];
    return trips.items[j].sourceTrip != null &&
        (action == DuplicateAction.importAsNew ||
            (tripSelections.contains(j) &&
                action != DuplicateAction.skip &&
                action != DuplicateAction.consolidate &&
                action != DuplicateAction.replaceSource));
  }

  final imported = {
    for (final j in rows)
      if (imports(j))
        j: _trip(
          'import-trip-$j',
          trips.items[j].sourceTrip!.name,
          now: now,
          start: trips.items[j].sourceTrip!.start,
          end: trips.items[j].sourceTrip!.end,
        ),
  };
  // A merged trip links to its match; an imported one to the new trip.
  Trip? linkOf(int j) => switch (tripActions[j]) {
    DuplicateAction.consolidate => switch (trips.entityMatches?[j]) {
      final match? =>
        existing.where((t) => t.id == match.existingId).firstOrNull ??
            _trip(match.existingId, match.existingName, now: now),
      null => null,
    },
    _ => imported[j],
  };

  return _ProfileTrips(
    imported: List.unmodifiable(imported.values),
    ownTripByRef: Map.unmodifiable({
      for (final j in rows) ?trips.items[j].tripRef: ?linkOf(j),
    }),
  );
}

bool _savedWithTrip(
  int index,
  EntityGroup dives,
  Set<int> selections,
  Map<int, DuplicateAction> actions,
  Set<int> mergesIntoTripless,
) => switch (actions[index]) {
  DuplicateAction.importAsNew => true,
  DuplicateAction.consolidate => mergesIntoTripless.contains(index),
  null => selections.contains(index) && !dives.duplicateIndices.contains(index),
  _ => false,
};

/// A trip as the importer saves it and reads it back: a missing date is
/// [now], and dates are read back in local time, whatever zone the source
/// gave them in, so a UTC end instant ends on its local day.
Trip _trip(
  String id,
  String name, {
  required DateTime now,
  DateTime? start,
  DateTime? end,
}) => Trip(
  id: id,
  name: name,
  startDate: _asReadBack(start ?? now),
  endDate: _asReadBack(end ?? now),
  createdAt: now,
  updatedAt: now,
);

DateTime _asReadBack(DateTime date) =>
    DateTime.fromMillisecondsSinceEpoch(date.millisecondsSinceEpoch);
