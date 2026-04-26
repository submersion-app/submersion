import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:submersion/features/media/data/resolvers/local_file_resolver.dart';
import 'package:submersion/features/media/data/resolvers/platform_gallery_resolver.dart';
import 'package:submersion/features/media/data/resolvers/signature_resolver.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/resolved_asset_providers.dart';

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

/// Phase 1 stub [LocalFileResolver].
///
/// Registered so v72-migrated rows with `source_type = 'localFile'` resolve
/// to a real file on desktop hosts (where the backfilled `local_path` is a
/// valid filesystem path) and to [UnavailableData] on iOS / Android (where
/// Phase 2's bookmark-aware resolver will replace this stub).
final localFileResolverProvider = Provider<LocalFileResolver>(
  (ref) => LocalFileResolver(),
);

/// The [MediaSourceResolverRegistry] used by the universal display widget
/// and any other consumer that resolves [MediaItem]s without caring about
/// their source type.
///
/// Phase 1 registers three resolvers: gallery (existing flow), signature,
/// and a stub local-file resolver covering rows the v72 migration backfills
/// to `MediaSourceType.localFile`. Later phases register additional
/// resolvers for network URLs, manifest entries, and service connectors.
final mediaSourceResolverRegistryProvider =
    Provider<MediaSourceResolverRegistry>((ref) {
      return MediaSourceResolverRegistry({
        MediaSourceType.platformGallery: ref.watch(
          platformGalleryResolverProvider,
        ),
        MediaSourceType.signature: ref.watch(signatureResolverProvider),
        MediaSourceType.localFile: ref.watch(localFileResolverProvider),
      });
    });

/// Whether to show the placeholder Files / URL tabs in the picker. Off by
/// default; enabled via Settings → Data → Media Sources → Diagnostics
/// (Task 29 wires the toggle).
final mediaPickerHiddenTabsProvider = StateProvider<bool>((ref) => false);
