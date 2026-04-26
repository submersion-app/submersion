import 'dart:ui' show Size;

import 'package:photo_manager/photo_manager.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';

/// Resolves [MediaSourceType.platformGallery] items via [photo_manager].
///
/// Gallery photos are universally addressable on the device that owns the
/// platform library — [canResolveOnThisDevice] returns `true` regardless of
/// `originDeviceId` because the existing gallery flow already handles
/// cross-device asset ID resolution via [resolved_asset_providers].
class PlatformGalleryResolver implements MediaSourceResolver {
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
    final asset = await AssetEntity.fromId(assetId);
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
    final asset = await AssetEntity.fromId(assetId);
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
    final asset = await AssetEntity.fromId(assetId);
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
    final asset = await AssetEntity.fromId(assetId);
    return asset == null ? VerifyResult.notFound : VerifyResult.available;
  }
}
