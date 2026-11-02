import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/data/resolvers/media_store_resolver.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';

import '../../../helpers/in_memory_media_object_store.dart';

/// Issue #3996: the PDF's device overwrites a stored thumb at the same key
/// and moves the row's stamp. A device showing that thumb has only the stamp
/// to tell it the bytes it cached are the old ones.
void main() {
  const hash = 'h1';

  late LocalCacheDatabase db;
  late Directory root;
  late InMemoryMediaObjectStore store;
  late MediaCacheStore cache;
  late MediaStoreResolver resolver;

  setUp(() async {
    db = LocalCacheDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    root = await Directory.systemTemp.createTemp('msr_pdf_thumb');
    store = InMemoryMediaObjectStore();
    cache = MediaCacheStore(database: db, root: root);
    resolver = MediaStoreResolver(store: store, cache: cache);
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  MediaItem pdf(DateTime stamp, {String name = 'map.pdf'}) => MediaItem(
    id: 'm1',
    mediaType: MediaType.document,
    originalFilename: name,
    takenAt: DateTime(2026, 1, 1),
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    contentHash: hash,
    remoteThumbUploadedAt: stamp,
  );

  Future<List<int>> thumbBytes(MediaItem item) async {
    final data = await resolver.tryResolveRemote(item, thumbnail: true);
    return (data! as FileData).file.readAsBytes();
  }

  test('a moved stamp replaces the cached thumb', () async {
    store.objects[StoreKeys.thumbKey(hash)] = [1, 1, 1];
    expect(await thumbBytes(pdf(DateTime(2026, 2))), [1, 1, 1]);

    store.objects[StoreKeys.thumbKey(hash)] = [2, 2, 2];

    expect(await thumbBytes(pdf(DateTime(2026, 11))), [2, 2, 2]);
  });

  test('an unmoved stamp is answered from the cache', () async {
    store.objects[StoreKeys.thumbKey(hash)] = [1, 1, 1];
    await thumbBytes(pdf(DateTime(2026, 2)));
    store.objects.clear();

    final data = await resolver.tryResolveRemote(
      pdf(DateTime(2026, 2)),
      thumbnail: true,
    );

    expect(data!.servedFrom, ServedFrom.storeCache);
    expect(await (data as FileData).file.readAsBytes(), [1, 1, 1]);
  });

  test('a thumb cached before stamps were recorded is fetched again', () async {
    final old = File(p.join(root.path, 'old.jpg'))..writeAsBytesSync([1, 1, 1]);
    await cache.put(hash, MediaCacheKind.thumb, old, extension: 'jpg');
    store.objects[StoreKeys.thumbKey(hash)] = [2, 2, 2];

    expect(await thumbBytes(pdf(DateTime(2026, 2))), [2, 2, 2]);
  });

  test('a photo thumb is not checked against its stamp', () async {
    final photo = pdf(DateTime(2026, 2)).copyWith(mediaType: MediaType.photo);
    final old = File(p.join(root.path, 'old.jpg'))..writeAsBytesSync([1, 1, 1]);
    await cache.put(hash, MediaCacheKind.thumb, old, extension: 'jpg');

    expect(await thumbBytes(photo), [1, 1, 1]);
  });
}
