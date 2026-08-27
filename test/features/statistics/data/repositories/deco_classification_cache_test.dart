import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/features/statistics/data/repositories/deco_classification_cache.dart';

void main() {
  late LocalCacheDatabase db;
  late DecoClassificationCacheRepository repo;

  setUp(() {
    db = LocalCacheDatabase(NativeDatabase.memory());
    LocalCacheDatabaseService.instance.setTestDatabase(db);
    repo = DecoClassificationCacheRepository();
  });

  tearDown(() async {
    await db.close();
    LocalCacheDatabaseService.instance.resetForTesting();
  });

  test('returns nothing before anything is cached', () async {
    expect(await repo.getEntries({'a', 'b'}), isEmpty);
  });

  test('round-trips a classification with its fingerprint', () async {
    await repo.put('a', hadDeco: true, inputsHash: 'hash-1');
    await repo.put('b', hadDeco: false, inputsHash: 'hash-2');

    final entries = await repo.getEntries({'a', 'b'});

    expect(entries['a']?.hadDeco, isTrue);
    expect(entries['a']?.inputsHash, 'hash-1');
    expect(entries['b']?.hadDeco, isFalse);
    expect(entries['b']?.inputsHash, 'hash-2');
  });

  test('reads dives with differing fingerprints in one call', () async {
    // The whole point of returning the hash instead of filtering on it: each
    // dive carries its own fingerprint, so one query serves the whole batch.
    await repo.put('a', hadDeco: true, inputsHash: 'hash-1');
    await repo.put('b', hadDeco: false, inputsHash: 'hash-2');

    expect((await repo.getEntries({'a', 'b'})).keys, containsAll(['a', 'b']));
  });

  test('re-putting the same dive replaces the entry', () async {
    await repo.put('a', hadDeco: true, inputsHash: 'hash-1');
    await repo.put('a', hadDeco: false, inputsHash: 'hash-2');

    final entries = await repo.getEntries({'a'});

    expect(entries, hasLength(1));
    expect(entries['a']?.hadDeco, isFalse);
    expect(entries['a']?.inputsHash, 'hash-2');
  });

  test('only the requested dives come back', () async {
    await repo.put('a', hadDeco: true, inputsHash: 'hash-1');
    await repo.put('b', hadDeco: true, inputsHash: 'hash-1');

    expect((await repo.getEntries({'a'})).keys, ['a']);
  });

  test('an empty request does not query', () async {
    expect(await repo.getEntries(const {}), isEmpty);
  });

  test('clear removes every entry', () async {
    await repo.put('a', hadDeco: true, inputsHash: 'hash-1');
    await repo.clear();

    expect(await repo.getEntries({'a'}), isEmpty);
  });

  test('reads more ids than SQLite allows bound variables', () async {
    // Sized against the measured ceiling of the bundled engine, not the 999
    // that older references cite: an unchunked query survives 2500 ids and
    // only throws "too many SQL variables" past 32766. Verified this test
    // fails without the chunking in getEntries, so do not lower the count.
    // The caller would swallow that throw into a full recompute rather than
    // surfacing it, which is why this is covered.
    const count = 33000;
    for (var i = 0; i < count; i++) {
      await repo.put('d$i', hadDeco: i.isEven, inputsHash: 'hash-1');
    }

    final entries = await repo.getEntries({
      for (var i = 0; i < count; i++) 'd$i',
    });

    expect(entries, hasLength(count));
    expect(entries['d0']?.hadDeco, isTrue);
    expect(entries['d1']?.hadDeco, isFalse);
    expect(entries['d2499']?.hadDeco, isFalse);
  });
}
