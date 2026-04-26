import 'dart:ui' show Size;

import 'package:photo_manager/photo_manager.dart';

import 'package:submersion/features/media/data/services/asset_resolution_service.dart';
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

  PlatformGalleryResolver({required AssetResolutionService resolutionService})
    : _resolutionService = resolutionService;

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
    final resolvedId = await _resolveId(item);
    if (resolvedId == null) {
      return const UnavailableData(kind: UnavailableKind.notFound);
    }
    final asset = await AssetEntity.fromId(resolvedId);
    if (asset == null) {
      return const UnavailableData(kind: UnavailableKind.notFound);
    }
    final bytes = await asset.originBytes;
    if (bytes == null) {
      return const UnavailableData(kind: UnavailableKind.notFound);
    }
    return BytesData(bytes: bytes);
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
    final resolvedId = await _resolveId(item);
    if (resolvedId == null) {
      return const UnavailableData(kind: UnavailableKind.notFound);
    }
    final asset = await AssetEntity.fromId(resolvedId);
    if (asset == null) {
      return const UnavailableData(kind: UnavailableKind.notFound);
    }
    final thumbBytes = await asset.thumbnailDataWithSize(
      ThumbnailSize(target.width.toInt(), target.height.toInt()),
    );
    if (thumbBytes == null) {
      return const UnavailableData(kind: UnavailableKind.notFound);
    }
    return BytesData(bytes: thumbBytes);
  }

  @override
  Future<MediaSourceMetadata?> extractMetadata(MediaItem item) async {
    final assetId = item.platformAssetId;
    if (assetId == null || assetId.isEmpty) return null;
    final resolvedId = await _resolveId(item);
    if (resolvedId == null) return null;
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
  }

  @override
  Future<VerifyResult> verify(MediaItem item) async {
    final assetId = item.platformAssetId;
    if (assetId == null || assetId.isEmpty) return VerifyResult.notFound;
    final resolvedId = await _resolveId(item);
    if (resolvedId == null) return VerifyResult.notFound;
    final asset = await AssetEntity.fromId(resolvedId);
    return asset == null ? VerifyResult.notFound : VerifyResult.available;
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
