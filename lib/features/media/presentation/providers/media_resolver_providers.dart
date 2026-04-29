import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:submersion/features/media/data/resolvers/local_file_resolver.dart';
import 'package:submersion/features/media/data/resolvers/platform_gallery_resolver.dart';
import 'package:submersion/features/media/data/resolvers/signature_resolver.dart';
import 'package:submersion/features/media/data/services/exif_extractor.dart';
import 'package:submersion/features/media/data/services/local_bookmark_storage.dart';
import 'package:submersion/features/media/data/services/local_files_diagnostics_service.dart';
import 'package:submersion/features/media/data/services/local_media_platform.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
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
