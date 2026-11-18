import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/geocoding/sea_area_service.dart';
import 'package:submersion/features/dive_sites/data/catalogue/local_site_catalogue.dart';
import 'package:submersion/features/dive_sites/data/catalogue/site_catalogue_importer.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_withdrawal.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_area_anchor_repository.dart';
import 'package:submersion/features/dive_sites/data/services/catalogue_adoption_service.dart';
import 'package:submersion/features/dive_sites/domain/repositories/site_catalogue.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/weather/presentation/providers/weather_providers.dart';

/// The built-in site catalogue. Tests override this with a fake.
final siteCatalogueProvider = Provider<SiteCatalogue>(
  (ref) => LocalSiteCatalogue(),
);

/// Goes up by one each time the bundled catalogue is imported.
///
/// The catalogue's tables are in the local cache database, which has no
/// change ticks, and they change only when an import replaces them: once
/// per app update. A provider that reads the catalogue watches this so it
/// reads again when the first import of a session lands.
final siteCatalogueRevisionProvider = StateProvider<int>((ref) => 0);

/// The importer, one per app run so overlapping calls share a run.
final siteCatalogueImporterProvider = Provider<SiteCatalogueImporter>(
  (ref) => SiteCatalogueImporter(),
);

/// Whether the bundled catalogue is being imported right now.
///
/// A record the catalogue does not hold while this is true may only not
/// be there yet: a screen that would say "no longer available" waits.
final siteCatalogueImportingProvider = StateProvider<bool>((ref) => false);

/// Imports the bundled catalogue if it changed, then tells its readers.
///
/// Called once after the first frame (see `app.dart`). Startup never waits
/// for it: until it finishes, built-in sites are simply absent.
// no-tick: the value is a function that starts the import, not data.
final siteCatalogueImportProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final importing = ref.read(siteCatalogueImportingProvider.notifier);
    importing.state = true;
    try {
      final outcome = await ref
          .read(siteCatalogueImporterProvider)
          .importIfChanged();
      if (outcome == SiteCatalogueImportOutcome.imported) {
        ref.read(siteCatalogueRevisionProvider.notifier).state++;
      }
    } finally {
      importing.state = false;
    }
  };
});

/// One catalogue record by id, or null when the catalogue no longer holds
/// it (a site linked to a record a later catalogue dropped).
// no-tick: local cache data with no change tick; refetched through
// siteCatalogueRevisionProvider when an import replaces the catalogue.
final catalogueSiteProvider = FutureProvider.family<CatalogueSite?, String>((
  ref,
  id,
) {
  ref.watch(siteCatalogueRevisionProvider);
  return ref.watch(siteCatalogueProvider).byId(id);
});

/// The source a catalogue record names.
// no-tick: local cache data with no change tick, as catalogueSiteProvider.
final catalogueSourceProvider = FutureProvider.family<CatalogueSource?, String>(
  (ref, key) {
    ref.watch(siteCatalogueRevisionProvider);
    return ref.watch(siteCatalogueProvider).source(key);
  },
);

/// Why a catalogue record was withdrawn, or null when it was not.
// no-tick: local cache data with no change tick, as catalogueSiteProvider.
final catalogueWithdrawalProvider =
    FutureProvider.family<CatalogueWithdrawal?, String>((ref, id) {
      ref.watch(siteCatalogueRevisionProvider);
      return ref.watch(siteCatalogueProvider).withdrawal(id);
    });

/// The one path that makes a diver's site from a catalogue record.
// no-tick: a service that writes; it holds no data.
final catalogueAdoptionServiceProvider = Provider<CatalogueAdoptionService>((
  ref,
) {
  return CatalogueAdoptionService(
    siteRepository: ref.watch(siteRepositoryProvider),
    fetchElevation: (point) => ref
        .read(elevationServiceProvider)
        .fetchElevation(latitude: point.latitude, longitude: point.longitude),
    // An adopted site's sea in the diver's place-name language, as the
    // geocoder names it for their other sites.
    loadSeas: SeaAreaService.load,
    placeNameLanguage: () => ref.read(placeNameLanguageProvider),
  );
});

/// Finds a dive's area from the dives logged around it.
// no-tick: a repository; callers ask it once, when the site picker opens.
final siteAreaAnchorRepositoryProvider = Provider<SiteAreaAnchorRepository>(
  (ref) => SiteAreaAnchorRepository(),
);

/// Adopts a catalogue site for the current diver.
///
/// The site picker goes through this, so a widget test can stand in for
/// the database with one override.
// no-tick: the value is a function that writes, not data.
final catalogueSiteAdopterProvider =
    Provider<Future<CatalogueAdoption> Function(CatalogueSite site)>((ref) {
      return (site) =>
          ref.read(siteListNotifierProvider.notifier).adoptCatalogueSite(site);
    });
