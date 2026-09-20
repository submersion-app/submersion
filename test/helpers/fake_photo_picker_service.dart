import 'dart:typed_data';

import 'package:submersion/features/media/data/services/gallery_asset_reader.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';

/// One photo or video in a fake device library.
class FakeGalleryAsset {
  const FakeGalleryAsset({
    required this.id,
    required this.bytes,
    required this.takenAt,
    this.width = 4032,
    this.height = 3024,
    this.filename = 'IMG_0001.JPG',
    this.type = AssetType.image,
  });

  final String id;
  final Uint8List bytes;
  final DateTime takenAt;
  final int width;
  final int height;

  /// Null models a library listing that carries no title, which PhotoKit
  /// often omits on a peer's fast date-range query.
  final String? filename;
  final AssetType type;

  AssetInfo get info => AssetInfo(
    id: id,
    type: type,
    createDateTime: takenAt,
    width: width,
    height: height,
    filename: filename,
  );
}

/// In-memory photo library standing in for photo_manager on one device.
///
/// Serves both halves of the gallery stack: the candidate search
/// `AssetResolutionService` runs through [PhotoPickerService], and the byte
/// reads `PlatformGalleryResolver` runs through [GalleryAssetReader]. Two
/// devices get two instances; a shared iCloud library is modelled by giving
/// both the same bytes under different ids.
class FakePhotoPickerService implements PhotoPickerService, GalleryAssetReader {
  FakePhotoPickerService({
    List<FakeGalleryAsset> assets = const [],
    this.permission = PhotoPermissionStatus.authorized,
    this.supportsGalleryBrowsing = true,
  }) : _assets = {for (final a in assets) a.id: a};

  final Map<String, FakeGalleryAsset> _assets;
  PhotoPermissionStatus permission;

  /// Ids the user did NOT select under limited access. Invisible to every
  /// query while [permission] is [PhotoPermissionStatus.limited].
  final Set<String> hiddenFromLimitedAccess = {};

  @override
  final bool supportsGalleryBrowsing;

  void add(FakeGalleryAsset asset) => _assets[asset.id] = asset;
  void remove(String id) => _assets.remove(id);

  FakeGalleryAsset? _visible(String id) {
    final asset = _assets[id];
    if (asset == null) return null;
    if (permission == PhotoPermissionStatus.limited &&
        hiddenFromLimitedAccess.contains(id)) {
      return null;
    }
    if (permission == PhotoPermissionStatus.denied ||
        permission == PhotoPermissionStatus.restricted) {
      return null;
    }
    return asset;
  }

  /// Newest first, as [PhotoPickerService] documents: the resolver's
  /// candidate order is part of the contract, so returning insertion order
  /// would let a test pass on setup order alone.
  @override
  Future<List<AssetInfo>> getAssetsInDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final matches = [
      for (final a in _assets.values)
        if (_visible(a.id) != null &&
            !a.takenAt.isBefore(start) &&
            !a.takenAt.isAfter(end))
          a,
    ]..sort((a, b) => b.takenAt.compareTo(a.takenAt));
    return [for (final a in matches) a.info];
  }

  @override
  Future<Uint8List?> getThumbnail(String assetId, {int size = 200}) async =>
      _visible(assetId)?.bytes;

  @override
  Future<Uint8List?> getFileBytes(String assetId) async =>
      _visible(assetId)?.bytes;

  @override
  Future<PhotoPermissionStatus> checkPermission() async => permission;

  @override
  Future<PhotoPermissionStatus> requestPermission() async => permission;

  @override
  Future<String?> getFilePath(String assetId) async => null;

  @override
  Future<MediaSourceMetadata?> getAssetMetadata(String assetId) =>
      metadata(assetId);

  // GalleryAssetReader

  @override
  Future<Uint8List?> originBytes(String assetId) async =>
      _visible(assetId)?.bytes;

  @override
  Future<Uint8List?> thumbnailBytes(
    String assetId,
    int width,
    int height,
  ) async => _visible(assetId)?.bytes;

  @override
  Future<bool> exists(String assetId) async => _visible(assetId) != null;

  @override
  Future<MediaSourceMetadata?> metadata(String assetId) async {
    final a = _visible(assetId);
    if (a == null) return null;
    return MediaSourceMetadata(
      takenAt: a.takenAt,
      width: a.width,
      height: a.height,
      mimeType: a.type == AssetType.video ? 'video/quicktime' : 'image/jpeg',
    );
  }
}
