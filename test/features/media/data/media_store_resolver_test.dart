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

void main() {
  late LocalCacheDatabase db;
  late Directory root;
  late InMemoryMediaObjectStore store;
  late MediaCacheStore cache;
  late MediaStoreResolver resolver;

  setUp(() async {
    db = LocalCacheDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('msr_test');
    store = InMemoryMediaObjectStore();
    cache = MediaCacheStore(database: db, root: root);
    resolver = MediaStoreResolver(store: store, cache: cache);
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  MediaItem item({String? hash, DateTime? uploadedAt}) => MediaItem(
    id: 'm1',
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.platformGallery,
    platformAssetId: 'gone-from-this-device',
    originalFilename: 'reef.jpg',
    takenAt: DateTime(2026),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    contentHash: hash,
    remoteUploadedAt: uploadedAt,
  );

  test('returns null without a confirmation stamp', () async {
    expect(
      await resolver.tryResolveRemote(item(hash: 'a' * 64), thumbnail: false),
      isNull,
    );
    expect(
      await resolver.tryResolveRemote(
        item(uploadedAt: DateTime(2026)),
        thumbnail: false,
      ),
      isNull,
    );
  });

  test('downloads, hash-verifies, caches, and returns FileData', () async {
    final bytes = 'submersion'.codeUnits;
    final tmp = File('${root.path}/seed');
    await tmp.writeAsBytes(bytes, flush: true);
    final digest = await sha256OfFile(tmp);
    store.objects[StoreKeys.objectKey(digest.hash, extension: 'jpg')] = bytes;

    final data = await resolver.tryResolveRemote(
      item(hash: digest.hash, uploadedAt: DateTime(2026)),
      thumbnail: false,
    );
    expect(data, isA<FileData>());
    expect(await (data! as FileData).file.readAsBytes(), bytes);

    // Second resolve is a pure cache hit even with an empty store.
    store.objects.clear();
    final again = await resolver.tryResolveRemote(
      item(hash: digest.hash, uploadedAt: DateTime(2026)),
      thumbnail: false,
    );
    expect(again, isA<FileData>());
  });

  test('hash mismatch is rejected and not cached', () async {
    final wrongHash = 'f' * 64;
    store.objects[StoreKeys.objectKey(wrongHash, extension: 'jpg')] =
        'tampered'.codeUnits;
    final data = await resolver.tryResolveRemote(
      item(hash: wrongHash, uploadedAt: DateTime(2026)),
      thumbnail: false,
    );
    expect(data, isNull);
    expect(await cache.get(wrongHash, MediaCacheKind.original), isNull);
  });

  test('store errors degrade to null', () async {
    store.failNextWith = Exception('boom');
    final data = await resolver.tryResolveRemote(
      item(hash: 'a' * 64, uploadedAt: DateTime(2026)),
      thumbnail: false,
    );
    expect(data, isNull);
  });

  test('thumbnail requests serve the thumb object and cache it under the '
      'thumb pool', () async {
    final thumbBytes = 'tiny-thumb'.codeUnits;
    final hash = 'a1${'9' * 62}';
    store.objects[StoreKeys.thumbKey(hash)] = thumbBytes;

    final data = await resolver.tryResolveRemote(
      item(
        hash: hash,
        uploadedAt: DateTime(2026),
      ).copyWith(remoteThumbUploadedAt: DateTime(2026)),
      thumbnail: true,
    );
    expect(data, isA<FileData>());
    expect(await (data! as FileData).file.readAsBytes(), thumbBytes);
    expect(await cache.get(hash, MediaCacheKind.thumb), isNotNull);
    expect(await cache.get(hash, MediaCacheKind.original), isNull);
  });

  test('a thumbnail resolves when only the thumb stamp is present (thumbs '
      'upload before originals)', () async {
    final thumbBytes = 'early-thumb'.codeUnits;
    final hash = 'b2${'8' * 62}';
    store.objects[StoreKeys.thumbKey(hash)] = thumbBytes;

    final earlyRow = item(
      hash: hash,
    ).copyWith(remoteThumbUploadedAt: DateTime(2026));
    expect(earlyRow.remoteUploadedAt, isNull);

    final thumb = await resolver.tryResolveRemote(earlyRow, thumbnail: true);
    expect(thumb, isA<FileData>());
    expect(await (thumb! as FileData).file.readAsBytes(), thumbBytes);

    // The original is not confirmed yet, so a full-size request stays null.
    expect(await resolver.tryResolveRemote(earlyRow, thumbnail: false), isNull);
  });

  test('failed fetches leave nothing behind in the staging '
      'directory', () async {
    final stagingDir = Directory('${root.path}/staging');

    // A download dying mid-transfer leaves a partial staging file...
    store.partialGetThenFail = 'half-of-the-obj'.codeUnits;
    expect(
      await resolver.tryResolveRemote(
        item(hash: 'a' * 64, uploadedAt: DateTime(2026)),
        thumbnail: false,
      ),
      isNull,
    );

    // ...as does a completed download that fails hash verification...
    final wrongHash = 'f' * 64;
    store.objects[StoreKeys.objectKey(wrongHash, extension: 'jpg')] =
        'tampered'.codeUnits;
    expect(
      await resolver.tryResolveRemote(
        item(hash: wrongHash, uploadedAt: DateTime(2026)),
        thumbnail: false,
      ),
      isNull,
    );

    // ...and a thumb download dying mid-transfer.
    store.partialGetThenFail = 'half-of-the-thumb'.codeUnits;
    expect(
      await resolver.tryResolveRemote(
        item(hash: 'c' * 64).copyWith(remoteThumbUploadedAt: DateTime(2026)),
        thumbnail: true,
      ),
      isNull,
    );

    expect(
      stagingDir.existsSync() ? stagingDir.listSync() : <FileSystemEntity>[],
      isEmpty,
    );
  });

  test('thumbnail request falls back to the original when no thumb was '
      'uploaded', () async {
    final bytes = 'submersion'.codeUnits;
    final tmp = File('${root.path}/seed2');
    await tmp.writeAsBytes(bytes, flush: true);
    final digest = await sha256OfFile(tmp);
    store.objects[StoreKeys.objectKey(digest.hash, extension: 'jpg')] = bytes;

    final data = await resolver.tryResolveRemote(
      item(hash: digest.hash, uploadedAt: DateTime(2026)),
      thumbnail: true, // no remoteThumbUploadedAt on the item
    );
    expect(data, isA<FileData>());
    expect(await (data! as FileData).file.readAsBytes(), bytes);
  });
}
