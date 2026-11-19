import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/services/review_trip_names.dart';
import 'package:submersion/features/import_wizard/presentation/providers/import_wizard_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

/// The trips a profile can see, which a new imported dive filed under it may
/// join (issue #3022): [diverId], or the active diver for null or empty, as
/// the importers read them.
final importOwnerTripsProvider = FutureProvider.autoDispose
    .family<List<Trip>, String?>((ref, diverId) async {
      final owner = diverId == null || diverId.isEmpty
          ? await ref.watch(validatedCurrentDiverIdProvider.future)
          : diverId;
      return ref.watch(tripRepositoryProvider).getAllTrips(diverId: owner);
    });

/// The prefix of an [ImportTarget.key] naming an existing profile.
const _diverTargetPrefix = 'diver:';

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
    if (target.isNew || !target.key.startsWith(_diverTargetPrefix)) {
      return (false, null);
    }
    return (true, target.key.substring(_diverTargetPrefix.length));
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
