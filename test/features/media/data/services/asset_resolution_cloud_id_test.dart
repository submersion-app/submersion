import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media/data/repositories/local_asset_cache_repository.dart';
import 'package:submersion/features/media/data/services/asset_resolution_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../../helpers/fake_photo_picker_service.dart';

/// Device B's view of a photo device A linked: A's local id does not load
/// here, and B's library holds the photo under its own id (spec 6.2).
void main() {
  late LocalCacheDatabase cacheDb;
  late LocalAssetCacheRepository cache;
  late FakePhotoPickerService library;
  late AssetResolutionService service;
  final taken = DateTime(2026, 7, 1, 10, 30);
  final frame1 = Uint8List.fromList([1]);
  final frame2 = Uint8List.fromList([2]);

  setUp(() {
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    cache = LocalAssetCacheRepository(database: cacheDb);
    library = FakePhotoPickerService();
    service = AssetResolutionService(
      cacheRepository: cache,
      photoPickerService: library,
      cloudIdentifiers: library,
    );
  });

  tearDown(() => cacheDb.close());

  /// A burst pair: same second, same dimensions, no titles.
  void addBurstPair() {
    library
      ..add(
        FakeGalleryAsset(
          id: 'B-1',
          bytes: frame1,
          takenAt: taken,
          filename: null,
          cloudId: 'C-1',
        ),
      )
      ..add(
        FakeGalleryAsset(
          id: 'B-2',
          bytes: frame2,
          takenAt: taken,
          filename: null,
          cloudId: 'C-2',
        ),
      );
  }

  MediaItem row({String? cloudAssetId, int? width, int? height}) => MediaItem(
    id: 'm1',
    platformAssetId: 'A-1',
    cloudAssetId: cloudAssetId,
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.platformGallery,
    width: width,
    height: height,
    // Wall-clock-as-UTC, the stored convention.
    takenAt: DateTime.utc(2026, 7, 1, 10, 30),
    createdAt: DateTime.utc(2026, 7, 1),
    updatedAt: DateTime.utc(2026, 7, 1),
  );

  test('a cloud id picks the right frame of a burst pair', () async {
    addBurstPair();

    final r = await service.resolveAssetId(row(cloudAssetId: 'C-2'));

    expect(r.status, ResolutionStatus.resolved);
    expect(r.localAssetId, 'B-2');
    expect((await cache.getCacheEntry('m1'))!.resolutionMethod, 'cloud_id');
  });

  test('without a cloud id the burst pair stays unresolved', () async {
    addBurstPair();

    final r = await service.resolveAssetId(row(width: 4032, height: 3024));

    expect(r.status, ResolutionStatus.unavailable);
    expect(library.cloudIdCalls, 0, reason: 'nothing to match, so no lookup');
  });

  test('an empty cloud id is none, and is not looked up', () async {
    addBurstPair();

    await service.resolveAssetId(row(cloudAssetId: ''));

    expect(library.cloudIdCalls, 0);
  });

  test('a cloud id no candidate carries falls through to metadata', () async {
    library.add(
      FakeGalleryAsset(
        id: 'B-1',
        bytes: frame1,
        takenAt: taken,
        filename: null,
      ),
    );

    final r = await service.resolveAssetId(
      row(cloudAssetId: 'C-9', width: 4032, height: 3024),
    );

    expect(r.localAssetId, 'B-1');
    expect(
      (await cache.getCacheEntry('m1'))!.resolutionMethod,
      'exact_timestamp_dimensions',
    );
  });

  test('a failed lookup falls through to metadata', () async {
    library
      ..add(
        FakeGalleryAsset(
          id: 'B-1',
          bytes: frame1,
          takenAt: taken,
          filename: null,
          cloudId: 'C-1',
        ),
      )
      ..cloudIdError = StateError('channel');

    final r = await service.resolveAssetId(
      row(cloudAssetId: 'C-1', width: 4032, height: 3024),
    );

    expect(r.localAssetId, 'B-1');
    expect(
      (await cache.getCacheEntry('m1'))!.resolutionMethod,
      'exact_timestamp_dimensions',
    );
  });

  // Never expected from PhotoKit, but a tie is not an answer.
  test('two candidates with the same cloud id is no match', () async {
    library
      ..add(
        FakeGalleryAsset(
          id: 'B-1',
          bytes: frame1,
          takenAt: taken,
          filename: null,
          cloudId: 'C-1',
        ),
      )
      ..add(
        FakeGalleryAsset(
          id: 'B-2',
          bytes: frame2,
          takenAt: taken,
          filename: null,
          cloudId: 'C-1',
        ),
      );

    final r = await service.resolveAssetId(row(cloudAssetId: 'C-1'));

    expect(r.status, ResolutionStatus.unavailable);
  });

  // Opening a dive resolves its photos together, over the same time window:
  // one lookup answers them all, as one gallery query already does.
  test('rows resolving together share one cloud id lookup', () async {
    addBurstPair();
    final second = MediaItem(
      id: 'm2',
      platformAssetId: 'A-2',
      cloudAssetId: 'C-2',
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.platformGallery,
      takenAt: DateTime.utc(2026, 7, 1, 10, 30),
      createdAt: DateTime.utc(2026, 7, 1),
      updatedAt: DateTime.utc(2026, 7, 1),
    );

    final results = await Future.wait([
      service.resolveAssetId(row(cloudAssetId: 'C-1')),
      service.resolveAssetId(second),
    ]);

    expect([for (final r in results) r.localAssetId], ['B-1', 'B-2']);
    expect(library.cloudIdCalls, 1);
  });

  test('a platform with no cloud identifiers is never asked', () async {
    addBurstPair();
    library.supportsCloudIdentifiers = false;

    await service.resolveAssetId(row(cloudAssetId: 'C-1'));

    expect(library.cloudIdCalls, 0);
  });
}
