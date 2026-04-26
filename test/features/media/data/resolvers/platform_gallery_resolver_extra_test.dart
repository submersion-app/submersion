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

class _StubPhotoPickerService implements PhotoPickerService {
  @override
  bool get supportsGalleryBrowsing => false;
  @override
  Future<List<AssetInfo>> getAssetsInDateRange(DateTime s, DateTime e) async =>
      [];
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

class _FakeService extends AssetResolutionService {
  final ResolutionResult _r;
  _FakeService(this._r)
    : super(
        cacheRepository: LocalAssetCacheRepository(),
        photoPickerService: _StubPhotoPickerService(),
      );
  @override
  Future<ResolutionResult> resolveAssetId(MediaItem item) async => _r;
}

MediaItem _gallery({String? assetId = 'A'}) => MediaItem(
  id: 'x',
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.platformGallery,
  platformAssetId: assetId,
  takenAt: DateTime.utc(2024, 1, 1),
  createdAt: DateTime.utc(2024, 1, 1),
  updatedAt: DateTime.utc(2024, 1, 1),
);

void main() {
  test('sourceType getter returns platformGallery', () {
    final r = PlatformGalleryResolver(
      resolutionService: _FakeService(
        const ResolutionResult(status: ResolutionStatus.unavailable),
      ),
    );
    expect(r.sourceType, MediaSourceType.platformGallery);
  });

  test(
    'resolve returns Unavailable.notFound when AssetResolutionService is unavailable',
    () async {
      final r = PlatformGalleryResolver(
        resolutionService: _FakeService(
          const ResolutionResult(status: ResolutionStatus.unavailable),
        ),
      );
      final d = await r.resolve(_gallery());
      expect(d, isA<UnavailableData>());
      expect((d as UnavailableData).kind, UnavailableKind.notFound);
    },
  );

  test('resolveThumbnail returns notFound when assetId missing', () async {
    final r = PlatformGalleryResolver(
      resolutionService: _FakeService(
        const ResolutionResult(status: ResolutionStatus.unavailable),
      ),
    );
    final d = await r.resolveThumbnail(
      _gallery(assetId: null),
      target: const Size(64, 64),
    );
    expect(d, isA<UnavailableData>());
    expect((d as UnavailableData).kind, UnavailableKind.notFound);
  });

  test('resolveThumbnail returns notFound when assetId empty', () async {
    final r = PlatformGalleryResolver(
      resolutionService: _FakeService(
        const ResolutionResult(status: ResolutionStatus.unavailable),
      ),
    );
    final d = await r.resolveThumbnail(
      _gallery(assetId: ''),
      target: const Size(64, 64),
    );
    expect(d, isA<UnavailableData>());
  });

  test(
    'resolveThumbnail returns notFound when AssetResolutionService is unavailable',
    () async {
      final r = PlatformGalleryResolver(
        resolutionService: _FakeService(
          const ResolutionResult(status: ResolutionStatus.unavailable),
        ),
      );
      final d = await r.resolveThumbnail(
        _gallery(),
        target: const Size(64, 64),
      );
      expect(d, isA<UnavailableData>());
    },
  );

  test(
    'extractMetadata returns null when AssetResolutionService is unavailable',
    () async {
      final r = PlatformGalleryResolver(
        resolutionService: _FakeService(
          const ResolutionResult(status: ResolutionStatus.unavailable),
        ),
      );
      final m = await r.extractMetadata(_gallery());
      expect(m, isNull);
    },
  );

  test(
    'verify returns notFound when AssetResolutionService is unavailable',
    () async {
      final r = PlatformGalleryResolver(
        resolutionService: _FakeService(
          const ResolutionResult(status: ResolutionStatus.unavailable),
        ),
      );
      final v = await r.verify(_gallery());
      expect(v.toString(), contains('notFound'));
    },
  );
}
