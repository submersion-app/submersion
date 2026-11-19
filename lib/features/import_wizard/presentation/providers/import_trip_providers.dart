import 'package:collection/collection.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_match_review_notifier.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
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
///
/// The wizard overrides [importWizardNotifierProvider] in its own scope, so
/// this lists it as a dependency to be scoped with it; otherwise it would
/// read the root's, which throws.
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

  final owners = [for (final dive in dives.items) ownerOf(dive)];
  // Each profile once: a row-by-row watch would repeat it for every dive.
  final tripsByOwner = {
    for (final (reads, owner) in owners.toSet())
      if (reads) owner: ref.watch(importOwnerTripsProvider(owner)).value,
  };

  // A merge passes the dive's trip to its match only when that has none.
  final diveActions =
      state.duplicateActions[ImportEntityType.dives] ?? const {};
  final mergeTargets = {
    for (final entry in diveActions.entries)
      if (entry.value == DuplicateAction.consolidate)
        entry.key: ?dives.matchResults?[entry.key]?.diveId,
  };
  final tripless = mergeTargets.isEmpty
      ? const <String>{}
      : ref
                .watch(
                  importMergeTargetsWithoutTripProvider(
                    ImportedDiveIds(mergeTargets.values.toSet().sorted()),
                  ),
                )
                .value ??
            const <String>{};

  final names = reviewTripNames(
    dives: dives,
    trips: bundle.groups[ImportEntityType.trips],
    diveSelections: state.selections[ImportEntityType.dives] ?? const {},
    diveActions: diveActions,
    tripSelections: state.selections[ImportEntityType.trips] ?? const {},
    tripActions: state.duplicateActions[ImportEntityType.trips] ?? const {},
    mergesIntoTripless: {
      for (final entry in mergeTargets.entries)
        if (tripless.contains(entry.value)) entry.key,
    },
    existingTripsFor: (dive) => switch (ownerOf(dive)) {
      (true, final owner) => tripsByOwner[owner] ?? const [],
      _ => const [],
    },
    now: DateTime.now(),
  );
  // While a profile's trips load, its rows get no name rather than a guess.
  return {
    for (final entry in names.entries)
      if (owners[entry.key] case (
        final reads,
        final owner,
      ) when !reads || tripsByOwner[owner] != null)
        entry.key: entry.value,
  };
}, dependencies: [importWizardNotifierProvider]);

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
      final found = await Future.wait(countByTrip.keys.map(trips.getTripById));
      return [
        for (final trip in found.nonNulls)
          (name: trip.name, count: countByTrip[trip.id]!),
      ].sorted((a, b) {
        final byCount = b.count.compareTo(a.count);
        return byCount != 0 ? byCount : compareTextForSort(a.name, b.name);
      });
    });

/// Of the dives that reviewed rows would merge into, the ids of those in no
/// trip (issue #3022): a merge saves the incoming dive on its own, placed in
/// a trip by date, then copies that trip onto its match only when the match
/// has none, so the review names the trip for those rows alone.
final importMergeTargetsWithoutTripProvider = FutureProvider.autoDispose
    .family<Set<String>, ImportedDiveIds>((ref, arg) async {
      if (arg.ids.isEmpty) return const {};
      final dives = ref.watch(diveRepositoryProvider);
      ref.invalidateSelfWhen(dives.watchDivesChanges());
      return {
        for (final dive in await dives.getDivesByIdsWithoutSamples(arg.ids))
          if (dive.tripId == null) dive.id,
      };
    });
