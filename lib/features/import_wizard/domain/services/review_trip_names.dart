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
/// - Only a row saved as a new dive is named: one marked import as new
///   (selected or not, as `UniversalAdapter._resolveSelections` reads it),
///   or a selected row that is not a duplicate. A dive merged into,
///   replacing or filling an existing one keeps that dive's trip.
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
/// [now] dates a file trip missing a date, as the importer does.
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
  final profiles = <String?, _ProfileTrips>{};
  final tripItems = trips?.items ?? const <EntityItem>[];
  for (var j = 0; j < tripItems.length; j++) {
    final item = tripItems[j];
    final profile = profiles.putIfAbsent(item.target?.key, _ProfileTrips.new);
    profile.hasRows = true;
    final ref = item.tripRef;
    final action = tripActions[j];
    if (action == DuplicateAction.consolidate) {
      final match = trips?.entityMatches?[j];
      if (ref != null && match != null) {
        profile.ownTripByRef[ref] = (dive) =>
            existingTripsFor(
              dive,
            ).where((t) => t.id == match.existingId).firstOrNull ??
            _trip(match.existingId, match.existingName, now: now);
      }
      continue;
    }
    final source = item.sourceTrip;
    final imported =
        source != null &&
        (action == DuplicateAction.importAsNew ||
            (tripSelections.contains(j) &&
                action != DuplicateAction.skip &&
                action != DuplicateAction.replaceSource));
    if (!imported) continue;
    final trip = _trip(
      'import-trip-$j',
      source.name,
      now: now,
      start: source.start,
      end: source.end,
    );
    profile.imported.add(trip);
    if (ref != null) profile.ownTripByRef[ref] = (_) => trip;
  }

  final names = <int, String>{};
  for (var i = 0; i < dives.items.length; i++) {
    if (!_savedAsNew(i, dives, diveSelections, diveActions)) continue;
    final dive = dives.items[i];
    final profile = profiles[dive.target?.key];
    final ref = dive.tripRef;
    final trip = tripForImportedDive(
      ownTrip: ref == null ? null : profile?.ownTripByRef[ref]?.call(dive),
      hasTripRef: ref != null,
      sourceHasTrips: dive.sourceHasTrips ?? (profile?.hasRows ?? false),
      diveDateTime: dive.hasSourceTime ? dive.diveData?.startTime : null,
      trips: [...existingTripsFor(dive), ...?profile?.imported],
    );
    if (trip != null) names[i] = trip.name;
  }
  return names;
}

/// One profile's file trips: whether it has any rows, the ones it imports,
/// and the trip each source ref links its dives to.
class _ProfileTrips {
  bool hasRows = false;
  final List<Trip> imported = [];
  final Map<String, Trip? Function(EntityItem dive)> ownTripByRef = {};
}

bool _savedAsNew(
  int index,
  EntityGroup dives,
  Set<int> selections,
  Map<int, DuplicateAction> actions,
) {
  final action = actions[index];
  if (action == DuplicateAction.importAsNew) return true;
  return action == null &&
      selections.contains(index) &&
      !dives.duplicateIndices.contains(index);
}

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
