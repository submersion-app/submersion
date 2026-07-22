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

  test('freshAfter newer than the cached source version is a miss', () async {
    final v1 = DateTime.now();
    await cache.put(
      'h2',
      MediaCacheKind.rendition,
      await staged([9]),
      sourceVersion: v1.millisecondsSinceEpoch,
    );
    // A later overwrite stamp than the version we cached invalidates it.
    final stale = await cache.get(
      'h2',
      MediaCacheKind.rendition,
      freshAfter: v1.add(const Duration(days: 1)),
    );
    expect(stale, isNull);
    // The stale entry was evicted, so a plain get now also misses.
    expect(await cache.get('h2', MediaCacheKind.rendition), isNull);
  });

  test('freshAfter at or below the cached source version is fresh', () async {
    final version = DateTime.now().add(const Duration(days: 10));
    await cache.put(
      'h3',
      MediaCacheKind.rendition,
      await staged([7]),
      sourceVersion: version.millisecondsSinceEpoch,
    );
    // freshAfter is later than the local wall clock (createdAt == now) but not
    // later than the authoritative source version we cached. The old
    // createdAt-based check would wrongly evict here; the token-based check
    // keeps it -- proving clock skew can't strand a valid rendition.
    final fresh = await cache.get(
      'h3',
      MediaCacheKind.rendition,
      freshAfter: DateTime.now().add(const Duration(days: 1)),
    );
    expect(fresh, isNotNull);
  });

  test(
    'rendition cached without a source version is treated as stale',
    () async {
      // Legacy pre-v5 entries have a null sourceVersion; any freshness check
      // must refetch rather than trust unverifiable bytes.
      await cache.put('h4', MediaCacheKind.rendition, await staged([5]));
      final stale = await cache.get(
        'h4',
        MediaCacheKind.rendition,
        freshAfter: DateTime.now(),
      );
      expect(stale, isNull);
    },
  );
}
