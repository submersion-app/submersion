import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/geocoding/sea_area_service.dart';
import 'package:submersion/features/dive_sites/data/services/catalogue_sea_name.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/services/catalogue_nearby.dart';
import 'package:submersion/features/dive_sites/domain/services/catalogue_site_visibility.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// What a built-in record's page needs beyond the record itself.

/// The id of the diver's site that stands for the catalogue record
/// [catalogueId], or null when the record is not theirs.
///
/// The site adopted from the record comes first; failing that, one a merge
/// folded a site adopted from it into. Null while the diver's sites load.
///
/// A record that has an owner never shows its built-in page: the page
/// opens the owner's own page instead, and does so again whenever this
/// changes (the site is added from the page, from another screen, or by a
/// sync).
// no-tick: derived from sitesWithCountsProvider, which carries the tick.
final catalogueOwnerSiteIdProvider = Provider.autoDispose
    .family<String?, String>((ref, catalogueId) {
      final sites = ref.watch(sitesWithCountsProvider).value;
      if (sites == null) return null;
      return catalogueOwnerSiteId(
        sites.map((entry) => entry.site),
        catalogueId,
      );
    });

/// How many records of each kind are read to find a built-in record's
/// neighbours: ten times what its page lists, so the list is still full
/// when the diver already has dozens of the nearest.
const _nearbyReadLimit = kCatalogueNearbyRecordLimit * 10;

/// What lies near the catalogue record [catalogueId]: the diver's own
/// sites and other built-in records. Empty for a record the catalogue
/// does not hold, or one without coordinates.
// no-tick: the catalogue is local cache data with no change tick, read
// again through catalogueSiteProvider when an import replaces it; the
// diver's sites it is compared with carry their own tick.
final catalogueNearbyProvider = FutureProvider.autoDispose
    .family<CatalogueNearby, String>((ref, catalogueId) async {
      final record = await ref.watch(catalogueSiteProvider(catalogueId).future);
      final origin = record?.location;
      if (record == null || origin == null) return CatalogueNearby.empty;
      final catalogue = ref.watch(siteCatalogueProvider);
      final userSites = await ref.watch(sitesWithCountsProvider.future);
      // The nearest of each kind, read apart: the page lists dive sites
      // before charted wrecks and reefs, and off Florida or the Solent a
      // single nearest-first read would be hundreds of wrecks before the
      // first dive site. Each read takes more than the page lists, since
      // the rule then leaves out the diver's own.
      Future<List<CatalogueSite>> nearest(CatalogueKind kind) => catalogue.near(
        origin,
        radiusMeters: kCatalogueNearbyRadiusMeters,
        limit: _nearbyReadLimit,
        kind: kind,
      );
      final (sites, registers) = await (
        nearest(CatalogueKind.site),
        nearest(CatalogueKind.register),
      ).wait;
      return catalogueNearby(
        record: record,
        candidates: [...sites, ...registers],
        userSites: userSites,
      );
    });

/// The sea of the catalogue record [catalogueId] as its page names it: in
/// the diver's place-name language, as the adopted site's would be, else
/// as the catalogue holds it. Null for a record with no sea.
// no-tick: local cache data with no change tick, as catalogueSiteProvider.
final catalogueSeaNameProvider = FutureProvider.autoDispose
    .family<String?, String>((ref, catalogueId) async {
      final record = await ref.watch(catalogueSiteProvider(catalogueId).future);
      if (record == null) return null;
      final language = ref.watch(placeNameLanguageProvider);
      final translated = await catalogueSeaInDiversLanguage(
        record,
        loadSeas: SeaAreaService.load,
        placeNameLanguage: () => language,
      );
      return translated ?? record.bodyOfWater;
    });
