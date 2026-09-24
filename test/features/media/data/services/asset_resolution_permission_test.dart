import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media/data/repositories/local_asset_cache_repository.dart';
import 'package:submersion/features/media/data/services/asset_resolution_service.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../../helpers/fake_photo_picker_service.dart';

/// On the device that linked a photo, a search that could not see the whole
/// library is never evidence the photo is gone (media sync program spec
/// 6.3): nothing it reports may become the orphaning notFound verdict.
void main() {
  late LocalCacheDatabase cacheDb;
  late LocalAssetCacheRepository cache;
  late FakePhotoPickerService library;
  late AssetResolutionService service;
  final taken = DateTime(2026, 7, 1, 10, 30);

  setUp(() {
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    cache = LocalAssetCacheRepository(database: cacheDb);
    library = FakePhotoPickerService();
    service = AssetResolutionService(
      cacheRepository: cache,
      photoPickerService: library,
    );
  });

  tearDown(() => cacheDb.close());

  /// A row whose stored id no longer loads (a re-index, or another
  /// device's id), carrying the metadata the tiers match on.
  MediaItem row() => MediaItem(
    id: 'm1',
    platformAssetId: 'gone',
    originalFilename: 'IMG_0001.JPG',
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.platformGallery,
    width: 4032,
    height: 3024,
    // Wall-clock-as-UTC, the stored convention.
    takenAt: DateTime.utc(2026, 7, 1, 10, 30),
    createdAt: DateTime.utc(2026, 7, 1),
    updatedAt: DateTime.utc(2026, 7, 1),
  );

  void addPhoto() => library.add(
    FakeGalleryAsset(id: 'B-1', bytes: Uint8List.fromList([1]), takenAt: taken),
  );

  // Resolution runs from thumbnail renders. On a phone, asking for access
  // shows the OS prompt, which must come only from the picker or the
  // "Allow full access" button.
  test('resolution reads permission and never prompts', () async {
    addPhoto();

    final r = await service.resolveAssetId(row());

    expect(r.localAssetId, 'B-1');
    expect(library.prompts, 0);
  });

  test(
    'a gallery query that fails is inconclusive, never unavailable',
    () async {
      addPhoto();
      library.queryError = StateError('channel');

      final r = await service.resolveAssetId(row());

      expect(r.status, ResolutionStatus.accessDenied);
      expect(await cache.getCacheEntry('m1'), isNull);
    },
  );

  test('a permission read that fails is inconclusive', () async {
    final failing = _FailingPermission();
    final r = await AssetResolutionService(
      cacheRepository: cache,
      photoPickerService: failing,
    ).resolveAssetId(row());

    expect(r.status, ResolutionStatus.accessDenied);
    expect(await cache.getCacheEntry('m1'), isNull);
  });
}

/// A library whose permission read throws, as a platform channel can.
class _FailingPermission extends FakePhotoPickerService {
  @override
  Future<PhotoPermissionStatus> currentPermission() async =>
      throw StateError('channel');
}
