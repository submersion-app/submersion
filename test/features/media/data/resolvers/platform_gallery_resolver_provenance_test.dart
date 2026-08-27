import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/repositories/local_asset_cache_repository.dart';
import 'package:submersion/features/media/data/resolvers/platform_gallery_resolver.dart';
import 'package:submersion/features/media/data/services/asset_resolution_service.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';

// The resolver's two SUCCESS returns cannot be reached from a test host:
// they call AssetEntity.fromId, which needs a real device photo library, and
// GalleryThumbnailCache keeps its entries private so a hit cannot be seeded.
// Both are stamped in the implementation and sit inside coverage:ignore
// blocks. What is reachable, and what this file pins, is the contract on the
// other side: a resolution that produced nothing must never claim a source.

class _StubPhotoPickerService implements PhotoPickerService {
  @override
  bool get supportsGalleryBrowsing => false;

  @override
  Future<List<AssetInfo>> getAssetsInDateRange(
    DateTime start,
    DateTime end,
  ) async => [];

  @override
  Future<Uint8List?> getThumbnail(String assetId, {int size = 200}) async =>
      null;

  @override
  Future<Uint8List?> getFileBytes(String assetId) async => null;

  @override
  Future<PhotoPermissionStatus> checkPermission() async =>
      PhotoPermissionStatus.denied;

  @override
  Future<PhotoPermissionStatus> requestPermission() async =>
      PhotoPermissionStatus.denied;

  @override
  Future<String?> getFilePath(String assetId) async => null;

  @override
  Future<MediaSourceMetadata?> getAssetMetadata(String assetId) async => null;
}

class _FakeAssetResolutionService extends AssetResolutionService {
  _FakeAssetResolutionService(this._result)
    : super(
        cacheRepository: LocalAssetCacheRepository(),
        photoPickerService: _StubPhotoPickerService(),
      );

  final ResolutionResult _result;

  @override
  Future<ResolutionResult> resolveAssetId(MediaItem item) async => _result;
}

PlatformGalleryResolver _unresolvable() => PlatformGalleryResolver(
  resolutionService: _FakeAssetResolutionService(
    const ResolutionResult(status: ResolutionStatus.unavailable),
  ),
);

MediaItem _gallery({String? assetId}) => MediaItem(
  id: 'm1',
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.platformGallery,
  platformAssetId: assetId,
  takenAt: DateTime.utc(2026),
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  test('a row with no asset id claims no source', () async {
    final data = await _unresolvable().resolve(_gallery());

    expect(data, isA<UnavailableData>());
    expect(data.servedFrom, isNull);
  });

  test('an unresolvable asset id claims no source', () async {
    final data = await _unresolvable().resolve(_gallery(assetId: 'gone'));

    expect(data, isA<UnavailableData>());
    expect(data.servedFrom, isNull);
  });

  test('an unresolvable thumbnail claims no source', () async {
    final data = await _unresolvable().resolveThumbnail(
      _gallery(assetId: 'gone'),
      target: const Size(128, 128),
    );

    expect(data, isA<UnavailableData>());
    expect(data.servedFrom, isNull);
  });
}
