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

  // A limited selection hides photos the device does have: a miss is not
  // evidence of absence, and caching it would back off a photo the user can
  // make visible in a moment.
  test(
    'under limited access a photo outside the selection is inconclusive',
    () async {
      addPhoto();
      library
        ..permission = PhotoPermissionStatus.limited
        ..hiddenFromLimitedAccess.add('B-1');

      final r = await service.resolveAssetId(row());

      expect(r.status, ResolutionStatus.accessDenied);
      expect(r.limitedAccess, isTrue);
      expect(await cache.getCacheEntry('m1'), isNull);
    },
  );

  test(
    'under limited access a photo in the selection still resolves',
    () async {
      addPhoto();
      library.permission = PhotoPermissionStatus.limited;

      final r = await service.resolveAssetId(row());

      expect(r.localAssetId, 'B-1');
    },
  );

  // Candidates in the window, none of them this photo: still a limited
  // view, so still inconclusive.
  test('under limited access a miss past the tiers is inconclusive', () async {
    library
      ..add(
        FakeGalleryAsset(
          id: 'B-other',
          bytes: Uint8List.fromList([2]),
          takenAt: taken,
          width: 10,
          height: 10,
          filename: 'OTHER.JPG',
        ),
      )
      ..permission = PhotoPermissionStatus.limited;

    final r = await service.resolveAssetId(row());

    expect(r.status, ResolutionStatus.accessDenied);
    expect(r.limitedAccess, isTrue);
    expect(await cache.getCacheEntry('m1'), isNull);
  });

  /// A file linked on this device, not a gallery asset: no stored asset id,
  /// only the metadata the tiers match on.
  MediaItem fileRow() => MediaItem(
    id: 'f1',
    originalFilename: 'IMG_0001.JPG',
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.localFile,
    bookmarkRef: 'content://media/external/images/media/42',
    width: 4032,
    height: 3024,
    takenAt: DateTime.utc(2026, 7, 1, 10, 30),
    createdAt: DateTime.utc(2026, 7, 1),
    updatedAt: DateTime.utc(2026, 7, 1),
  );

  // A file whose read grant was lost is usually still in the photo library
  // (spec 6.3): the metadata tiers find it without a stored asset id.
  test('findInLibrary matches a row with no asset id by metadata', () async {
    addPhoto();

    final r = await service.findInLibrary(fileRow());

    expect(r.localAssetId, 'B-1');
  });

  // A mapping this search cached can go stale (a second re-index). It runs
  // only after a read has failed, so it proves the mapping before trusting
  // it: a stale one would otherwise be served as nothing, forever, and read
  // as notFound on the linking device.
  test(
    'findInLibrary searches again past a cached mapping that is gone',
    () async {
      addPhoto();
      await cache.cacheResolution(
        mediaId: 'f1',
        localAssetId: 'B-gone',
        method: 'filename_timestamp',
      );

      final r = await service.findInLibrary(fileRow());

      expect(r.localAssetId, 'B-1');
      expect((await cache.getCacheEntry('f1'))!.localAssetId, 'B-1');
    },
  );

  test('findInLibrary keeps a cached mapping that still loads', () async {
    addPhoto();
    await cache.cacheResolution(
      mediaId: 'f1',
      localAssetId: 'B-1',
      method: 'filename_timestamp',
    );
    library.queryError = StateError('a search would fail');

    final r = await service.findInLibrary(fileRow());

    expect(r.localAssetId, 'B-1', reason: 'no search was needed');
  });

  test('findInLibrary under limited access is inconclusive', () async {
    addPhoto();
    library
      ..permission = PhotoPermissionStatus.limited
      ..hiddenFromLimitedAccess.add('B-1');

    final r = await service.findInLibrary(fileRow());

    expect(r.status, ResolutionStatus.accessDenied);
    expect(r.limitedAccess, isTrue);
  });

  /// A search that gave up on the row earlier and is still backing off.
  Future<void> backedOff(String mediaId) => cache.cacheResolution(
    mediaId: mediaId,
    localAssetId: null,
    method: 'unresolved',
  );

  // A miss cached before limited access was honoured (every older build
  // cached one under limited access), or before the user narrowed access,
  // may not have seen the photo: it is evidence only under full access.
  test('a backed-off row under limited access is inconclusive', () async {
    await backedOff('m1');
    library.permission = PhotoPermissionStatus.limited;

    final r = await service.resolveAssetId(row());

    expect(r.status, ResolutionStatus.accessDenied);
    expect(r.limitedAccess, isTrue);
  });

  test('a backed-off row under full access is still unavailable', () async {
    await backedOff('m1');

    final r = await service.resolveAssetId(row());

    expect(r.status, ResolutionStatus.unavailable);
  });

  test('a backed-off row with access denied is inconclusive', () async {
    await backedOff('m1');
    library.permission = PhotoPermissionStatus.denied;

    final r = await service.resolveAssetId(row());

    expect(r.status, ResolutionStatus.accessDenied);
    expect(r.limitedAccess, isFalse);
  });

  test('a backed-off file row under limited access is inconclusive', () async {
    await backedOff('f1');
    library.permission = PhotoPermissionStatus.limited;

    final r = await service.findInLibrary(fileRow());

    expect(r.status, ResolutionStatus.accessDenied);
    expect(r.limitedAccess, isTrue);
  });

  // Gallery queries are shared for 30 seconds. One taken under full access
  // must not answer a search made after the user narrowed access: it would
  // match a photo that is now hidden.
  test('a query from full access is not reused under limited access', () async {
    addPhoto();
    await service.resolveAssetId(row());
    await cache.clearEntry('m1');
    library
      ..permission = PhotoPermissionStatus.limited
      ..hiddenFromLimitedAccess.add('B-1');

    final r = await service.resolveAssetId(row());

    expect(r.status, ResolutionStatus.accessDenied);
    expect(r.limitedAccess, isTrue);
  });

  // "Choose photo again" changes the selection without changing the
  // permission: the shared queries are dropped so the added photo shows.
  test(
    'a photo added to the selection is found once queries are forgotten',
    () async {
      addPhoto();
      library
        ..permission = PhotoPermissionStatus.limited
        ..hiddenFromLimitedAccess.add('B-1');
      expect(
        (await service.resolveAssetId(row())).status,
        ResolutionStatus.accessDenied,
      );

      library.hiddenFromLimitedAccess.remove('B-1');
      service.forgetGalleryQueries();

      expect((await service.resolveAssetId(row())).localAssetId, 'B-1');
    },
  );

  test(
    'findInLibrary on a host with no photo library is unavailable',
    () async {
      final none = AssetResolutionService(
        cacheRepository: cache,
        photoPickerService: FakePhotoPickerService(
          supportsGalleryBrowsing: false,
        ),
      );

      final r = await none.findInLibrary(fileRow());

      expect(r.status, ResolutionStatus.unavailable);
    },
  );

  test(
    'a backed-off row whose permission read fails is inconclusive',
    () async {
      await backedOff('m1');

      final r = await AssetResolutionService(
        cacheRepository: cache,
        photoPickerService: _FailingPermission(),
      ).resolveAssetId(row());

      expect(r.status, ResolutionStatus.accessDenied);
      expect(r.limitedAccess, isFalse);
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
