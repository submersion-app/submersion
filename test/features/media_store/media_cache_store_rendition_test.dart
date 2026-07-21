import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';

void main() {
  late LocalCacheDatabase db;
  late Directory root;
  late MediaCacheStore cache;

  setUp(() async {
    db = LocalCacheDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('cache_rendition');
    cache = MediaCacheStore(database: db, root: root);
  });
  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  Future<File> staged(List<int> bytes) async {
    final f = await cache.stagingFile();
    await f.writeAsBytes(bytes, flush: true);
    return f;
  }

  test(
    'rendition pool stores and retrieves separately from original',
    () async {
      await cache.put('h1', MediaCacheKind.rendition, await staged([1, 2, 3]));
      final got = await cache.get('h1', MediaCacheKind.rendition);
      expect(got, isNotNull);
      expect(await cache.get('h1', MediaCacheKind.original), isNull);
    },
  );

  test('get with freshAfter later than the cache time is a miss', () async {
    await cache.put('h2', MediaCacheKind.rendition, await staged([9]));
    final stale = await cache.get(
      'h2',
      MediaCacheKind.rendition,
      freshAfter: DateTime.now().add(const Duration(days: 1)),
    );
    expect(stale, isNull);
    // The stale entry was evicted, so a plain get now also misses.
    expect(await cache.get('h2', MediaCacheKind.rendition), isNull);
  });
}
