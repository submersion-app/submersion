// Adapted from plan `docs/superpowers/plans/2026-04-28-media-source-extension-phase3c.md`
// Task 5. Deviations from the plan code:
//
// - The plan imports `domain/entities/manifest_subscription.dart` and
//   `domain/entities/network_credential_host.dart`. Those files do not
//   exist: `ManifestSubscription` is exported from
//   `data/repositories/manifest_subscription_repository.dart` (already
//   imported), and `NetworkCredentialHost` is the Drift dataclass
//   exported from `core/database/database.dart`. Imports updated
//   accordingly.
// - The plan calls `NetworkCredentialsService.listHosts()` for
//   `savedHostsProvider`. The method on the service is `list()` (Phase 3a
//   Task 6). We call `list()`.
// - The plan calls `ManifestSubscriptionRepository.listAll()` for
//   `manifestSubscriptionsProvider`. The repository (Phase 3b) exposes
//   `listAllActive()` (returns every active subscription regardless of
//   `nextPollAt`). The Settings card surfaces every active subscription
//   the user has saved, so we use `listAllActive()`.
// - `networkCredentialsServiceProvider` and `manifestSubscriptionRepositoryProvider`
//   live in `url_tab_providers.dart` and `media_resolver_providers.dart`
//   respectively (Phase 3a / 3b). We import from those.
// - The plan's import list includes `subscription_poller.dart`, but Task 5
//   does not actually create a `subscriptionPollerProvider` (that lives in
//   `media_resolver_providers.dart` already). Dropped to avoid an unused
//   import.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/manifest_subscription_repository.dart';
import 'package:submersion/features/media/data/services/cached_network_image_diagnostics.dart';
import 'package:submersion/features/media/data/services/host_rate_limiter.dart';
import 'package:submersion/features/media/data/services/network_scan_service.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media/presentation/providers/url_tab_providers.dart';

/// Singleton [HostRateLimiter] used by [NetworkScanService]. Configured for
/// the polite defaults specified in
/// `2026-04-25-media-source-extension-design.md` deliverable 8: max 4
/// concurrent requests per host, min 250 ms gap between same-host requests.
final hostRateLimiterProvider = Provider<HostRateLimiter>(
  (ref) => HostRateLimiter(
    maxConcurrentPerHost: 4,
    minSpacing: const Duration(milliseconds: 250),
  ),
);

/// Singleton [CachedNetworkImageDiagnostics]. Test code overrides this to
/// inject a stub directory + clear callback.
final cachedNetworkImageDiagnosticsProvider =
    Provider<CachedNetworkImageDiagnostics>(
      (ref) => CachedNetworkImageDiagnostics(),
    );

/// Singleton [NetworkScanService] wired to all dependencies.
final networkScanServiceProvider = Provider<NetworkScanService>(
  (ref) => NetworkScanService(
    repository: ref.watch(mediaRepositoryProvider),
    credentials: ref.watch(networkCredentialsServiceProvider),
    subscriptions: ref.watch(manifestSubscriptionRepositoryProvider),
    rateLimiter: ref.watch(hostRateLimiterProvider),
  ),
);

/// Saved per-host credentials displayed in the Saved hosts card.
/// `ref.invalidate` after writes (delete / edit / test) to refresh.
final savedHostsProvider = FutureProvider<List<NetworkCredentialHost>>(
  (ref) => ref.watch(networkCredentialsServiceProvider).list(),
);

/// Manifest subscriptions displayed in the Manifest subscriptions card.
/// Surfaces every active subscription regardless of `nextPollAt`.
final manifestSubscriptionsProvider =
    FutureProvider<List<ManifestSubscription>>(
      (ref) =>
          ref.watch(manifestSubscriptionRepositoryProvider).listAllActive(),
    );

/// Current cache size in bytes. Refresh by invalidating after Clear cache.
final cacheSizeProvider = FutureProvider<int>(
  (ref) => ref.watch(cachedNetworkImageDiagnosticsProvider).cacheSize(),
);
