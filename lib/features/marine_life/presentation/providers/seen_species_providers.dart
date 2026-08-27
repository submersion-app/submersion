import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/marine_life/data/repositories/seen_species_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/seen_species.dart';
import 'package:submersion/features/marine_life/domain/entities/species_sighting_record.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';

final seenSpeciesRepositoryProvider = Provider<SeenSpeciesRepository>((ref) {
  return SeenSpeciesRepository();
});

/// Every species the current diver has logged, with sighting aggregates.
///
/// Deliberately UNFILTERED by `statisticsFilterProvider`, for the reason
/// written on `speciesStatisticsProvider`: the Species page is a logbook
/// surface with its own search and sort, not a Statistics panel, and it must
/// not silently shrink to whatever filter the Statistics tab last used.
///
/// Three table ticks. `species`: a rename or category edit. `sightings`:
/// add, edit, delete, bulk replace, and the cascade when a dive is deleted
/// (drift_dev propagates cascade foreign keys). `dives`: a dive's date, site
/// or diver edit changes first/last seen and site counts without touching
/// `sightings`.
final seenSpeciesProvider = FutureProvider<List<SeenSpecies>>((ref) async {
  final repository = ref.watch(seenSpeciesRepositoryProvider);
  final speciesRepository = ref.watch(speciesRepositoryProvider);
  final diverId = ref.watch(currentDiverIdProvider);
  ref.invalidateSelfWhen(speciesRepository.watchSpeciesChanges());
  ref.invalidateSelfWhen(speciesRepository.watchSightingChanges());
  ref.invalidateSelfWhen(ref.watch(diveRepositoryProvider).watchDivesChanges());
  return repository.getSeenSpecies(diverId: diverId);
});

/// The dives on which the current diver saw one species, newest first.
///
/// Same scoping and the same three ticks as [seenSpeciesProvider].
final speciesSightingsProvider =
    FutureProvider.family<List<SpeciesSightingRecord>, String>((
      ref,
      speciesId,
    ) async {
      final repository = ref.watch(seenSpeciesRepositoryProvider);
      final speciesRepository = ref.watch(speciesRepositoryProvider);
      final diverId = ref.watch(currentDiverIdProvider);
      ref.invalidateSelfWhen(speciesRepository.watchSpeciesChanges());
      ref.invalidateSelfWhen(speciesRepository.watchSightingChanges());
      ref.invalidateSelfWhen(
        ref.watch(diveRepositoryProvider).watchDivesChanges(),
      );
      return repository.getSightingsForSpecies(speciesId, diverId: diverId);
    });
