import 'dart:ui' show Size;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/features/media/data/repositories/local_asset_cache_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/media_health_reporter.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';

import '../../../../helpers/in_memory_media_object_store.dart';
import '../../../../helpers/test_database.dart';

/// Two costs a report must not pay, both invisible from a one-row test.
void main() {
  late AppDatabase db;
  late LocalCacheDatabase cacheDb;
  late InMemoryMediaObjectStore bucket;
  var nameLookups = 0;

  TestWidgetsFlutterBinding.ensureInitialized();

  const hash =
      'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = await setUpTestDatabase();
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    LocalCacheDatabaseService.instance.setTestDatabase(cacheDb);
    bucket = InMemoryMediaObjectStore();
    nameLookups = 0;
  });

  tearDown(() async {
    LocalCacheDatabaseService.instance.resetForTesting();
    DatabaseService.instance.resetForTesting();
    SyncClock.instance.reset();
    await cacheDb.close();
    await db.close();
  });

  MediaHealthReporter reporter() => MediaHealthReporter(
    mediaRepository: MediaRepository(),
    syncRepository: SyncRepository(),
    assetCache: LocalAssetCacheRepository(),
    queue: MediaTransferQueueRepository(),
    registry: MediaSourceResolverRegistry({
      for (final t in MediaSourceType.values) t: _StubResolver(),
    }),
    attachState: MediaStoreAttachState(),
    store: () async => bucket,
    localDeviceId: () async => 'dev-1',
    localDeviceName: () async {
      nameLookups++;
      return 'This device';
    },
    deviceName: (_) => null,
  );

  group('the store probe covers the whole namespace', () {
    MediaItem uploaded({required String filename}) => MediaItem(
      id: 'm-1',
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.localFile,
      originalFilename: filename,
      contentHash: hash,
      remoteUploadedAt: DateTime(2026, 7, 1),
      takenAt: DateTime(2026, 7, 1),
      createdAt: DateTime(2026, 7, 1),
      updatedAt: DateTime(2026, 7, 1),
    );

    test('an original stored under another extension is found', () async {
      // The first uploader held the photo as IMG_1.JPG and keyed it .jpg.
      // This device holds identical bytes as IMG_1.jpeg, and skipped the
      // upload because the stamp had already synced, so its own spelling
      // was never written to the store.
      bucket.objects[StoreKeys.objectKey(hash, extension: 'jpg')] = [1, 2, 3];

      final report = await reporter().forItem(
        uploaded(filename: 'IMG_1.jpeg'),
        probeStore: true,
      );

      expect(report.rows.single.storeObjectExists, isTrue);
      expect(report.rows.single.storeObjectTier, 'original');
    });

    test('a hash with nothing stored still reports missing', () async {
      bucket.objects['smv1/objects/zz/${'0' * 64}.jpg'] = [1, 2, 3];

      final report = await reporter().forItem(
        uploaded(filename: 'IMG_1.jpeg'),
        probeStore: true,
      );

      expect(report.rows.single.storeObjectExists, isFalse);
      expect(report.rows.single.storeObjectTier, isNull);
    });

    test('a longer hash sharing this one as a prefix is not a match', () async {
      // The trailing dot in objectKeyPrefix is what keeps one hash from
      // prefix-matching another; without it this would read as present.
      bucket.objects['smv1/objects/a1/${hash}ff.jpg'] = [1, 2, 3];

      final report = await reporter().forItem(
        uploaded(filename: 'IMG_1.jpeg'),
        probeStore: true,
      );

      expect(report.rows.single.storeObjectExists, isFalse);
    });
  });

  group('this device is named once per report', () {
    Future<void> seed(int count) async {
      for (var i = 0; i < count; i++) {
        await MediaRepository().createMedia(
          MediaItem(
            id: 'm-$i',
            mediaType: MediaType.photo,
            sourceType: MediaSourceType.localFile,
            filePath: '/nowhere/reef-$i.jpg',
            originDeviceId: 'dev-1',
            takenAt: DateTime(2026, 7, 1),
            createdAt: DateTime(2026, 7, 1),
            updatedAt: DateTime(2026, 7, 1),
          ),
        );
      }
    }

    test('a library of rows linked here costs one lookup', () async {
      await seed(5);

      final report = await reporter().forLibrary();

      expect(report.rows, hasLength(5));
      expect(
        report.rows.every((r) => r.originDeviceName == 'This device'),
        isTrue,
        reason: 'every row still carries the name',
      );
      // The injected lookup resolves device metadata from scratch: a
      // database read plus two uncached platform channels. Once per row
      // turned a library export into thousands of them.
      expect(nameLookups, 1);
    });

    test('a one-row report costs one lookup', () async {
      await reporter().forItem(
        MediaItem(
          id: 'm-1',
          mediaType: MediaType.photo,
          sourceType: MediaSourceType.localFile,
          originDeviceId: 'dev-1',
          takenAt: DateTime(2026, 7, 1),
          createdAt: DateTime(2026, 7, 1),
          updatedAt: DateTime(2026, 7, 1),
        ),
      );

      expect(nameLookups, 1);
    });
  });
}

/// Answers every verify without touching a source.
class _StubResolver implements MediaSourceResolver {
  @override
  MediaSourceType get sourceType => MediaSourceType.localFile;

  @override
  bool canResolveOnThisDevice(MediaItem item) => true;

  @override
  Future<VerifyResult> verify(MediaItem item) async => VerifyResult.available;

  @override
  Future<MediaSourceData> resolve(MediaItem item) async =>
      throw StateError('a report must never take the bytes path');

  @override
  Future<MediaSourceData> resolveThumbnail(
    MediaItem item, {
    required Size target,
  }) => throw StateError('a report must never take the bytes path');

  @override
  Future<MediaSourceMetadata?> extractMetadata(MediaItem item) async => null;
}
