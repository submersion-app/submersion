import 'dart:typed_data';

import 'package:photo_manager/photo_manager.dart' as pm;

import 'package:submersion/features/media/data/services/photo_picker_service.dart';

/// Photo picker implementation for iOS, Android, and macOS using photo_manager.
///
/// This implementation provides full gallery access with date range filtering,
/// making it ideal for selecting dive photos from a specific time window.
class PhotoPickerServiceMobile implements PhotoPickerService {
  /// Cache of AssetEntity objects keyed by their ID.
  /// Used to retrieve full file bytes after thumbnail selection.
  final Map<String, pm.AssetEntity> _assetCache = {};

  @override
  bool get supportsGalleryBrowsing => true;

  @override
  Future<PhotoPermissionStatus> checkPermission() async {
    final status = await pm.PhotoManager.requestPermissionExtend(
      requestOption: const pm.PermissionRequestOption(
        androidPermission: pm.AndroidPermission(
          type: pm.RequestType.common,
          mediaLocation: true,
        ),
      ),
    );
    return _mapPermissionStatus(status);
  }

  @override
  Future<PhotoPermissionStatus> requestPermission() async {
    final status = await pm.PhotoManager.requestPermissionExtend(
      requestOption: const pm.PermissionRequestOption(
        androidPermission: pm.AndroidPermission(
          type: pm.RequestType.common,
          mediaLocation: true,
        ),
      ),
    );
    return _mapPermissionStatus(status);
  }

  @override
  Future<List<AssetInfo>> getAssetsInDateRange(
    DateTime start,
    DateTime end,
  ) async {
    // Clear cache before new query
    _assetCache.clear();

    // Create filter for date range with both photos and videos
    final filter = pm.FilterOptionGroup(
      imageOption: const pm.FilterOption(
        sizeConstraint: pm.SizeConstraint(ignoreSize: true),
      ),
      videoOption: const pm.FilterOption(
        sizeConstraint: pm.SizeConstraint(ignoreSize: true),
      ),
      createTimeCond: pm.DateTimeCond(min: start, max: end),
      orders: [
        const pm.OrderOption(type: pm.OrderOptionType.createDate, asc: false),
      ],
    );

    // Get all asset paths (albums)
    final albums = await pm.PhotoManager.getAssetPathList(
      type: pm.RequestType.common, // Photos and videos
      filterOption: filter,
    );

    if (albums.isEmpty) {
      return [];
    }

    // Collect assets from all albums (primarily "Recent" or "All Photos")
    final List<AssetInfo> results = [];

    for (final album in albums) {
      // Get asset count for this album
      final count = await album.assetCountAsync;
      if (count == 0) continue;

      // Load all assets from the album
      final assets = await album.getAssetListRange(start: 0, end: count);

      for (final asset in assets) {
        // Filter by date range (photo_manager filter should handle this,
        // but double-check for edge cases)
        final createTime = asset.createDateTime;
        if (createTime.isBefore(start) || createTime.isAfter(end)) {
          continue;
        }

        // Cache asset for later file retrieval
        _assetCache[asset.id] = asset;

        // Get GPS coordinates if available
        final latLng = await asset.latlngAsync();
        final lat = latLng?.latitude;
        final lng = latLng?.longitude;

        results.add(
          AssetInfo(
            id: asset.id,
            type: asset.type == pm.AssetType.video
                ? AssetType.video
                : AssetType.image,
            createDateTime: createTime,
            width: asset.width,
            height: asset.height,
            durationSeconds: asset.type == pm.AssetType.video
                ? asset.duration
                : null,
            latitude: lat != null && lat != 0 ? lat : null,
            longitude: lng != null && lng != 0 ? lng : null,
            filename: asset.title,
          ),
        );
      }
    }

    // Remove duplicates (same asset may appear in multiple albums)
    final uniqueResults = <String, AssetInfo>{};
    for (final asset in results) {
      uniqueResults[asset.id] = asset;
    }

    // Sort by creation date (newest first)
    final sorted = uniqueResults.values.toList()
      ..sort((a, b) => b.createDateTime.compareTo(a.createDateTime));

    return sorted;
  }

  @override
  Future<Uint8List?> getThumbnail(String assetId, {int size = 200}) async {
    final asset = _assetCache[assetId];
    if (asset == null) {
      // Try to retrieve asset if not in cache
      final retrieved = await pm.AssetEntity.fromId(assetId);
      if (retrieved == null) return null;
      _assetCache[assetId] = retrieved;
      return _getThumbnailFromAsset(retrieved, size);
    }
    return _getThumbnailFromAsset(asset, size);
  }

  Future<Uint8List?> _getThumbnailFromAsset(
    pm.AssetEntity asset,
    int size,
  ) async {
    final thumbnail = await asset.thumbnailDataWithSize(
      pm.ThumbnailSize(size, size),
      quality: 80,
    );
    return thumbnail;
  }

  @override
  Future<Uint8List?> getFileBytes(String assetId) async {
    final asset = _assetCache[assetId] ?? await pm.AssetEntity.fromId(assetId);
    if (asset == null) return null;

    final file = await asset.file;
    if (file == null) return null;

    return file.readAsBytes();
  }

  @override
  Future<String?> getFilePath(String assetId) async {
    final asset = _assetCache[assetId] ?? await pm.AssetEntity.fromId(assetId);
    if (asset == null) return null;

    final file = await asset.file;
    return file?.path;
  }

  PhotoPermissionStatus _mapPermissionStatus(pm.PermissionState status) {
    switch (status) {
      case pm.PermissionState.authorized:
        return PhotoPermissionStatus.authorized;
      case pm.PermissionState.denied:
        return PhotoPermissionStatus.denied;
      case pm.PermissionState.limited:
        return PhotoPermissionStatus.limited;
      case pm.PermissionState.notDetermined:
        return PhotoPermissionStatus.notDetermined;
      case pm.PermissionState.restricted:
        return PhotoPermissionStatus.restricted;
    }
  }
}
