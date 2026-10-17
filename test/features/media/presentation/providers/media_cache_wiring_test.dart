import 'dart:io';
import 'dart:ui' show Size;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/data/media_cache_settings.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/fake_path_provider.dart';
import '../../../../helpers/in_memory_media_object_store.dart';
import '../../../../helpers/test_database.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.supportPath);
  final String supportPath;

  @override
  Future<String?> getApplicationSupportPath() async => supportPath;
}

/// The production wiring of the thumbnail cache (issue #3337): the providers
/// that hand the real cache database, cache directory, preferences and media
/// repository to services which are otherwise tested with stand-ins. What is
/// asserted here is which of those each closure actually reaches.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory support;
  late Directory photos;
  late LocalCacheDatabase cacheDb;
  late SharedPreferences prefs;
  late MediaRepository repo;

  const tile = Size(200, 200);
  const mb = 1024 * 1024;

  setUp(() async {
    await setUpTestDatabase();
    support = await Directory.systemTemp.createTemp('media_cache_wiring');
    photos = await Directory.systemTemp.createTemp('media_cache_wiring_src');
    useFakePathProvider(_FakePathProvider(support.path));
    resetMediaCacheRootForTesting();
    LocalCacheDatabaseService.instance.resetForTesting();
    await LocalCacheDatabaseService.instance.initialize();
    cacheDb = LocalCacheDatabaseService.instance.database;
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = MediaRepository();
  });

  tearDown(() async {
    await cacheDb.close();
    LocalCacheDatabaseService.instance.resetForTesting();
    resetMediaCacheRootForTesting();
    await tearDownTestDatabase();
    if (support.existsSync()) await support.delete(recursive: true);
    if (photos.existsSync()) await photos.delete(recursive: true);
  });

  ProviderContainer container({bool withPrefs = true}) {
    final built = ProviderContainer(
      overrides: [
        if (withPrefs) sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(built.dispose);
    return built;
  }

  File writePng(String name) {
    final image = img.Image(width: 80, height: 60);
    img.fill(image, color: img.ColorRgb8(20, 80, 140));
    return File(p.join(photos.path, name))
      ..writeAsBytesSync(img.encodePng(image));
  }

  MediaItem photo(String id, File file, {String? hash}) => MediaItem(
    id: id,
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.localFile,
    originalFilename: p.basename(file.path),
    localPath: file.path,
    contentHash: hash,
    takenAt: DateTime(2026),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  String thumbsDir() =>
      p.join(support.path, 'Submersion', 'media_cache', 'thumbs');

  /// Indexes a thumbnail without writing a file: eviction sums sizes from
  /// the index, so this puts the pool over a cap without filling the disk.
  Future<void> indexThumb(String key, int sizeBytes, int accessedAt) => cacheDb
      .into(cacheDb.mediaCacheEntries)
      .insert(
        MediaCacheEntriesCompanion.insert(
          contentHash: key,
          kind: 'thumb',
          relativePath: p.join('thumbs', key.substring(0, 2), '$key.jpg'),
          sizeBytes: sizeBytes,
          lastAccessedAt: accessedAt,
          createdAt: accessedAt,
        ),
      );

  /// Polls [check] until it holds, for work a provider starts and does not
  /// hand back a future for.
  Future<void> eventually(Future<bool> Function() check) async {
    for (var i = 0; i < 100; i++) {
      if (await check()) return;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    fail('the condition never held');
  }

  group('openMediaCacheStore', () {
    test("caps the thumbnail pool at the diver's disk cache size", () async {
      await prefs.setInt(kMediaDiskCacheMbKey, 256);
      await indexThumb('aa${'1' * 62}', 200 * mb, 1);
      await indexThumb('bb${'2' * 62}', 200 * mb, 2);

      final store = await openMediaCacheStore(prefs);
      await store.evictIfNeeded();

      expect(await store.totalBytes(MediaCacheKind.thumb), 200 * mb);
    });

    test('reads the size when eviction runs, not when the store is '
        'opened', () async {
      await indexThumb('aa${'1' * 62}', 200 * mb, 1);
      await indexThumb('bb${'2' * 62}', 200 * mb, 2);
      final store = await openMediaCacheStore(prefs);
      await store.evictIfNeeded();
      expect(await store.totalBytes(MediaCacheKind.thumb), 400 * mb);

      await prefs.setInt(kMediaDiskCacheMbKey, 256);
      await store.evictIfNeeded();

      expect(await store.totalBytes(MediaCacheKind.thumb), 200 * mb);
    });

    test('without preferences the default size applies', () async {
      await indexThumb('aa${'1' * 62}', 300 * mb, 1);
      await indexThumb('bb${'2' * 62}', 300 * mb, 2);

      final store = await openMediaCacheStore(null);
      await store.evictIfNeeded();

      // Over the 512 MB default, so the older entry goes.
      expect(await store.totalBytes(MediaCacheKind.thumb), 300 * mb);
    });
  });

  group('localThumbnailCacheProvider', () {
    test("writes into the media cache's thumbnail pool", () async {
      final source = writePng('reef.png');

      final made = await container()
          .read(localThumbnailCacheProvider)
          .generate(photo('m1', source), file: source);

      expect(made, isNotNull);
      expect(p.isWithin(thumbsDir(), made!.path), isTrue);
    });

    test('works in a container that has no preferences', () async {
      final source = writePng('reef.png');

      final made = await container(withPrefs: false)
          .read(localThumbnailCacheProvider)
          .generate(photo('m1', source), file: source);

      expect(made, isNotNull);
    });
  });

  group('localFileResolverProvider', () {
    test('serves a photo thumbnail from the cache', () async {
      final source = writePng('reef.png');
      final resolver = container().read(localFileResolverProvider);

      final data = await resolver.resolveThumbnail(
        photo('m1', source),
        target: tile,
      );

      expect(p.isWithin(thumbsDir(), (data as FileData).file.path), isTrue);
    });

    test('a photo whose file has gone is marked missing, though its cached '
        'thumbnail still answers', () async {
      final source = writePng('reef.png');
      final item = photo('m1', source);
      await repo.createMedia(item);
      final resolver = container().read(localFileResolverProvider);
      await resolver.resolveThumbnail(item, target: tile);
      source.deleteSync();

      final data = await resolver.resolveThumbnail(item, target: tile);

      expect(data, isA<FileData>());
      await eventually(
        () async => (await repo.getMediaById('m1'))?.isOrphaned ?? false,
      );
    });

    test('a photo marked missing is resolved from its file every time, so '
        'the tile can clear the flag once the file is back', () async {
      final source = writePng('reef.png');
      await repo.createMedia(photo('m1', source));
      await repo.markVerified(
        'm1',
        isOrphaned: true,
        verifiedAt: DateTime(2026, 2),
      );
      final item = (await repo.getMediaById('m1'))!;
      expect(item.isOrphaned, isTrue);
      final resolver = container().read(localFileResolverProvider);
      await resolver.resolveThumbnail(item, target: tile);

      final again = await resolver.resolveThumbnail(item, target: tile);

      // Not a cache hit: the resolution read the original, which is what
      // lets MediaItemView reconcile the flag on it.
      expect((again as FileData).originUntouched, isFalse);
    });

    test('a photo that is where it was writes nothing', () async {
      final source = writePng('reef.png');
      final item = photo('m1', source);
      await repo.createMedia(item);
      final resolver = container().read(localFileResolverProvider);
      await resolver.resolveThumbnail(item, target: tile);

      await resolver.resolveThumbnail(item, target: tile);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final row = (await repo.getMediaById('m1'))!;
      expect(row.isOrphaned, isFalse);
      expect(row.lastVerifiedAt, isNull);
    });
  });

  group('mediaStoreProbeResolverProvider', () {
    test('serves a store thumbnail into the same thumbnail pool', () async {
      final hash = 'ef${'3' * 62}';
      final store = InMemoryMediaObjectStore();
      final staged = File(p.join(photos.path, 'thumb.jpg'))
        ..writeAsBytesSync([0xFF, 0xD8, 1, 2, 3]);
      await store.putFile(
        StoreKeys.thumbKey(hash),
        staged,
        contentType: 'image/jpeg',
      );
      final scope = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          attachedMediaObjectStoreProvider.overrideWith((ref) async => store),
        ],
      );
      addTearDown(scope.dispose);

      final resolver = await scope.read(mediaStoreProbeResolverProvider.future);
      final served = await resolver!.tryResolveRemote(
        photo(
          'm1',
          writePng('reef.png'),
          hash: hash,
        ).copyWith(remoteThumbUploadedAt: DateTime(2026, 2)),
        thumbnail: true,
      );

      expect(served, isA<FileData>());
      expect(p.isWithin(thumbsDir(), (served! as FileData).file.path), isTrue);
    });

    test('answers a store thumbnail already cached without touching the '
        'index', () async {
      final hash = 'fa${'4' * 62}';
      final store = InMemoryMediaObjectStore();
      final staged = File(p.join(photos.path, 'thumb.jpg'))
        ..writeAsBytesSync([0xFF, 0xD8, 1, 2, 3]);
      await store.putFile(
        StoreKeys.thumbKey(hash),
        staged,
        contentType: 'image/jpeg',
      );
      final scope = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          attachedMediaObjectStoreProvider.overrideWith((ref) async => store),
        ],
      );
      addTearDown(scope.dispose);
      final resolver = await scope.read(mediaStoreProbeResolverProvider.future);
      final item = photo(
        'm1',
        writePng('reef.png'),
        hash: hash,
      ).copyWith(remoteThumbUploadedAt: DateTime(2026, 2));
      await resolver!.tryResolveRemote(item, thumbnail: true);
      Future<int> lastAccessed() async =>
          (await cacheDb.select(cacheDb.mediaCacheEntries).getSingle())
              .lastAccessedAt;
      final before = await lastAccessed();
      await Future<void>.delayed(const Duration(milliseconds: 5));

      final served = await resolver.tryResolveRemote(item, thumbnail: true);

      expect((served! as FileData).servedFrom, ServedFrom.storeCache);
      expect(
        await lastAccessed(),
        before,
        reason: 'the hit is noted in memory and written at eviction',
      );
    });

    test('is null with no store attached', () async {
      final scope = ProviderContainer(
        overrides: [
          attachedMediaObjectStoreProvider.overrideWith((ref) async => null),
        ],
      );
      addTearDown(scope.dispose);

      expect(await scope.read(mediaStoreProbeResolverProvider.future), isNull);
    });
  });

  group('mediaDeletionCoordinatorProvider', () {
    Future<File> storeCopy(String hash) async {
      final store = await openMediaCacheStore(prefs);
      final staged = await store.stagingFile();
      await staged.writeAsBytes([1, 2, 3], flush: true);
      return store.put(hash, MediaCacheKind.original, staged, extension: 'jpg');
    }

    test('deleting a photo removes its thumbnail and the store copies '
        'nothing else uses', () async {
      final hash = 'ab${'1' * 62}';
      final source = writePng('reef.png');
      final item = photo('m1', source, hash: hash);
      await repo.createMedia(item);
      final scope = container();
      final thumb = await scope
          .read(localThumbnailCacheProvider)
          .generate(item, file: source);
      final original = await storeCopy(hash);

      await scope.read(mediaDeletionCoordinatorProvider).deleteMedia('m1');

      expect(await repo.getMediaById('m1'), isNull);
      expect(thumb!.existsSync(), isFalse);
      expect(original.existsSync(), isFalse);
      expect(source.existsSync(), isTrue, reason: 'never the original file');
    });

    test('a delete held for undo removes the thumbnail but keeps the store '
        'copies an undo would need', () async {
      final hash = 'ef${'3' * 62}';
      final source = writePng('reef.png');
      final item = photo('m1', source, hash: hash);
      await repo.createMedia(item);
      final scope = container();
      final thumb = await scope
          .read(localThumbnailCacheProvider)
          .generate(item, file: source);
      final original = await storeCopy(hash);

      await scope.read(mediaDeletionCoordinatorProvider).deleteMediaItems([
        item,
      ], holdRemoteDelete: true);

      expect(await repo.getMediaById('m1'), isNull);
      expect(thumb!.existsSync(), isFalse);
      expect(original.existsSync(), isTrue);
    });

    test('store copies stay while another photo has the same '
        'content', () async {
      final hash = 'cd${'2' * 62}';
      final source = writePng('reef.png');
      await repo.createMedia(photo('m1', source, hash: hash));
      await repo.createMedia(photo('m2', source, hash: hash));
      final original = await storeCopy(hash);

      await container()
          .read(mediaDeletionCoordinatorProvider)
          .deleteMedia('m1');

      expect(await repo.getMediaById('m2'), isNotNull);
      expect(original.existsSync(), isTrue);
    });
  });

  test('the repository provider is the one these tests seed', () {
    // Guards the premise of the groups above: rows created through [repo]
    // are the rows the providers read and write.
    expect(container().read(mediaRepositoryProvider), isA<MediaRepository>());
  });
}
