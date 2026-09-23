import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/data/resolvers/media_store_resolver.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';

import '../../../../helpers/in_memory_media_object_store.dart';

/// Counts HEADs, and can fail the next one.
class _CountingStore extends InMemoryMediaObjectStore {
  final heads = <String>[];
  Exception? failNextHead;

  @override
  Future<StoreObjectInfo?> head(String key) {
    heads.add(key);
    final fail = failNextHead;
    if (fail != null) {
      failNextHead = null;
      throw fail;
    }
    return super.head(key);
  }
}

/// A foreign row can reach a device before its upload stamps do, or lose
/// them in a merge. The store the device is attached to may hold its bytes
/// anyway, and the probe is how the tile finds out (media sync program spec
/// 7.2).
void main() {
  late Directory root;
  late LocalCacheDatabase cacheDb;
  late _CountingStore store;
  late MediaStoreResolver resolver;
  final bytes = List<int>.generate(512, (i) => (i * 7) % 251);
  final hash = sha256.convert(bytes).toString();

  setUp(() async {
    root = await Directory.systemTemp.createTemp('store_probe');
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    store = _CountingStore();
    resolver = MediaStoreResolver(
      store: store,
      cache: MediaCacheStore(database: cacheDb, root: root),
    );
  });

  tearDown(() async {
    resolver.dispose();
    await cacheDb.close();
    if (root.existsSync()) await root.delete(recursive: true);
  });

  /// A row with no upload stamps at all, as a peer's row arrives before its
  /// stamps do.
  MediaItem unstamped({
    MediaType mediaType = MediaType.photo,
    String? contentHash,
    bool withHash = true,
  }) => MediaItem(
    id: 'm1',
    mediaType: mediaType,
    sourceType: MediaSourceType.localFile,
    localPath: p.join('elsewhere', 'reef.jpg'),
    originalFilename: 'reef.jpg',
    contentHash: withHash ? (contentHash ?? hash) : null,
    takenAt: DateTime(2026, 7, 1),
    createdAt: DateTime(2026, 7, 1),
    updatedAt: DateTime(2026, 7, 1),
  );

  String originalKey() =>
      StoreKeys.objectKey(hash, extension: StoreKeys.extensionFor('reef.jpg'));

  test('an unstamped row whose thumb is in the store is served', () async {
    store.objects[StoreKeys.thumbKey(hash)] = bytes;

    final served = await resolver.tryResolveProbed(
      unstamped(),
      thumbnail: true,
    );

    expect(served, isA<FileData>());
  });

  test('with no thumb, a thumbnail is served from the original', () async {
    store.objects[originalKey()] = bytes;

    final served = await resolver.tryResolveProbed(
      unstamped(),
      thumbnail: true,
    );

    expect(served, isA<FileData>());
    expect(store.heads, [StoreKeys.thumbKey(hash), originalKey()]);
  });

  test('a full view probes and serves the original', () async {
    store.objects[originalKey()] = bytes;

    final served = await resolver.tryResolveProbed(
      unstamped(),
      thumbnail: false,
    );

    expect(served, isA<FileData>());
    expect(store.heads, [originalKey()]);
  });

  // A grid redraws its tiles constantly. Absence is remembered, so a row
  // the store does not hold costs one HEAD per session, not one per frame.
  test('an absent object is asked about once', () async {
    expect(
      await resolver.tryResolveProbed(unstamped(), thumbnail: false),
      isNull,
    );
    expect(
      await resolver.tryResolveProbed(unstamped(), thumbnail: false),
      isNull,
    );

    expect(store.heads, [originalKey()]);
  });

  // A failed HEAD says nothing about the object (offline, a blip), so it
  // is not remembered as absent.
  test('a probe that failed is asked again', () async {
    store.objects[originalKey()] = bytes;
    store.failNextHead = const MediaStoreException(
      'offline',
      kind: MediaStoreErrorKind.transient,
    );

    expect(
      await resolver.tryResolveProbed(unstamped(), thumbnail: false),
      isNull,
    );
    expect(
      await resolver.tryResolveProbed(unstamped(), thumbnail: false),
      isA<FileData>(),
    );
  });

  // A video's original is a video: it can only draw as the movie
  // placeholder, so a thumbnail never costs its download, or its HEAD.
  test('a video thumbnail never falls back to the original', () async {
    store.objects[originalKey()] = bytes;

    final served = await resolver.tryResolveProbed(
      unstamped(mediaType: MediaType.video),
      thumbnail: true,
    );

    expect(served, isNull);
    expect(store.heads, [StoreKeys.thumbKey(hash)]);
  });

  test('a row with no content hash is not probed', () async {
    final served = await resolver.tryResolveProbed(
      unstamped(withHash: false),
      thumbnail: true,
    );

    expect(served, isNull);
    expect(store.heads, isEmpty);
  });
}
