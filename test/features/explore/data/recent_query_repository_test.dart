import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/features/explore/data/recent_query_repository.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

void main() {
  late LocalCacheDatabase db;
  late RecentQueryRepository repo;

  setUp(() {
    db = LocalCacheDatabase(NativeDatabase.memory());
    LocalCacheDatabaseService.instance.setTestDatabase(db);
    repo = RecentQueryRepository();
  });
  tearDown(() async {
    await db.close();
    LocalCacheDatabaseService.instance.resetForTesting();
  });

  const parsed = ParsedQuery(subject: QuerySubject.dives);

  test('records and lists newest first', () async {
    await repo.record('a', 'en', parsed, diverId: 'ana');
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await repo.record('b', 'en', parsed, diverId: 'ana');
    final list = await repo.list(diverId: 'ana', locale: 'en');
    expect(list.map((r) => r.sentence), ['b', 'a']);
    expect(list.first.parsed.subject, QuerySubject.dives);
  });

  test(
    're-recording the same sentence bumps it instead of duplicating',
    () async {
      await repo.record('Turtles in Bonaire', 'en', parsed, diverId: 'ana');
      await repo.record('a', 'en', parsed, diverId: 'ana');
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await repo.record('turtles  in bonaire', 'en', parsed, diverId: 'ana');
      final list = await repo.list(diverId: 'ana', locale: 'en');
      expect(list, hasLength(2));
      expect(list.first.sentence, 'turtles  in bonaire');
    },
  );

  test('the cap keeps the twenty newest', () async {
    for (var i = 0; i < 25; i++) {
      await repo.record('q$i', 'en', parsed, diverId: 'ana');
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    final list = await repo.list(diverId: 'ana', locale: 'en');
    expect(list, hasLength(RecentQueryRepository.cap));
    expect(list.first.sentence, 'q24');
    expect(list.last.sentence, 'q5');
  });

  test('rows from an older schema are skipped and deleted', () async {
    await repo.record('old', 'en', parsed, diverId: 'ana');
    await db.customStatement('UPDATE recent_queries SET schema_version = 0');
    expect(await repo.list(diverId: 'ana', locale: 'en'), isEmpty);
    final rows = await db
        .customSelect('SELECT COUNT(*) AS n FROM recent_queries')
        .getSingle();
    expect(rows.read<int>('n'), 0);
  });

  test('each diver sees only their own sentences', () async {
    await repo.record('turtles with Ana', 'en', parsed, diverId: 'ana');
    await repo.record('wrecks with Bob', 'en', parsed, diverId: 'bob');
    expect(
      (await repo.list(diverId: 'ana', locale: 'en')).map((r) => r.sentence),
      ['turtles with Ana'],
    );
    expect(
      (await repo.list(diverId: 'bob', locale: 'en')).map((r) => r.sentence),
      ['wrecks with Bob'],
    );
  });

  test('the same sentence from two divers is two rows', () async {
    await repo.record('night dives', 'en', parsed, diverId: 'ana');
    await repo.record('night dives', 'en', parsed, diverId: 'bob');
    expect(await repo.list(diverId: 'ana', locale: 'en'), hasLength(1));
    expect(await repo.list(diverId: 'bob', locale: 'en'), hasLength(1));
  });

  test('the cap is per diver', () async {
    await repo.record('bob keeps this', 'en', parsed, diverId: 'bob');
    for (var i = 0; i < 25; i++) {
      await repo.record('q$i', 'en', parsed, diverId: 'ana');
    }
    expect(
      (await repo.list(diverId: 'bob', locale: 'en')).map((r) => r.sentence),
      ['bob keeps this'],
    );
  });

  test('another locale is not listed', () async {
    await repo.record('tortues', 'fr', parsed, diverId: 'ana');
    expect(await repo.list(diverId: 'ana', locale: 'en'), isEmpty);
  });

  test('a table from before rows carried a diver is recreated', () async {
    // A development build of cache v18 made the table with no diver_id.
    final file = File(
      p.join(
        (await Directory.systemTemp.createTemp('recent_queries')).path,
        'cache.db',
      ),
    );
    addTearDown(() => file.parent.delete(recursive: true));
    final old = LocalCacheDatabase(NativeDatabase(file));
    await old.customStatement('SELECT 1');
    await old.customStatement('DROP TABLE recent_queries');
    await old.customStatement(
      'CREATE TABLE recent_queries (key TEXT NOT NULL, sentence TEXT NOT NULL, '
      'locale TEXT NOT NULL, parsed_json TEXT NOT NULL, '
      'schema_version INTEGER NOT NULL, subject TEXT NOT NULL, '
      'last_used_at INTEGER NOT NULL, PRIMARY KEY (key))',
    );
    await old.close();

    final reopened = LocalCacheDatabase(NativeDatabase(file));
    addTearDown(reopened.close);
    final scoped = RecentQueryRepository(database: reopened);
    await scoped.record('after the upgrade', 'en', parsed, diverId: 'ana');
    expect(
      (await scoped.list(diverId: 'ana', locale: 'en')).map((r) => r.sentence),
      ['after the upgrade'],
    );
  });
}
