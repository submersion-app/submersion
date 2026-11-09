import 'package:http/http.dart' as http;

import 'package:submersion/core/network/platform_http_client.dart';
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

final gbifSpeciesMapServiceProvider = Provider<GbifSpeciesMapService>((ref) {
  final service = GbifSpeciesMapService();
  ref.onDispose(service.close);
  return service;
});

/// The one HTTP client the public layer's occurrence tiles go through.
///
/// A tile provider left to create its own client closes it only when its
/// tile layer unmounts, so every rebuild that hands the layer a new provider
/// would leave the previous client open. Sharing this one leaves nothing to
/// close but it, and it carries the app's connect timeout.
final gbifTileHttpClientProvider = Provider<http.Client>((ref) {
  final client = createPlatformHttpClient();
  ref.onDispose(client.close);
  return client;
});

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
///
/// Like every read below, dropped once nothing watches it: kept alive after
/// the map closes, it would re-query the whole logbook on each sighting,
/// dive and site change.
final speciesMapSitePinsProvider =
    FutureProvider.autoDispose<List<SiteSpeciesPin>>((ref) async {
      final repository = ref.watch(speciesMapRepositoryProvider);
      final diverId = ref.watch(currentDiverIdProvider);
      _invalidateOnPlacedSightingChanges(ref);
      return repository.getSitePins(diverId: diverId);
    });

/// One species' map: where the current diver logged it, and where it is
/// expected under the chosen [ExpectedSiteScope]. Every species page the
/// diver opens watches one, which is why these are dropped too.
final speciesMapSpeciesPinsProvider = FutureProvider.autoDispose
    .family<List<SpeciesSitePin>, String>((ref, speciesId) async {
      final repository = ref.watch(speciesMapRepositoryProvider);
      final diverId = ref.watch(currentDiverIdProvider);
      final scope = ref.watch(speciesMapExpectedScopeProvider);
      _invalidateOnPlacedSightingChanges(ref);
      ref.invalidateSelfWhen(
        ref.watch(speciesRepositoryProvider).watchSiteSpeciesChanges(),
      );
      if (scope == ExpectedSiteScope.allVisible) {
        ref.invalidateSelfWhen(repository.watchLibraryMembershipChanges());
      }
      return repository.getPinsForSpecies(
        speciesId,
        diverId: diverId,
        scope: scope,
      );
    });

/// Sightings that cannot be drawn (no site, or no usable coordinates), for
/// one species or, with a null id, every species.
final speciesMapUnplacedCountProvider = FutureProvider.autoDispose
    .family<int, String?>((ref, speciesId) async {
      final repository = ref.watch(speciesMapRepositoryProvider);
      final diverId = ref.watch(currentDiverIdProvider);
      _invalidateOnPlacedSightingChanges(ref);
      return repository.countUnplacedSightings(
        speciesId: speciesId,
        diverId: diverId,
      );
    });

/// The species the current diver logged at one site, most seen first.
final speciesMapLoggedAtSiteProvider = FutureProvider.autoDispose
    .family<List<LoggedSpeciesAtSite>, String>((ref, siteId) async {
      final repository = ref.watch(speciesMapRepositoryProvider);
      final diverId = ref.watch(currentDiverIdProvider);
      _invalidateOnPlacedSightingChanges(ref);
      return repository.getLoggedSpeciesAtSite(siteId, diverId: diverId);
    });

/// A species' GBIF taxon key for the public layer, or null when there is
/// none to draw. Read only while the public layer is on. Errors (as
/// [GbifUnavailableException]) when GBIF cannot be reached.
// no-tick: a remote lookup keyed by species id. The species row is watched
// through speciesProvider, so a scientific-name edit re-resolves, and the
// service caches name matches by name, so the edited name is asked afresh.
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

/// Set when a public-layer tile for a species fails to load (offline, rate
/// limited), so the map can say the records did not load rather than show
/// nothing. Reset when the map closes.
final speciesMapPublicTilesFailedProvider = StateProvider.autoDispose
    .family<bool, String>((ref, speciesId) => false);
