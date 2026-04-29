import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/repositories/local_asset_cache_repository.dart';
import 'package:submersion/features/media/data/resolvers/platform_gallery_resolver.dart';
import 'package:submersion/features/media/data/services/asset_resolution_service.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';

// ---------------------------------------------------------------------------
// Stub PhotoPickerService (abstract — must be implemented for tests)
// ---------------------------------------------------------------------------

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
}

// ---------------------------------------------------------------------------
// Fake AssetResolutionService that returns a configurable result
// without touching the database or gallery.
// ---------------------------------------------------------------------------

class _FakeAssetResolutionService extends AssetResolutionService {
  final ResolutionResult _result;

  _FakeAssetResolutionService(this._result)
    : super(
        cacheRepository: LocalAssetCacheRepository(),
        photoPickerService: _StubPhotoPickerService(),
      );

  @override
  Future<ResolutionResult> resolveAssetId(MediaItem item) async => _result;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

AssetResolutionService _unavailableService() => _FakeAssetResolutionService(
  const ResolutionResult(status: ResolutionStatus.unavailable),
);

MediaItem _gallery({String? assetId, String? originDeviceId}) => MediaItem(
  id: 'x',
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.platformGallery,
  platformAssetId: assetId,
  originDeviceId: originDeviceId,
  takenAt: DateTime.utc(2024, 1, 1),
  createdAt: DateTime.utc(2024, 1, 1),
  updatedAt: DateTime.utc(2024, 1, 1),
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  test('canResolveOnThisDevice is always true for gallery items', () {
    final r = PlatformGalleryResolver(resolutionService: _unavailableService());
    expect(r.canResolveOnThisDevice(_gallery(assetId: 'A')), isTrue);
    expect(r.canResolveOnThisDevice(_gallery(originDeviceId: 'other')), isTrue);
  });

  test('resolve returns Unavailable.notFound when assetId missing', () async {
    final r = PlatformGalleryResolver(resolutionService: _unavailableService());
    final data = await r.resolve(_gallery(assetId: null));
    expect(data, isA<UnavailableData>());
    expect((data as UnavailableData).kind, UnavailableKind.notFound);
  });

  test('resolve returns Unavailable.notFound when assetId empty', () async {
    final r = PlatformGalleryResolver(resolutionService: _unavailableService());
    final data = await r.resolve(_gallery(assetId: ''));
    expect(data, isA<UnavailableData>());
    expect((data as UnavailableData).kind, UnavailableKind.notFound);
  });

  test('extractMetadata returns null when assetId missing', () async {
    final r = PlatformGalleryResolver(resolutionService: _unavailableService());
    final m = await r.extractMetadata(_gallery(assetId: null));
    expect(m, isNull);
  });

  test('verify returns notFound when assetId missing', () async {
    final r = PlatformGalleryResolver(resolutionService: _unavailableService());
    final v = await r.verify(_gallery(assetId: null));
    expect(v.toString(), contains('notFound'));
  });
}
