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
    root = await Directory.systemTemp.createTemp('media_cache_test');
    cache = MediaCacheStore(
      database: db,
      root: root,
      originalsCapBytes: 100,
      thumbsCapBytes: 50,
    );
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

  test('put then get round-trips and moves the staging file', () async {
    final hash = 'ab${'0' * 62}';
    final src = await staged([1, 2, 3]);
    final cached = await cache.put(hash, MediaCacheKind.original, src);
    expect(await cached.readAsBytes(), [1, 2, 3]);
    expect(await src.exists(), isFalse);

    final hit = await cache.get(hash, MediaCacheKind.original);
    expect(hit, isNotNull);
    expect(hit!.path, cached.path);
    expect(await cache.get(hash, MediaCacheKind.thumb), isNull);
    expect(await cache.totalBytes(MediaCacheKind.original), 3);
  });

  test('put is idempotent when the destination already exists (duplicate '
      'rows sharing a hash, concurrent resolves)', () async {
    final hash = 'cd${'1' * 62}';
    final first = await cache.put(
      hash,
      MediaCacheKind.original,
      await staged([1, 2, 3]),
    );
    final second = await cache.put(
      hash,
      MediaCacheKind.original,
      await staged([1, 2, 3]),
    );
    expect(second.path, first.path);
    expect(await second.readAsBytes(), [1, 2, 3]);
    expect(await cache.totalBytes(MediaCacheKind.original), 3);
  });

  test('eviction removes least-recently-used entries above the cap', () async {
    // put() evicts eagerly after each write, so build the LRU order BEFORE
    // the overflowing put: A, B inserted (80 <= 100), A touched so B is
    // LRU, then C (120 > 100) triggers eviction of B during its put.
    final a = 'aa${'1' * 62}';
    final b = 'bb${'2' * 62}';
    final c = 'cc${'3' * 62}';
    await cache.put(
      a,
      MediaCacheKind.original,
      await staged(List.filled(40, 1)),
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await cache.put(
      b,
      MediaCacheKind.original,
      await staged(List.filled(40, 2)),
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await cache.get(a, MediaCacheKind.original);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await cache.put(
      c,
      MediaCacheKind.original,
      await staged(List.filled(40, 3)),
    );

    expect(
      await cache.totalBytes(MediaCacheKind.original),
      lessThanOrEqualTo(100),
    );
    expect(await cache.get(b, MediaCacheKind.original), isNull);
    expect(await cache.get(a, MediaCacheKind.original), isNotNull);
    expect(await cache.get(c, MediaCacheKind.original), isNotNull);
  });

  test('get self-heals when the file vanished behind the index', () async {
    final hash = 'dd${'4' * 62}';
    final cached = await cache.put(
      hash,
      MediaCacheKind.original,
      await staged([5]),
    );
    await cached.delete();
    expect(await cache.get(hash, MediaCacheKind.original), isNull);
  });

  test('thumb pool evicts independently of originals', () async {
    final bigOriginal = 'ee${'5' * 62}';
    await cache.put(
      bigOriginal,
      MediaCacheKind.original,
      await staged(List.filled(90, 1)),
    );
    final thumbA = 'ff${'6' * 62}';
    final thumbB = 'a1${'7' * 62}';
    await cache.put(
      thumbA,
      MediaCacheKind.thumb,
      await staged(List.filled(30, 2)),
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await cache.put(
      thumbB,
      MediaCacheKind.thumb,
      await staged(List.filled(30, 3)),
    );

    // Thumbs cap is 50: thumbA (LRU) must be gone, the original untouched.
    expect(await cache.get(thumbA, MediaCacheKind.thumb), isNull);
    expect(await cache.get(thumbB, MediaCacheKind.thumb), isNotNull);
    expect(await cache.get(bigOriginal, MediaCacheKind.original), isNotNull);
  });
}
