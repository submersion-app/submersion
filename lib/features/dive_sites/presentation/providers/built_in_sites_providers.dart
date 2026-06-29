import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/data/services/dive_site_api_service.dart';
import 'package:submersion/features/dive_sites/domain/services/built_in_site_dedup.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';

/// All built-in (bundled) dive sites with coordinates.
/// Static for the app lifetime; loaded once via the service cache.
final builtInSitesProvider = FutureProvider<List<ExternalDiveSite>>((
  ref,
) async {
  final service = ref.watch(diveSiteApiServiceProvider);
  return service.allSitesWithCoordinates();
});

/// Whether built-in site markers are shown on the Sites map.
/// In-memory only (matches the heat-map toggle convention); resets each launch.
final showBuiltInSitesProvider = StateProvider<bool>((ref) => false);

/// Built-in sites with the user's already-owned sites deduped out.
/// Recomputes when either the built-in list or the user's sites change.
final visibleBuiltInSitesProvider = FutureProvider<List<ExternalDiveSite>>((
  ref,
) async {
  // Start both queries before awaiting so they run in parallel, reducing
  // toggle-on latency when either touches disk/DB.
  final builtInFuture = ref.watch(builtInSitesProvider.future);
  final userSitesFuture = ref.watch(sitesWithCountsProvider.future);
  final builtIn = await builtInFuture;
  final userSites = await userSitesFuture;
  return visibleBuiltInSites(builtIn, userSites.map((s) => s.site).toList());
});
