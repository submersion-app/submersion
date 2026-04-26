import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/data/resolvers/platform_gallery_resolver.dart';
import 'package:submersion/features/media/data/resolvers/signature_resolver.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

/// Singleton [PlatformGalleryResolver].
final platformGalleryResolverProvider = Provider<PlatformGalleryResolver>(
  (ref) => PlatformGalleryResolver(),
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
