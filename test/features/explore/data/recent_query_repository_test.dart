import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
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

  const parsed = ParsedQuery(subject: ParsedSubject.dives);

  test('records and lists newest first', () async {
    await repo.record('a', 'en', parsed, diverId: 'ana');
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await repo.record('b', 'en', parsed, diverId: 'ana');
    final list = await repo.list(diverId: 'ana', locale: 'en');
    expect(list.map((r) => r.sentence), ['b', 'a']);
    expect(list.first.parsed!.subject, ParsedSubject.dives);
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

  test('a row parsed by an older prompt keeps its sentence but not its '
      'parse (#2838)', () async {
    // Before version 4 the model invented a time for most sentences, so a
    // replayed parse would keep that window: the sentence is asked again.
    await repo.record(
      'deep dives',
      'en',
      const ParsedQuery(
        subject: ParsedSubject.dives,
        time: QueryTime('this year'),
      ),
      diverId: 'ana',
    );
    await db.customStatement(
      'UPDATE recent_queries '
      'SET schema_version = ${kMinReplayableQuerySchemaVersion - 1}',
    );
    final list = await repo.list(diverId: 'ana', locale: 'en');
    expect(list.single.sentence, 'deep dives');
    expect(list.single.parsed, isNull);
  });

  test('a row parsed by the current prompt replays its parse', () async {
    await repo.record('deep dives', 'en', parsed, diverId: 'ana');
    final list = await repo.list(diverId: 'ana', locale: 'en');
    expect(list.single.parsed, isNotNull);
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

  // Earlier development builds of cache v18: no diver at all, then a diver
  // column that was not part of the key.
  for (final (name, columns) in [
    ('no diver column', 'key TEXT NOT NULL,'),
    ('a diver outside the key', 'key TEXT NOT NULL, diver_id TEXT NOT NULL,'),
  ]) {
    test('a table with $name is recreated', () async {
      final dir = await Directory.systemTemp.createTemp('recent_queries');
      addTearDown(() => dir.delete(recursive: true));
      final file = File(p.join(dir.path, 'cache.db'));
      final old = LocalCacheDatabase(NativeDatabase(file));
      await old.customStatement('DROP TABLE recent_queries');
      await old.customStatement(
        'CREATE TABLE recent_queries ($columns sentence TEXT NOT NULL, '
        'locale TEXT NOT NULL, parsed_json TEXT NOT NULL, '
        'schema_version INTEGER NOT NULL, subject TEXT NOT NULL, '
        'last_used_at INTEGER NOT NULL, PRIMARY KEY (key))',
      );
      await old.close();

      final reopened = LocalCacheDatabase(NativeDatabase(file));
      addTearDown(reopened.close);
      final scoped = RecentQueryRepository(database: reopened);
      // The same sentence for two divers needs the diver in the key.
      await scoped.record('night dives', 'en', parsed, diverId: 'ana');
      await scoped.record('night dives', 'en', parsed, diverId: 'bob');
      expect(await scoped.list(diverId: 'ana', locale: 'en'), hasLength(1));
      expect(await scoped.list(diverId: 'bob', locale: 'en'), hasLength(1));
    });
  }

  test('a sentence saved before schema v2 is kept', () async {
    await repo.record('turtles', 'en', parsed, diverId: 'ana');
    await db.customStatement('UPDATE recent_queries SET schema_version = 1');
    expect(
      (await repo.list(diverId: 'ana', locale: 'en')).map((r) => r.sentence),
      ['turtles'],
    );
  });
  test('typed and asked recents keep their kind and do not collide', () async {
    final repo = RecentQueryRepository();
    await repo.record(
      'manta',
      'en',
      const ParsedQuery(subject: ParsedSubject.dives),
      diverId: 'ana',
    );
    await repo.recordTyped(
      'manta',
      TextNode(['manta']),
      locale: 'en',
      diverId: 'ana',
    );
    final rows = await repo.list(diverId: 'ana', locale: 'en');
    expect(rows.map((r) => r.kind).toSet(), {
      RecentQueryKind.typed,
      RecentQueryKind.asked,
    });
    final typed = rows.singleWhere((r) => r.kind == RecentQueryKind.typed);
    expect(typed.node, TextNode(['manta']));
    expect(typed.sentence, 'manta');
  });

  test('a typed recent survives a list read', () async {
    final repo = RecentQueryRepository();
    await repo.recordTyped(
      'depth > 30m',
      ConditionNode(
        FieldPath(['depth']),
        QueryOp.gt,
        const NumberValue(30, null),
      ),
      locale: 'en',
      diverId: 'ana',
    );
    await repo.list(diverId: 'ana', locale: 'en');
    expect(await repo.list(diverId: 'ana', locale: 'en'), hasLength(1));
  });

  test('another diver or language never sees a typed recent', () async {
    final repo = RecentQueryRepository();
    await repo.recordTyped(
      'manta',
      TextNode(['manta']),
      locale: 'en',
      diverId: 'ana',
    );
    expect(await repo.list(diverId: 'ben', locale: 'en'), isEmpty);
    expect(await repo.list(diverId: 'ana', locale: 'de'), isEmpty);
  });

  // Review: typed rows were keyed by their printed text, labels included,
  // so a rename split one search into two rows that print alike.
  test('a typed search keeps one row across a rename', () async {
    QueryNode site(String label) =>
        ConditionNode(FieldPath(['site']), QueryOp.eq, RefValue('s1', label));
    await repo.recordTyped(
      'site = "Bari Reef"',
      site('Bari Reef'),
      locale: 'en',
      diverId: 'ana',
    );
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await repo.recordTyped(
      'site = "Bari Reef North"',
      site('Bari Reef North'),
      locale: 'en',
      diverId: 'ana',
    );
    final rows = await repo.list(diverId: 'ana', locale: 'en');
    expect(rows, hasLength(1));
    expect(rows.single.sentence, 'site = "Bari Reef North"');
  });

  test('typed words differing only in case are one row', () async {
    await repo.recordTyped(
      'Manta',
      TextNode(['Manta']),
      locale: 'en',
      diverId: 'ana',
    );
    await repo.recordTyped(
      'manta',
      TextNode(['manta']),
      locale: 'en',
      diverId: 'ana',
    );
    expect(await repo.list(diverId: 'ana', locale: 'en'), hasLength(1));
  });

  // Review: a dropped typed row left no trace.
  test('an unreadable typed row is dropped with a warning', () async {
    await db
        .into(db.recentQueries)
        .insert(
          RecentQueriesCompanion.insert(
            diverId: 'ana',
            key: 'typed:x',
            sentence: 'x',
            locale: 'en',
            parsedJson: '{"version":1,"node":{"t":"bogus"}}',
            schemaVersion: 0,
            subject: 'dives',
            lastUsedAt: 1,
            kind: const Value('typed'),
          ),
        );
    final seen = <LogEntry>[];
    final sub = LoggerService.logStream.listen(seen.add);
    addTearDown(sub.cancel);
    expect(await repo.list(diverId: 'ana', locale: 'en'), isEmpty);
    await Future<void>.delayed(Duration.zero);
    expect(seen.where((e) => e.level == LogLevel.warning), isNotEmpty);
    expect(await db.select(db.recentQueries).get(), isEmpty);
  });

  test('a rename inside a list or a scoped group keeps one row', () async {
    QueryNode buddies(String label) => ScopedNode(
      FieldPath(['buddies']),
      ConditionNode(
        FieldPath(['buddy']),
        QueryOp.inList,
        ListValue([RefValue('b1', label), const StringValue('x')]),
      ),
    );
    await repo.recordTyped(
      'before',
      buddies('Ana'),
      locale: 'en',
      diverId: 'ana',
    );
    await repo.recordTyped(
      'after',
      buddies('Ana Lee'),
      locale: 'en',
      diverId: 'ana',
    );
    expect(await repo.list(diverId: 'ana', locale: 'en'), hasLength(1));
  });

  test('a typed row that is not JSON is dropped with a warning', () async {
    await db
        .into(db.recentQueries)
        .insert(
          RecentQueriesCompanion.insert(
            diverId: 'ana',
            key: 'typed:y',
            sentence: 'y',
            locale: 'en',
            parsedJson: 'not json',
            schemaVersion: 0,
            subject: 'dives',
            lastUsedAt: 1,
            kind: const Value('typed'),
          ),
        );
    final seen = <LogEntry>[];
    final sub = LoggerService.logStream.listen(seen.add);
    addTearDown(sub.cancel);
    expect(await repo.list(diverId: 'ana', locale: 'en'), isEmpty);
    await Future<void>.delayed(Duration.zero);
    expect(seen.where((e) => e.level == LogLevel.warning), isNotEmpty);
  });
}
