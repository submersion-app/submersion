import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/marine_life/data/repositories/species_map_repository.dart';
import 'package:submersion/features/marine_life/data/services/gbif_species_map_service.dart';
import 'package:submersion/features/marine_life/domain/entities/species_map_pins.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_map_prefs_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';

final speciesMapRepositoryProvider = Provider<SpeciesMapRepository>(
  (ref) => SpeciesMapRepository(),
);

final gbifSpeciesMapServiceProvider = Provider<GbifSpeciesMapService>(
  (ref) => GbifSpeciesMapService(),
);

/// The ticks every species map read shares: a sighting added or removed, a
/// dive's site, diver or date edited (or the dive deleted), and a site moved
/// or renamed.
void _invalidateOnPlacedSightingChanges(Ref ref) {
  ref.invalidateSelfWhen(
    ref.watch(speciesRepositoryProvider).watchSightingChanges(),
  );
  ref.invalidateSelfWhen(ref.watch(diveRepositoryProvider).watchDivesChanges());
  ref.invalidateSelfWhen(ref.watch(siteRepositoryProvider).watchSitesChanges());
}

/// The places view: every site where the current diver logged a species.
final speciesMapSitePinsProvider = FutureProvider<List<SiteSpeciesPin>>((
  ref,
) async {
  final repository = ref.watch(speciesMapRepositoryProvider);
  final diverId = ref.watch(currentDiverIdProvider);
  _invalidateOnPlacedSightingChanges(ref);
  return repository.getSitePins(diverId: diverId);
});

/// One species' map: where the current diver logged it, and where it is
/// expected under the chosen [ExpectedSiteScope].
final speciesMapSpeciesPinsProvider =
    FutureProvider.family<List<SpeciesSitePin>, String>((ref, speciesId) async {
      final repository = ref.watch(speciesMapRepositoryProvider);
      final diverId = ref.watch(currentDiverIdProvider);
      final scope = ref.watch(speciesMapExpectedScopeProvider);
      _invalidateOnPlacedSightingChanges(ref);
      ref.invalidateSelfWhen(
        ref.watch(speciesRepositoryProvider).watchSiteSpeciesChanges(),
      );
      return repository.getPinsForSpecies(
        speciesId,
        diverId: diverId,
        scope: scope,
      );
    });

/// Sightings that cannot be drawn (no site, or no usable coordinates), for
/// one species or, with a null id, every species.
final speciesMapUnplacedCountProvider = FutureProvider.family<int, String?>((
  ref,
  speciesId,
) async {
  final repository = ref.watch(speciesMapRepositoryProvider);
  final diverId = ref.watch(currentDiverIdProvider);
  _invalidateOnPlacedSightingChanges(ref);
  return repository.countUnplacedSightings(
    speciesId: speciesId,
    diverId: diverId,
  );
});

/// The species the current diver logged at one site, most seen first.
final speciesMapLoggedAtSiteProvider =
    FutureProvider.family<List<LoggedSpeciesAtSite>, String>((
      ref,
      siteId,
    ) async {
      final repository = ref.watch(speciesMapRepositoryProvider);
      final diverId = ref.watch(currentDiverIdProvider);
      _invalidateOnPlacedSightingChanges(ref);
      return repository.getLoggedSpeciesAtSite(siteId, diverId: diverId);
    });

/// A species' GBIF taxon key for the public layer, or null when there is
/// none to draw. Read only while the public layer is on.
// no-tick: a remote lookup keyed by species id. The species row is watched
// through speciesProvider, so a scientific-name edit re-resolves; the answer
// itself is cached for the session in GbifSpeciesMapService.
final speciesGbifTaxonKeyProvider = FutureProvider.autoDispose
    .family<int?, String>((ref, speciesId) async {
      final species = await ref.watch(speciesProvider(speciesId).future);
      if (species == null) return null;
      return ref
          .watch(gbifSpeciesMapServiceProvider)
          .resolveTaxonKey(
            speciesId: speciesId,
            scientificName: species.scientificName,
          );
    });
