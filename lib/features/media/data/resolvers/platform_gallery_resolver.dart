import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:photo_manager/photo_manager.dart';

import 'package:submersion/features/media/data/services/asset_resolution_service.dart';
import 'package:submersion/features/media/data/services/gallery_thumbnail_cache.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';

/// Resolves [MediaSourceType.platformGallery] items via [photo_manager].
///
/// Gallery photos are universally addressable on the device that owns the
/// platform library, but on a synced second device the [platformAssetId]
/// stored in the database is device-specific and will not load directly.
/// This resolver delegates to [AssetResolutionService] for a 3-step fallback:
///   1. Check [LocalAssetCacheRepository] for a previously resolved local ID.
///   2. Try [platformAssetId] directly (works on the originating device).
///   3. Search the gallery by filename + timestamp, then timestamp + dimensions.
class PlatformGalleryResolver implements MediaSourceResolver {
  final AssetResolutionService _resolutionService;

  /// Memoizes thumbnail bytes across tile recycling and caps concurrent
  /// PhotoKit traffic. Must be shared process-wide to be worth anything -- a
  /// per-resolver instance would be discarded on every provider rebuild -- so
  /// production injects the singleton from [galleryThumbnailCacheProvider].
  final GalleryThumbnailCache _thumbnailCache;

  PlatformGalleryResolver({
    required AssetResolutionService resolutionService,
    GalleryThumbnailCache? thumbnailCache,
  }) : _resolutionService = resolutionService,
       _thumbnailCache = thumbnailCache ?? GalleryThumbnailCache();

  @override
  MediaSourceType get sourceType => MediaSourceType.platformGallery;

  @override
  bool canResolveOnThisDevice(MediaItem item) => true;

  @override
  Future<MediaSourceData> resolve(MediaItem item) async {
    final assetId = item.platformAssetId;
    if (assetId == null || assetId.isEmpty) {
      return const UnavailableData(kind: UnavailableKind.notFound);
    }
    final resolution = await _resolutionService.resolveAssetId(item);
    // Checked before the id, because accessDenied always carries a null id
    // and collapsing the two would report "your photo is gone" for what is
    // really "let me look at your photos".
    if (resolution.status == ResolutionStatus.accessDenied) {
      return const UnavailableData(kind: UnavailableKind.accessDenied);
    }
    final resolvedId = resolution.localAssetId;
    if (resolvedId == null) {
      return const UnavailableData(kind: UnavailableKind.notFound);
    }
    // photo_manager AssetEntity APIs require a real device gallery; the
    // remaining branches are exercised on iOS/Android hosts only.
    // coverage:ignore-start
    final asset = await AssetEntity.fromId(resolvedId);
    if (asset == null) {
      return const UnavailableData(kind: UnavailableKind.notFound);
    }
    final bytes = await asset.originBytes;
    if (bytes == null) {
      return const UnavailableData(kind: UnavailableKind.notFound);
    }
    return BytesData(bytes: bytes, servedFrom: ServedFrom.platformGallery);
    // coverage:ignore-end
  }

  @override
  Future<MediaSourceData> resolveThumbnail(
    MediaItem item, {
    required Size target,
  }) async {
    final assetId = item.platformAssetId;
    if (assetId == null || assetId.isEmpty) {
      return const UnavailableData(kind: UnavailableKind.notFound);
    }
    final width = target.width.toInt();
    final height = target.height.toInt();
    // Keyed by size as well as item: the grid and the viewer ask for different
    // targets and must not serve each other's bytes.
    final bytes = await _thumbnailCache.getOrFetch(
      '${item.id}@${width}x$height',
      () => _fetchThumbnail(item, width, height),
    );
    if (bytes == null) {
      // _fetchThumbnail returns Uint8List? and has already discarded WHY, so
      // re-derive it. Failure path only, and getOrFetch never caches a null
      // (gallery_thumbnail_cache.dart:99-103), so this costs nothing in the
      // common case. resolveAssetId short-circuits at the permission check
      // before it queries the gallery.
      //
      // Load-bearing: grid tiles call resolveThumbnail, so without this every
      // tile on a permission-revoked device reports notFound and the
      // reconciler would orphan the whole library.
      final status = (await _resolutionService.resolveAssetId(item)).status;
      return UnavailableData(
        kind: status == ResolutionStatus.accessDenied
            ? UnavailableKind.accessDenied
            : UnavailableKind.notFound,
      );
    }
    return BytesData(
      bytes: bytes,
      servedFrom: ServedFrom.platformGallery,
      servedTier: ServedTier.thumbnail,
    );
  }

  /// Runs only on a cache miss.
  Future<Uint8List?> _fetchThumbnail(
    MediaItem item,
    int width,
    int height,
  ) async {
    final resolvedId = await _resolveId(item);
    if (resolvedId == null) return null;
    final bytes = await _thumbBytes(resolvedId, width, height);
    if (bytes != null) return bytes;
    // The mapping produced no bytes. That is now the ONLY staleness signal:
    // resolveAssetId no longer pre-checks with a throwaway fetch. Drop the
    // mapping, search the gallery again, and retry once against a genuinely
    // different id.
    final retry = await _resolutionService.reresolve(item);
    final retryId = retry.localAssetId;
    if (retryId == null || retryId == resolvedId) return null;
    return _thumbBytes(retryId, width, height);
  }

  // coverage:ignore-start
  // photo_manager AssetEntity APIs require a real device gallery.
  Future<Uint8List?> _thumbBytes(String id, int width, int height) async {
    final asset = await AssetEntity.fromId(id);
    if (asset == null) return null;
    return asset.thumbnailDataWithSize(ThumbnailSize(width, height));
  }
  // coverage:ignore-end

  @override
  Future<MediaSourceMetadata?> extractMetadata(MediaItem item) async {
    final assetId = item.platformAssetId;
    if (assetId == null || assetId.isEmpty) return null;
    final resolvedId = await _resolveId(item);
    if (resolvedId == null) return null;
    // coverage:ignore-start
    final asset = await AssetEntity.fromId(resolvedId);
    if (asset == null) return null;
    final ll = await asset.latlngAsync();
    return MediaSourceMetadata(
      takenAt: asset.createDateTime,
      latitude: (ll?.latitude == 0.0) ? null : ll?.latitude,
      longitude: (ll?.longitude == 0.0) ? null : ll?.longitude,
      width: asset.width,
      height: asset.height,
      durationSeconds: asset.duration > 0 ? asset.duration : null,
      mimeType: asset.mimeType ?? 'application/octet-stream',
    );
    // coverage:ignore-end
  }

  @override
  Future<VerifyResult> verify(MediaItem item) async {
    final assetId = item.platformAssetId;
    if (assetId == null || assetId.isEmpty) return VerifyResult.notFound;
    final resolution = await _resolutionService.resolveAssetId(item);
    // Before the id check: accessDenied always carries a null id, and
    // returning notFound here is what used to let a revoked permission mark
    // every row in the library orphaned.
    if (resolution.status == ResolutionStatus.accessDenied) {
      return VerifyResult.accessDenied;
    }
    final resolvedId = resolution.localAssetId;
    if (resolvedId == null) return VerifyResult.notFound;
    // coverage:ignore-start
    final asset = await AssetEntity.fromId(resolvedId);
    return asset == null ? VerifyResult.notFound : VerifyResult.available;
    // coverage:ignore-end
  }

  /// Delegates to [AssetResolutionService] to obtain the local asset ID.
  /// Returns null when resolution fails or no match is found.
  Future<String?> _resolveId(MediaItem item) async {
    final result = await _resolutionService.resolveAssetId(item);
    if (result.status == ResolutionStatus.unavailable ||
        result.localAssetId == null) {
      return null;
    }
    return result.localAssetId;
  }
}
