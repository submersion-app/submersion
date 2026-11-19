import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_match_review_notifier.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/services/review_trip_names.dart';
import 'package:submersion/features/import_wizard/presentation/providers/import_wizard_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/universal_import/data/models/diver_target.dart';

/// The trips a profile can see, which a new imported dive filed under it may
/// join (issue #3022): [diverId], or the active diver for null or empty, as
/// the importers read them.
final importOwnerTripsProvider = FutureProvider.autoDispose
    .family<List<Trip>, String?>((ref, diverId) async {
      final trips = ref.watch(tripRepositoryProvider);
      ref.invalidateSelfWhen(trips.watchTripsChanges());
      final owner = diverId == null || diverId.isEmpty
          ? await ref.watch(validatedCurrentDiverIdProvider.future)
          : diverId;
      return trips.getAllTrips(diverId: owner);
    });

/// The trip each reviewed dive will be saved in, keyed by row index of the
/// dives group (issue #3022); see [reviewTripNames]. Follows the review
/// state, so unticking a trip or marking a row skip updates it.
///
/// A row reads the trips of the profile it is filed under: its own target in
/// a multi-profile import (none for a profile the import creates), else the
/// download's chosen profile, else the wizard's diver. While a profile's
/// trips are loading its rows get no name rather than a guess.
final importReviewTripNamesProvider = Provider.autoDispose<Map<int, String>>((
  ref,
) {
  final state = ref.watch(importWizardNotifierProvider);
  final dives = state.bundle?.groups[ImportEntityType.dives];
  if (dives == null || dives.items.isEmpty) return const {};
  final bundle = state.bundle!;
  final wizardDiverId =
      bundle.targetChoice?.chosenDiverId ??
      ref.read(importWizardNotifierProvider.notifier).diverId;

  // (true, id) for a profile whose trips are read; (false, _) for none.
  (bool, String?) ownerOf(EntityItem dive) {
    final target = dive.target;
    if (target == null) return (true, wizardDiverId);
    if (target.isNew) return (false, null);
    final id = DiverTarget.diverIdOf(target.key);
    return id == null ? (false, null) : (true, id);
  }

  final tripsByOwner = <String?, List<Trip>?>{};
  for (final dive in dives.items) {
    final (reads, owner) = ownerOf(dive);
    if (!reads || tripsByOwner.containsKey(owner)) continue;
    tripsByOwner[owner] = ref.watch(importOwnerTripsProvider(owner)).value;
  }

  bool loading(EntityItem dive) {
    final (reads, owner) = ownerOf(dive);
    return reads && tripsByOwner[owner] == null;
  }

  final names = reviewTripNames(
    dives: dives,
    trips: bundle.groups[ImportEntityType.trips],
    diveSelections: state.selections[ImportEntityType.dives] ?? const {},
    diveActions: state.duplicateActions[ImportEntityType.dives] ?? const {},
    tripSelections: state.selections[ImportEntityType.trips] ?? const {},
    tripActions: state.duplicateActions[ImportEntityType.trips] ?? const {},
    existingTripsFor: (dive) {
      final (reads, owner) = ownerOf(dive);
      return reads ? tripsByOwner[owner] ?? const [] : const [];
    },
    now: DateTime.now(),
  );
  return {
    for (final entry in names.entries)
      if (!loading(dives.items[entry.key])) entry.key: entry.value,
  };
});

/// How many of the dives an import saved went into each trip (issue
/// #3022), most dives first, then by name; dives in no trip are not
/// counted. Read from the saved dives rather than the review's prediction,
/// so the summary shows where they actually landed.
final importedDiveTripCountsProvider = FutureProvider.autoDispose
    .family<List<({String name, int count})>, ImportedDiveIds>((
      ref,
      arg,
    ) async {
      if (arg.ids.isEmpty) return const [];
      final dives = ref.watch(diveRepositoryProvider);
      final trips = ref.watch(tripRepositoryProvider);
      ref.invalidateSelfWhen(dives.watchDivesChanges());
      ref.invalidateSelfWhen(trips.watchTripsChanges());

      final countByTrip = <String, int>{};
      for (final dive in await dives.getDivesByIdsWithoutSamples(arg.ids)) {
        if (dive.tripId case final tripId?) {
          countByTrip[tripId] = (countByTrip[tripId] ?? 0) + 1;
        }
      }
      final rows = <({String name, int count})>[
        for (final entry in countByTrip.entries)
          if (await trips.getTripById(entry.key) case final trip?)
            (name: trip.name, count: entry.value),
      ];
      rows.sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        return byCount != 0 ? byCount : a.name.compareTo(b.name);
      });
      return rows;
    });
