import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';

/// Counts every statement that reaches the database, so a test can assert
/// that a code path ran none.
class _StatementCounter extends QueryInterceptor {
  int statements = 0;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    statements++;
    return super.runSelect(executor, statement, args);
  }

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    statements++;
    return super.runUpdate(executor, statement, args);
  }

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    statements++;
    return super.runInsert(executor, statement, args);
  }

  @override
  Future<int> runDelete(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    statements++;
    return super.runDelete(executor, statement, args);
  }

  @override
  Future<void> runCustom(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    statements++;
    return super.runCustom(executor, statement, args);
  }

  @override
  Future<void> runBatched(
    QueryExecutor executor,
    BatchedStatements statements,
  ) {
    this.statements++;
    return super.runBatched(executor, statements);
  }
}

void main() {
  late LocalCacheDatabase db;
  late Directory root;
  late MediaCacheStore cache;
  late _StatementCounter counter;

  setUp(() async {
    counter = _StatementCounter();
    db = LocalCacheDatabase(
      NativeDatabase.memory(
        setup: registerAppSqlFunctions,
      ).interceptWith(counter),
    );
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

  test(
    'an idle over-cap store settles when evictIfNeeded runs alone',
    () async {
      // The gap this closes: the caps are enforced only inside put(), so the
      // next eviction needs a write. A store that went over cap and then went
      // idle stayed over cap indefinitely, waiting on a download that might
      // never come. Lowering the cap under a settled store reproduces that
      // state without needing a write to create it.
      final a = 'aa${'1' * 62}';
      final b = 'bb${'2' * 62}';
      await cache.put(
        a,
        MediaCacheKind.original,
        await staged(List.filled(60, 1)),
      );
      // lastAccessedAt is millisecondsSinceEpoch and _evictPool orders by it
      // ascending, so two puts in the same millisecond leave the LRU order,
      // and therefore the victim, undefined. Same delay as the LRU test above.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await cache.put(
        b,
        MediaCacheKind.original,
        await staged(List.filled(30, 1)),
      );
      expect(await cache.totalBytes(MediaCacheKind.original), 90);

      final tightened = MediaCacheStore(
        database: db,
        root: root,
        originalsCapBytes: 50,
        thumbsCapBytes: 50,
      );

      // No put(), no writes of any kind: the pass runs on its own.
      await tightened.evictIfNeeded();

      expect(
        await tightened.totalBytes(MediaCacheKind.original),
        lessThanOrEqualTo(50),
      );
      expect(await tightened.get(a, MediaCacheKind.original), isNull);
      expect(await tightened.get(b, MediaCacheKind.original), isNotNull);
    },
  );

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

  // The index is keyed {contentHash, kind} and relativePath used to be a pure
  // function of that key, so an overwrite always rewrote the same path. Now
  // that the caller supplies the extension, two rows over identical bytes can
  // ask for different names (StoreKeys.extensionFor is explicitly not
  // injective over content -- photo.JPG and photo.jpeg -- and a video's name
  // can also fall back to its local path). The superseded file has to go:
  // nothing references it, and eviction only walks the index, so it would sit
  // on disk forever without counting against any cap.
  test('re-putting under a different extension leaves no untracked '
      'file', () async {
    final hash = 'cd${'4' * 62}';

    final first = await cache.put(
      hash,
      MediaCacheKind.original,
      await staged([1, 2, 3]),
      extension: 'jpg',
    );
    expect(await first.exists(), isTrue);

    final second = await cache.put(
      hash,
      MediaCacheKind.original,
      await staged([4, 5, 6]),
      extension: 'jpeg',
    );

    expect(second.path, isNot(first.path));
    expect(await second.exists(), isTrue);
    expect(
      await first.exists(),
      isFalse,
      reason: 'the superseded file must not linger untracked',
    );

    // The index agrees with what is on disk.
    final hit = await cache.get(hash, MediaCacheKind.original);
    expect(hit!.path, second.path);
    expect(await hit.readAsBytes(), [4, 5, 6]);

    final pool = Directory('${root.path}/originals/cd');
    expect(pool.listSync().whereType<File>().length, 1);
  });

  test('re-putting under the same extension still works', () async {
    final hash = 'ce${'3' * 62}';
    await cache.put(
      hash,
      MediaCacheKind.original,
      await staged([1]),
      extension: 'mp4',
    );
    final again = await cache.put(
      hash,
      MediaCacheKind.original,
      await staged([2]),
      extension: 'mp4',
    );
    expect(await again.exists(), isTrue);
    expect(await again.readAsBytes(), [2]);
  });

  // Issue #3337. A grid tile asks for its thumbnail on every scroll into
  // view, so the hit path may cost a stat and nothing else.
  group('thumbnail fast path', () {
    const pause = Duration(milliseconds: 5);

    Future<File> putThumb(String key, int size, {MediaCacheStore? into}) =>
        (into ?? cache).put(
          key,
          MediaCacheKind.thumb,
          File(p.join(root.path, 'src_$key'))
            ..writeAsBytesSync(List.filled(size, 7)),
          extension: 'jpg',
        );

    test('a hit runs no database statement', () async {
      final key = 'ab${'1' * 62}';
      final stored = await putThumb(key, 10);
      counter.statements = 0;

      final hit = await cache.peekThumb(key);

      expect(hit, isNotNull);
      expect(hit!.path, stored.path);
      expect(counter.statements, 0);
    });

    test('a key too short for the layout is a miss, not an error', () async {
      expect(await cache.peekThumb('a'), isNull);
      expect(await cache.peekThumb(''), isNull);
    });

    test('a miss is null and runs no database statement', () async {
      counter.statements = 0;
      expect(await cache.peekThumb('cd${'2' * 62}'), isNull);
      expect(counter.statements, 0);
    });

    test('a hit counts as a use once eviction runs, from any store on the '
        'same database', () async {
      final a = 'aa${'1' * 62}';
      final b = 'bb${'2' * 62}';
      final c = 'cc${'3' * 62}';
      await putThumb(a, 20);
      await Future<void>.delayed(pause);
      await putThumb(b, 20);
      await Future<void>.delayed(pause);
      // Without the touch A is the least recently used.
      expect(await cache.peekThumb(a), isNotNull);
      await Future<void>.delayed(pause);

      // The upload runtime, the probe resolver and the thumbnail cache each
      // build their own store over the one database.
      final other = MediaCacheStore(
        database: db,
        root: root,
        originalsCapBytes: 100,
        thumbsCapBytes: 50,
      );
      await putThumb(c, 20, into: other);

      expect(await cache.peekThumb(a), isNotNull);
      expect(await cache.peekThumb(b), isNull);
      expect(await cache.peekThumb(c), isNotNull);
    });

    test('touches are written as one batch', () async {
      final keys = [for (var i = 0; i < 5; i++) 'a$i${'4' * 62}'];
      final roomy = MediaCacheStore(
        database: db,
        root: root,
        thumbsCapBytes: 1000,
      );
      for (final key in keys) {
        await putThumb(key, 5, into: roomy);
      }
      for (final key in keys) {
        await roomy.peekThumb(key);
      }
      counter.statements = 0;

      await roomy.flushTouches();

      expect(counter.statements, 1);
      // Nothing left to write.
      await roomy.flushTouches();
      expect(counter.statements, 1);
    });

    test('remove deletes the file and its index entry', () async {
      final key = 'ef${'5' * 62}';
      final stored = await putThumb(key, 10);

      await cache.remove(key, MediaCacheKind.thumb);

      expect(await stored.exists(), isFalse);
      expect(await cache.peekThumb(key), isNull);
      expect(await cache.get(key, MediaCacheKind.thumb), isNull);
      expect(await cache.totalBytes(MediaCacheKind.thumb), 0);
    });

    test('remove of an entry that is not there is a no-op', () async {
      await cache.remove('0a${'6' * 62}', MediaCacheKind.thumb);
    });

    test('the thumbnail cap is read when eviction runs, so a changed '
        'setting applies to a store already built', () async {
      var cap = 1000;
      final adjustable = MediaCacheStore(
        database: db,
        root: root,
        thumbsCapSource: () => cap,
      );
      final a = 'a7${'7' * 62}';
      final b = 'b7${'7' * 62}';
      await putThumb(a, 40, into: adjustable);
      await Future<void>.delayed(pause);
      await putThumb(b, 40, into: adjustable);
      expect(await adjustable.totalBytes(MediaCacheKind.thumb), 80);

      cap = 50;
      await adjustable.evictIfNeeded();

      expect(await adjustable.peekThumb(a), isNull);
      expect(await adjustable.peekThumb(b), isNotNull);
    });
  });

  // Two thumbnails made at the same moment were staged at the same path,
  // because the name was a clock reading plus a counter that every store
  // started from zero, and a store is built per use. The later write won,
  // so one photo was filed under another's picture.
  test('staging files are unique across stores, whatever the clock '
      'says', () async {
    final paths = <String>{};
    for (var i = 0; i < 200; i++) {
      final fresh = MediaCacheStore(database: db, root: root);
      paths.add((await fresh.stagingFile()).path);
    }
    expect(paths, hasLength(200));
  });

  group('clear', () {
    Future<File> stored(String key, MediaCacheKind kind) async {
      final source = await staged([1, 2, 3]);
      return cache.put(key, kind, source, extension: 'jpg');
    }

    test('empties one pool, files and index, and leaves the others', () async {
      final thumbA = await stored('aa${'1' * 62}', MediaCacheKind.thumb);
      final thumbB = await stored('bb${'2' * 62}', MediaCacheKind.thumb);
      final original = await stored('cc${'3' * 62}', MediaCacheKind.original);

      await cache.clear(MediaCacheKind.thumb);

      expect(await thumbA.exists(), isFalse);
      expect(await thumbB.exists(), isFalse);
      expect(await cache.totalBytes(MediaCacheKind.thumb), 0);
      expect(await cache.peekThumb('aa${'1' * 62}'), isNull);
      expect(await original.exists(), isTrue);
      expect(await cache.totalBytes(MediaCacheKind.original), 3);
    });

    test('removes files the index does not know about', () async {
      final stray = File(p.join(root.path, 'thumbs', 'zz', 'stray.jpg'));
      await stray.parent.create(recursive: true);
      await stray.writeAsBytes([9]);

      await cache.clear(MediaCacheKind.thumb);

      expect(await stray.exists(), isFalse);
    });

    test('an empty pool clears without error, and takes new entries '
        'after', () async {
      await cache.clear(MediaCacheKind.thumb);
      final again = await stored('dd${'4' * 62}', MediaCacheKind.thumb);
      expect(await again.exists(), isTrue);
    });
  });
}
