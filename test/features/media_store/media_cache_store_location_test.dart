import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';

/// The store with its pools and its scratch directories apart, as on a phone
/// (issue #3341), and its index after the OS has emptied the cache directory.
void main() {
  late LocalCacheDatabase db;
  late Directory base;
  late Directory pools;
  late Directory scratch;
  late MediaCacheStore cache;

  setUp(() async {
    db = LocalCacheDatabase(NativeDatabase.memory());
    base = await Directory.systemTemp.createTemp('media_cache_location_test');
    pools = Directory(p.join(base.path, 'pools'));
    scratch = Directory(p.join(base.path, 'scratch'));
    await pools.create();
    await scratch.create();
    cache = MediaCacheStore(
      database: db,
      root: pools,
      scratchRoot: scratch,
      thumbsCapBytes: 50,
    );
  });

  tearDown(() async {
    await db.close();
    await base.delete(recursive: true);
  });

  String hash(String prefix) => prefix.padRight(64, '0');

  Future<File> put(String key, MediaCacheKind kind, int bytes) async {
    final staged = await cache.stagingFile();
    await staged.writeAsBytes(List<int>.filled(bytes, 1), flush: true);
    return cache.put(key, kind, staged);
  }

  Directory pool(String name) => Directory(p.join(pools.path, name));

  group('two roots', () {
    test('staging and transcode files live under the scratch root', () async {
      final staged = await cache.stagingFile();
      final transcoded = await cache.transcodeFile(hash('ab'), 'low');

      expect(p.isWithin(p.join(scratch.path, 'staging'), staged.path), isTrue);
      expect(
        p.isWithin(p.join(scratch.path, 'transcode'), transcoded.path),
        isTrue,
      );
    });

    test('without a scratch root they stay under root', () async {
      final single = MediaCacheStore(database: db, root: pools);

      final staged = await single.stagingFile();

      expect(p.isWithin(p.join(pools.path, 'staging'), staged.path), isTrue);
    });

    test('deleteTranscodeArtifacts looks under the scratch root', () async {
      final transcoded = await cache.transcodeFile(hash('ab'), 'low');
      await transcoded.writeAsString('done');

      await cache.deleteTranscodeArtifacts(hash('ab'));

      expect(await transcoded.exists(), isFalse);
    });

    test('put moves a staged file across the two roots', () async {
      final key = hash('ab');

      final stored = await put(key, MediaCacheKind.thumb, 3);

      expect(
        stored.path,
        p.join(pools.path, 'thumbs', 'ab', key),
        reason: 'the relative path stays in the form the index already holds',
      );
      expect(await stored.length(), 3);
      expect(await cache.totalBytes(MediaCacheKind.thumb), 3);
    });

    test('clear leaves the scratch root alone', () async {
      await put(hash('ab'), MediaCacheKind.thumb, 3);
      final staged = await cache.stagingFile();
      await staged.writeAsString('in flight');
      final transcoded = await cache.transcodeFile(hash('cd'), 'low');
      await transcoded.writeAsString('done');

      await cache.clear(MediaCacheKind.thumb);

      expect(await staged.exists(), isTrue);
      expect(await transcoded.exists(), isTrue);
    });
  });

  group('a pool whose directory has gone', () {
    test('reads as empty and loses its rows', () async {
      await put(hash('ab'), MediaCacheKind.thumb, 3);

      await pool('thumbs').delete(recursive: true);

      expect(await cache.totalBytes(MediaCacheKind.thumb), 0);
      expect(await db.select(db.mediaCacheEntries).get(), isEmpty);
    });

    test('takes only its own rows with it', () async {
      await put(hash('ab'), MediaCacheKind.thumb, 3);
      await put(hash('cd'), MediaCacheKind.original, 7);

      await pool('thumbs').delete(recursive: true);

      expect(await cache.totalBytes(MediaCacheKind.thumb), 0);
      expect(await cache.totalBytes(MediaCacheKind.original), 7);
    });

    test('is noticed by a put, which recreates the directory', () async {
      // The first thing to touch a purged pool is usually a put: a tile
      // misses and makes its thumbnail again. Recreating the directory first
      // would hide the purge from every later read of the total.
      await put(hash('ab'), MediaCacheKind.thumb, 20);
      await pool('thumbs').delete(recursive: true);

      final stored = await put(hash('cd'), MediaCacheKind.thumb, 10);

      expect(await cache.totalBytes(MediaCacheKind.thumb), 10);
      expect(await stored.exists(), isTrue);
    });

    test('evicts nothing real when the pool had been full', () async {
      await put(hash('ab'), MediaCacheKind.thumb, 30);
      await put(hash('cd'), MediaCacheKind.thumb, 20);
      await pool('thumbs').delete(recursive: true);

      final first = await put(hash('ef'), MediaCacheKind.thumb, 30);
      final second = await put(hash('12'), MediaCacheKind.thumb, 20);

      expect(await first.exists(), isTrue);
      expect(await second.exists(), isTrue);
      expect(await cache.totalBytes(MediaCacheKind.thumb), 50);
    });

    test('leaves a pool whose directory exists alone', () async {
      final key = hash('ab');
      final stored = await put(key, MediaCacheKind.thumb, 3);
      await stored.delete();

      expect(await cache.totalBytes(MediaCacheKind.thumb), 3);
      expect(await db.select(db.mediaCacheEntries).get(), hasLength(1));
    });
  });

  group('dropMissingEntries', () {
    test('removes only rows whose file has gone, in every pool', () async {
      final deadThumb = await put(hash('ab'), MediaCacheKind.thumb, 1);
      await put(hash('cd'), MediaCacheKind.thumb, 2);
      final deadOriginal = await put(hash('ab'), MediaCacheKind.original, 3);
      await put(hash('ef'), MediaCacheKind.original, 4);
      final deadRendition = await put(hash('ab'), MediaCacheKind.rendition, 5);
      await put(hash('12'), MediaCacheKind.rendition, 6);
      await deadThumb.delete();
      await deadOriginal.delete();
      await deadRendition.delete();

      final dropped = await cache.dropMissingEntries();

      expect(dropped, 3);
      expect(await cache.totalBytes(MediaCacheKind.thumb), 2);
      expect(await cache.totalBytes(MediaCacheKind.original), 4);
      expect(await cache.totalBytes(MediaCacheKind.rendition), 6);
    });

    test('clears a pool emptied with its directory left behind', () async {
      // What a whole-directory check cannot see, and what low-storage trimming
      // can leave: every file gone and the directories still there.
      final first = await put(hash('ab'), MediaCacheKind.thumb, 1);
      final second = await put(hash('cd'), MediaCacheKind.thumb, 2);
      await first.delete();
      await second.delete();

      await cache.dropMissingEntries();

      expect(await cache.totalBytes(MediaCacheKind.thumb), 0);
    });

    test('visits every row across pages while deleting from them', () async {
      final keys = ['10', '20', '30', '40', '50'].map(hash).toList();
      final files = [
        for (final key in keys) await put(key, MediaCacheKind.original, 1),
      ];
      await files[0].delete();
      await files[1].delete();
      await files[3].delete();

      final dropped = await cache.dropMissingEntries(pageSize: 2);

      expect(dropped, 3);
      expect(await cache.totalBytes(MediaCacheKind.original), 2);
    });

    test('leaves everything alone when no file is missing', () async {
      await put(hash('ab'), MediaCacheKind.thumb, 1);

      expect(await cache.dropMissingEntries(), 0);
      expect(await cache.totalBytes(MediaCacheKind.thumb), 1);
    });
  });
}
