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
///
/// Gone with the map (the reporter keeps it alive): the next map starts
/// from nothing, not from the sites of wherever the last one looked.
final builtInOverlayBoundsProvider =
    StateProvider.autoDispose<CatalogueBounds?>((ref) => null);

/// The built-in sites worth marking in the bounds the map reported: not
/// ones the diver adopted, and not ones a site they made by hand already
/// sits on. `truncated` says the view holds more of them than are marked.
///
/// The limit is of markers shown, so it is applied after the diver's own
/// are left out: the catalogue is read again, for more, while records it
/// hid leave room and the view still has some.
// no-tick: local cache data with no change tick; read again through
// siteCatalogueRevisionProvider when an import replaces the catalogue. The
// diver's sites it is filtered by carry their own tick.
final _builtInSitesInViewProvider =
    FutureProvider.autoDispose<CatalogueBoundsResult>((ref) async {
      ref.watch(siteCatalogueRevisionProvider);
      final bounds = ref.watch(builtInOverlayBoundsProvider);
      final catalogue = ref.watch(siteCatalogueProvider);
      final userSitesFuture = ref.watch(sitesWithCountsProvider.future);
      if (bounds == null) {
        return (sites: const <CatalogueSite>[], truncated: false);
      }
      final userSites = (await userSitesFuture).map((s) => s.site).toList();

      var ask = kBuiltInOverlayMarkerLimit;
      while (true) {
        final read = await catalogue.inBounds(bounds, limit: ask);
        final offered = offerableCatalogueSites(
          read.sites,
          userSites,
          byPosition: true,
        );
        final short = kBuiltInOverlayMarkerLimit - offered.length;
        if (short <= 0 || !read.truncated) {
          return (
            sites: offered.take(kBuiltInOverlayMarkerLimit).toList(),
            truncated: read.truncated || short < 0,
          );
        }
        // As many more as were hidden: enough when none of those is.
        ask += short;
      }
    });

/// Whether the map's view holds more built-in sites than it marks.
// no-tick: derived from _builtInSitesInViewProvider.
final builtInOverlayTruncatedProvider = Provider.autoDispose<bool>(
  (ref) => ref.watch(_builtInSitesInViewProvider).value?.truncated ?? false,
);

/// Built-in sites worth showing beside the diver's own in the map's view.
/// Recomputes when the view, the catalogue or the diver's sites change.
// no-tick: derived from _builtInSitesInViewProvider.
final visibleBuiltInSitesProvider =
    FutureProvider.autoDispose<List<CatalogueSite>>(
      (ref) async =>
          (await ref.watch(_builtInSitesInViewProvider.future)).sites,
    );
