import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/services/catalogue_site_visibility.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';

/// Every built-in catalogue site that has coordinates, for the map.
// no-tick: local cache data with no change tick; read again through
// siteCatalogueRevisionProvider when an import replaces the catalogue.
final builtInSitesProvider = FutureProvider<List<CatalogueSite>>((ref) {
  ref.watch(siteCatalogueRevisionProvider);
  return ref.watch(siteCatalogueProvider).allWithCoordinates();
});

/// Whether built-in site markers are shown on the Sites map.
/// In-memory only (matches the heat-map toggle convention); resets each launch.
final showBuiltInSitesProvider = StateProvider<bool>((ref) => false);

/// Built-in sites worth showing beside the diver's own: not ones they
/// adopted, and not ones a site they made by hand already sits on.
/// Recomputes when either the catalogue or the diver's sites change.
final visibleBuiltInSitesProvider = FutureProvider<List<CatalogueSite>>((
  ref,
) async {
  // Start both queries before awaiting so they run in parallel, reducing
  // toggle-on latency when either touches disk/DB.
  final builtInFuture = ref.watch(builtInSitesProvider.future);
  final userSitesFuture = ref.watch(sitesWithCountsProvider.future);
  final builtIn = await builtInFuture;
  final userSites = await userSitesFuture;
  return offerableCatalogueSites(
    builtIn,
    userSites.map((s) => s.site).toList(),
    byPosition: true,
  );
});
