import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

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

/// The [MediaSourceResolverRegistry] used by the universal display widget
/// and any other consumer that resolves [MediaItem]s without caring about
/// their source type.
///
/// Phase 1 registers two resolvers: gallery (existing flow) and signature.
/// Later phases register additional resolvers for local files, network
/// URLs, manifest entries, and service connectors.
final mediaSourceResolverRegistryProvider =
    Provider<MediaSourceResolverRegistry>((ref) {
      return MediaSourceResolverRegistry({
        MediaSourceType.platformGallery: ref.watch(
          platformGalleryResolverProvider,
        ),
        MediaSourceType.signature: ref.watch(signatureResolverProvider),
      });
    });

/// Whether to show the placeholder Files / URL tabs in the picker. Off by
/// default; enabled via Settings → Data → Media Sources → Diagnostics
/// (Task 29 wires the toggle).
final mediaPickerHiddenTabsProvider = StateProvider<bool>((ref) => false);
