import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/features/insights/data/repositories/vertical_distance_cache.dart';

void main() {
  late LocalCacheDatabase db;
  late VerticalDistanceCacheRepository repo;

  setUp(() {
    db = LocalCacheDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    LocalCacheDatabaseService.instance.setTestDatabase(db);
    repo = VerticalDistanceCacheRepository();
  });

  tearDown(() async {
    await db.close();
    LocalCacheDatabaseService.instance.resetForTesting();
  });

  test('returns nothing before anything is cached', () async {
    expect(await repo.getEntries({'a', 'b'}), isEmpty);
    expect(await repo.getEntries({}), isEmpty);
  });

  test('round-trips each dive\'s figure with its fingerprint', () async {
    await repo.putAll({
      'a': (meters: 20.5, inputsHash: 'v1|x'),
      'b': (meters: 36, inputsHash: 'v1|y'),
    });

    final entries = await repo.getEntries({'a', 'b', 'c'});

    expect(entries.keys, unorderedEquals(['a', 'b']));
    expect(entries['a'], (meters: 20.5, inputsHash: 'v1|x'));
    expect(entries['b'], (meters: 36.0, inputsHash: 'v1|y'));
  });

  test('a second write for the same dive replaces the row', () async {
    await repo.putAll({'a': (meters: 20, inputsHash: 'old')});
    await repo.putAll({'a': (meters: 24, inputsHash: 'new')});

    expect((await repo.getEntries({'a'}))['a'], (
      meters: 24.0,
      inputsHash: 'new',
    ));
    expect(await db.select(db.diveVerticalDistanceCache).get(), hasLength(1));
  });

  test('reads more ids than one query may bind', () async {
    final all = {
      for (var i = 0; i < 2000; i++) 'd$i': (meters: i + 1.0, inputsHash: 'h'),
    };
    await repo.putAll(all);

    final entries = await repo.getEntries(all.keys.toSet());

    expect(entries, hasLength(2000));
    expect(entries['d1999']!.meters, 2000);
  });

  test('an empty write does nothing', () async {
    await repo.putAll({});
    expect(await db.select(db.diveVerticalDistanceCache).get(), isEmpty);
  });

  test('clear empties the table', () async {
    await repo.putAll({'a': (meters: 20, inputsHash: 'h')});
    await repo.clear();
    expect(await repo.getEntries({'a'}), isEmpty);
  });
}
