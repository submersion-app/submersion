import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/data/resolvers/media_store_resolver.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';

import '../../../helpers/in_memory_media_object_store.dart';

/// These six stamps are the reason the provenance feature exists: the two
/// returns in each fetch method were the only place in the app that knew a
/// media-cache hit from a fresh cloud download, and all six discarded it.
///
/// Every test here EMPTIES the object store between the two reads. That is
/// the load-bearing step: without it a resolver that stamped storeCache
/// unconditionally would pass too, and the assertion would prove nothing.
void main() {
  late LocalCacheDatabase db;
  late Directory root;
  late InMemoryMediaObjectStore store;
  late MediaCacheStore cache;
  late MediaStoreResolver resolver;

  setUp(() async {
    db = LocalCacheDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('msr_prov');
    store = InMemoryMediaObjectStore();
    cache = MediaCacheStore(database: db, root: root);
    resolver = MediaStoreResolver(store: store, cache: cache);
  });

  tearDown(() async {
    await db.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  MediaItem item({
    String? hash,
    DateTime? uploadedAt,
    DateTime? thumbUploadedAt,
    DateTime? compressedUploadedAt,
    MediaType mediaType = MediaType.photo,
  }) => MediaItem(
    id: 'm1',
    mediaType: mediaType,
    sourceType: MediaSourceType.platformGallery,
    platformAssetId: 'gone-from-this-device',
    originalFilename: 'reef.jpg',
    takenAt: DateTime(2026),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    contentHash: hash,
    remoteUploadedAt: uploadedAt,
    remoteThumbUploadedAt: thumbUploadedAt,
    remoteCompressedUploadedAt: compressedUploadedAt,
  );

  test(
    'an original download is storeNetwork, the re-read is storeCache',
    () async {
      final bytes = 'submersion'.codeUnits;
      final tmp = File('${root.path}/seed');
      await tmp.writeAsBytes(bytes, flush: true);
      final digest = await sha256OfFile(tmp);
      store.objects[StoreKeys.objectKey(digest.hash, extension: 'jpg')] = bytes;

      final first = await resolver.tryResolveRemote(
        item(hash: digest.hash, uploadedAt: DateTime(2026)),
        thumbnail: false,
      );
      expect(first!.servedFrom, ServedFrom.storeNetwork);
      expect(first.servedTier, ServedTier.original);

      // Emptying the store proves the second read cannot have gone to network.
      store.objects.clear();

      final second = await resolver.tryResolveRemote(
        item(hash: digest.hash, uploadedAt: DateTime(2026)),
        thumbnail: false,
      );
      expect(second!.servedFrom, ServedFrom.storeCache);
      expect(second.servedTier, ServedTier.original);
    },
  );

  test('a thumb download is storeNetwork, the re-read is storeCache', () async {
    final hash = 'a' * 64;
    // Thumbs are derived bytes and are not hash-verified, so any content
    // works here.
    store.objects[StoreKeys.thumbKey(hash)] = 'thumb-bytes'.codeUnits;

    final first = await resolver.tryResolveRemote(
      item(hash: hash, thumbUploadedAt: DateTime(2026)),
      thumbnail: true,
    );
    expect(first!.servedFrom, ServedFrom.storeNetwork);
    expect(first.servedTier, ServedTier.thumbnail);

    store.objects.clear();

    final second = await resolver.tryResolveRemote(
      item(hash: hash, thumbUploadedAt: DateTime(2026)),
      thumbnail: true,
    );
    expect(second!.servedFrom, ServedFrom.storeCache);
    expect(second.servedTier, ServedTier.thumbnail);
  });

  test(
    'a rendition download is storeNetwork, the re-read is storeCache',
    () async {
      final hash = 'b' * 64;
      store.objects[StoreKeys.renditionKey(hash, ext: 'jpg')] =
          'rendition-bytes'.codeUnits;

      // No remoteUploadedAt: the compressed stamp alone must route here.
      final first = await resolver.tryResolveRemote(
        item(hash: hash, compressedUploadedAt: DateTime(2026)),
        thumbnail: false,
      );
      expect(first!.servedFrom, ServedFrom.storeNetwork);
      expect(first.servedTier, ServedTier.rendition);

      store.objects.clear();

      final second = await resolver.tryResolveRemote(
        item(hash: hash, compressedUploadedAt: DateTime(2026)),
        thumbnail: false,
      );
      expect(second!.servedFrom, ServedFrom.storeCache);
      expect(second.servedTier, ServedTier.rendition);
    },
  );
}
