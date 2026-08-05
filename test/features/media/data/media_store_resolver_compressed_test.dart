import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/data/resolvers/media_store_resolver.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import '../../../helpers/in_memory_media_object_store.dart';

void main() {
  late LocalCacheDatabase db;
  late Directory root;
  late InMemoryMediaObjectStore store;
  late MediaCacheStore cache;
  late MediaStoreResolver resolver;

  setUp(() async {
    db = LocalCacheDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('msr_compressed');
    store = InMemoryMediaObjectStore();
    cache = MediaCacheStore(database: db, root: root);
    resolver = MediaStoreResolver(store: store, cache: cache);
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  MediaItem item({
    required String hash,
    DateTime? remoteUploadedAt,
    DateTime? remoteCompressedUploadedAt,
  }) => MediaItem(
    id: 'm1',
    mediaType: MediaType.photo,
    originalFilename: 'shot.jpg',
    takenAt: DateTime(2026, 1, 1),
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    contentHash: hash,
    remoteUploadedAt: remoteUploadedAt,
    remoteCompressedUploadedAt: remoteCompressedUploadedAt,
  );

  test('serves the rendition when only a rendition exists', () async {
    store.objects[StoreKeys.renditionKey('h1', ext: 'jpg')] = [1, 2, 3, 4];
    final data = await resolver.tryResolveRemote(
      item(hash: 'h1', remoteCompressedUploadedAt: DateTime(2026, 2, 2)),
      thumbnail: false,
    );
    expect(data, isA<FileData>());
    expect(await (data as FileData).file.readAsBytes(), [1, 2, 3, 4]);
  });

  test('prefers the hash-verified original over the rendition', () async {
    final f = File('${root.path}/orig.bin');
    await f.writeAsBytes([9, 9, 9]);
    final digest = await sha256OfFile(f);
    store.objects[StoreKeys.objectKey(digest.hash, extension: 'jpg')] = [
      9,
      9,
      9,
    ];
    store.objects[StoreKeys.renditionKey(digest.hash, ext: 'jpg')] = [1, 1, 1];

    final data = await resolver.tryResolveRemote(
      item(
        hash: digest.hash,
        remoteUploadedAt: DateTime(2026, 2, 2),
        remoteCompressedUploadedAt: DateTime(2026, 2, 2),
      ),
      thumbnail: false,
    );
    expect(await (data as FileData).file.readAsBytes(), [9, 9, 9]);
  });

  test(
    'a re-uploaded rendition (advanced stamp) invalidates the cache',
    () async {
      store.objects[StoreKeys.renditionKey('h3', ext: 'jpg')] = [1, 1, 1];
      final first = await resolver.tryResolveRemote(
        item(hash: 'h3', remoteCompressedUploadedAt: DateTime(2020, 1, 1)),
        thumbnail: false,
      );
      expect(await (first as FileData).file.readAsBytes(), [1, 1, 1]);

      // Overwrite the store object (a re-upload at a new level).
      store.objects[StoreKeys.renditionKey('h3', ext: 'jpg')] = [2, 2, 2];
      final refetched = await resolver.tryResolveRemote(
        item(
          hash: 'h3',
          remoteCompressedUploadedAt: DateTime.now().add(
            const Duration(days: 1),
          ),
        ),
        thumbnail: false,
      );
      expect(await (refetched as FileData).file.readAsBytes(), [2, 2, 2]);
    },
  );
}
