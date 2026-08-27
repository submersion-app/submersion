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
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';

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
  @override
  Future<MediaSourceMetadata?> getAssetMetadata(String assetId) async => null;
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

/// The gallery refused to answer, which is what a revoked or not-yet-granted
/// photo permission produces. Distinct from [_unavailableService], which is
/// the gallery answering "no such asset".
AssetResolutionService _accessDeniedService() => _FakeAssetResolutionService(
  const ResolutionResult(status: ResolutionStatus.accessDenied),
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

  // The three tests below pin the distinction the orphan-reconciliation path
  // depends on. A denied photo library makes EVERY gallery row fail, so if
  // these reported notFound, one revoked permission would orphan the whole
  // library and sync that claim to every other device.
  group('denied gallery access is not reported as a missing asset', () {
    test('resolve reports accessDenied', () async {
      final r = PlatformGalleryResolver(
        resolutionService: _accessDeniedService(),
      );
      final data = await r.resolve(_gallery(assetId: 'A'));
      expect(data, isA<UnavailableData>());
      expect((data as UnavailableData).kind, UnavailableKind.accessDenied);
    });

    // Grid tiles take this path, not resolve, so this is the one that
    // actually protects a scrolling library.
    test('resolveThumbnail reports accessDenied', () async {
      final r = PlatformGalleryResolver(
        resolutionService: _accessDeniedService(),
      );
      final data = await r.resolveThumbnail(
        _gallery(assetId: 'A'),
        target: const Size(200, 200),
      );
      expect(data, isA<UnavailableData>());
      expect((data as UnavailableData).kind, UnavailableKind.accessDenied);
    });

    test('verify reports accessDenied', () async {
      final r = PlatformGalleryResolver(
        resolutionService: _accessDeniedService(),
      );
      expect(await r.verify(_gallery(assetId: 'A')), VerifyResult.accessDenied);
    });

    // The negative half: a gallery that answered "no such asset" must still
    // report notFound, or the reconciler could never orphan anything.
    test('a genuine miss still reports notFound', () async {
      final r = PlatformGalleryResolver(
        resolutionService: _unavailableService(),
      );
      final data = await r.resolveThumbnail(
        _gallery(assetId: 'A'),
        target: const Size(200, 200),
      );
      expect((data as UnavailableData).kind, UnavailableKind.notFound);
      expect(await r.verify(_gallery(assetId: 'A')), VerifyResult.notFound);
    });
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
