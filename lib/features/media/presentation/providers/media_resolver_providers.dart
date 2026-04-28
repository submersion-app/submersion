import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:submersion/features/media/data/repositories/manifest_subscription_repository.dart';
import 'package:submersion/features/media/data/resolvers/local_file_resolver.dart';
import 'package:submersion/features/media/data/resolvers/manifest_entry_resolver.dart';
import 'package:submersion/features/media/data/resolvers/platform_gallery_resolver.dart';
import 'package:submersion/features/media/data/resolvers/signature_resolver.dart';
import 'package:submersion/features/media/data/services/exif_extractor.dart';
import 'package:submersion/features/media/data/services/local_bookmark_storage.dart';
import 'package:submersion/features/media/data/services/local_files_diagnostics_service.dart';
import 'package:submersion/features/media/data/services/local_media_platform.dart';
import 'package:submersion/features/media/data/services/manifest_fetch_service.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/data/services/network_credentials_service.dart';
import 'package:submersion/features/media/data/services/subscription_poller.dart';
import 'package:submersion/features/media/data/services/subscription_poller_scheduler.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';
import 'package:submersion/features/media/presentation/providers/url_tab_providers.dart';

/// Singleton [PlatformGalleryResolver].
///
/// Injects [AssetResolutionService] so the resolver uses the 3-step fallback
/// (cache → original ID → metadata search) instead of calling
/// [AssetEntity.fromId] directly. This makes gallery photos visible on synced
/// second devices where the stored [platformAssetId] is device-specific.
final platformGalleryResolverProvider = Provider<PlatformGalleryResolver>(
  (ref) => PlatformGalleryResolver(
    resolutionService: ref.watch(assetResolutionServiceProvider),
  ),
);

/// Singleton [SignatureResolver].
final signatureResolverProvider = Provider<SignatureResolver>(
  (ref) => SignatureResolver(),
);

final localBookmarkStorageProvider = Provider<LocalBookmarkStorage>(
  (ref) => LocalBookmarkStorage(),
);

final localMediaPlatformProvider = Provider<LocalMediaPlatform>(
  (ref) => LocalMediaPlatform(),
);

final exifExtractorProvider = Provider<ExifExtractor>((ref) => ExifExtractor());

/// Singleton [LocalFileResolver] (Phase 2 — multi-platform).
final localFileResolverProvider = Provider<LocalFileResolver>(
  (ref) => LocalFileResolver(
    bookmarkStorage: ref.watch(localBookmarkStorageProvider),
    platform: ref.watch(localMediaPlatformProvider),
    exifExtractor: ref.watch(exifExtractorProvider),
  ),
);

/// Singleton [ManifestEntryResolver] (Phase 3b).
///
/// Manifest-entry items are HTTP(S) URLs that arrived via a feed, so the
/// resolver delegates byte fetch and metadata extraction to the Phase 3a
/// HTTP stack ([NetworkUrlResolver] + [UrlMetadataExtractor]). The
/// providers for those services are co-located with the URL tab in
/// `url_tab_providers.dart`.
final manifestEntryResolverProvider = Provider<ManifestEntryResolver>(
  (ref) => ManifestEntryResolver(
    networkUrlResolver: ref.watch(networkUrlResolverProvider),
    urlMetadataExtractor: ref.watch(urlMetadataExtractorProvider),
  ),
);

/// The [MediaSourceResolverRegistry] used by the universal display widget
/// and any other consumer that resolves [MediaItem]s without caring about
/// their source type.
final mediaSourceResolverRegistryProvider =
    Provider<MediaSourceResolverRegistry>((ref) {
      return MediaSourceResolverRegistry({
        MediaSourceType.platformGallery: ref.watch(
          platformGalleryResolverProvider,
        ),
        MediaSourceType.signature: ref.watch(signatureResolverProvider),
        MediaSourceType.localFile: ref.watch(localFileResolverProvider),
        MediaSourceType.manifestEntry: ref.watch(manifestEntryResolverProvider),
      });
    });

/// Whether to show the placeholder Files / URL tabs in the picker. Off by
/// default; enabled via Settings → Data → Media Sources → Diagnostics
/// (Task 29 wires the toggle).
final mediaPickerHiddenTabsProvider = StateProvider<bool>((ref) => false);

/// Singleton [LocalFilesDiagnosticsService] used by the Settings →
/// Media Sources → Local files subsection.
final localFilesDiagnosticsServiceProvider =
    Provider<LocalFilesDiagnosticsService>(
      (ref) => LocalFilesDiagnosticsService(
        repository: ref.read(mediaRepositoryProvider),
        resolver: ref.read(localFileResolverProvider),
        platform: ref.read(localMediaPlatformProvider),
      ),
    );

/// Cached counts of local-file media items (total / available / unavailable).
/// Invalidate after [LocalFilesDiagnosticsService.reverifyAll] to refresh.
final localFilesDiagnosticsProvider = FutureProvider<LocalFilesDiagnostics>(
  (ref) async => ref.read(localFilesDiagnosticsServiceProvider).diagnose(),
);

/// Number of persistable URI permissions Android currently holds for this
/// app. Returns 0 on every non-Android platform.
final androidUriUsageProvider = FutureProvider<int>(
  (ref) async =>
      ref.read(localFilesDiagnosticsServiceProvider).androidUriUsage(),
);

// ---------------------------------------------------------------------------
// Phase 3b — manifest subscription pipeline
// ---------------------------------------------------------------------------

/// Singleton [ManifestFetchService] for the manifest subscription poller.
///
/// 3a's [NetworkCredentialsService.headersFor] returns
/// `Future<Map<String, String>?>` (nullable map), but 3b's
/// [ManifestCredentialsLookup] is the slightly stricter
/// `Future<Map<String, String>>` (non-nullable). The
/// [_NetworkCredentialsAdapter] below bridges the two with a single
/// `?? const {}` so 3b stays loosely coupled to 3a's exact signatures.
final manifestFetchServiceProvider = Provider<ManifestFetchService>((ref) {
  return ManifestFetchService(
    client: ref.watch(httpClientProvider),
    credentials: _NetworkCredentialsAdapter(
      ref.watch(networkCredentialsServiceProvider),
    ),
  );
});

/// Singleton [ManifestSubscriptionRepository]. Wraps the synced
/// `media_subscriptions` table and the per-device
/// `media_subscription_state` table.
final manifestSubscriptionRepositoryProvider =
    Provider<ManifestSubscriptionRepository>(
      (ref) => ManifestSubscriptionRepository(),
    );

/// Singleton [SubscriptionPoller]. Composes the subscription repository,
/// the media repository, the manifest fetch service, and 3a's network
/// fetch pipeline (which actually inserts the new manifest entries and
/// fills metadata in the background).
final subscriptionPollerProvider = Provider<SubscriptionPoller>((ref) {
  return SubscriptionPoller(
    subscriptions: ref.watch(manifestSubscriptionRepositoryProvider),
    mediaRepo: ref.watch(mediaRepositoryProvider),
    fetchService: ref.watch(manifestFetchServiceProvider),
    pipeline: ref.watch(networkFetchPipelineProvider),
  );
});

/// Singleton [SubscriptionPollerScheduler]. Decides *when*
/// [SubscriptionPoller.pollAllDue] runs (30 s warm-up, periodic cadence,
/// and user-triggered "Poll now"). The scheduler is created lazily on first
/// read; the eventual caller (Settings page in Phase 3c, or the Manifest
/// mode panel in Tasks 13-14) is responsible for invoking
/// `startAfterWarmup()` to begin the recurring cycle.
final subscriptionPollerSchedulerProvider =
    Provider<SubscriptionPollerScheduler>((ref) {
      final scheduler = SubscriptionPollerScheduler(
        poller: ref.watch(subscriptionPollerProvider),
        subscriptions: ref.watch(manifestSubscriptionRepositoryProvider),
      );
      ref.onDispose(scheduler.dispose);
      return scheduler;
    });

/// Adapter that turns 3a's nullable-map `NetworkCredentialsService.headersFor`
/// into 3b's non-nullable `ManifestCredentialsLookup.headersFor`. An empty
/// map (no auth) is the desired fallback for hosts without saved
/// credentials.
class _NetworkCredentialsAdapter implements ManifestCredentialsLookup {
  _NetworkCredentialsAdapter(this._service);

  final NetworkCredentialsService _service;

  @override
  Future<Map<String, String>> headersFor(Uri uri) async {
    return await _service.headersFor(uri) ?? const <String, String>{};
  }
}
