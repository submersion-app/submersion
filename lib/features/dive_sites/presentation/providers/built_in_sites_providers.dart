import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_bounds.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/services/catalogue_site_visibility.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';

/// The most built-in markers a map holds at once. A view that contains
/// more gets its dive sites first, then the charted wrecks and reefs
/// nearest its middle, and a caption saying to zoom in.
const kBuiltInOverlayMarkerLimit = 1500;

/// Whether built-in site markers are shown on the Sites map.
/// In-memory only (matches the heat-map toggle convention); resets each launch.
final showBuiltInSitesProvider = StateProvider<bool>((ref) => false);

/// What the Sites map shows, as the map last reported it, or null until a
/// map with the overlay on has reported. The catalogue holds tens of
/// thousands of records, so the overlay reads only the ones in view.
final builtInOverlayBoundsProvider = StateProvider<CatalogueBounds?>(
  (ref) => null,
);

/// The built-in catalogue sites in the bounds the map reported.
// no-tick: local cache data with no change tick; read again through
// siteCatalogueRevisionProvider when an import replaces the catalogue.
final _builtInSitesInViewProvider =
    FutureProvider.autoDispose<CatalogueBoundsResult>((ref) async {
      ref.watch(siteCatalogueRevisionProvider);
      final bounds = ref.watch(builtInOverlayBoundsProvider);
      if (bounds == null) {
        return (sites: const <CatalogueSite>[], truncated: false);
      }
      return ref
          .watch(siteCatalogueProvider)
          .inBounds(bounds, limit: kBuiltInOverlayMarkerLimit);
    });

/// Whether the map's view holds more built-in sites than it marks.
// no-tick: derived from _builtInSitesInViewProvider.
final builtInOverlayTruncatedProvider = Provider.autoDispose<bool>(
  (ref) => ref.watch(_builtInSitesInViewProvider).value?.truncated ?? false,
);

/// Built-in sites worth showing beside the diver's own in the map's view:
/// not ones they adopted, and not ones a site they made by hand already
/// sits on. Recomputes when the view, the catalogue or the diver's sites
/// change.
// no-tick: local cache data, as _builtInSitesInViewProvider; the diver's
// sites it is filtered by carry their own tick.
final visibleBuiltInSitesProvider =
    FutureProvider.autoDispose<List<CatalogueSite>>((ref) async {
      // Start both queries before awaiting so they run in parallel, reducing
      // toggle-on latency when either touches disk/DB.
      final inViewFuture = ref.watch(_builtInSitesInViewProvider.future);
      final userSitesFuture = ref.watch(sitesWithCountsProvider.future);
      final inView = await inViewFuture;
      final userSites = await userSitesFuture;
      return offerableCatalogueSites(
        inView.sites,
        userSites.map((s) => s.site).toList(),
        byPosition: true,
      );
    });
