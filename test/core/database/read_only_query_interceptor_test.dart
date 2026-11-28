import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/read_only_query_interceptor.dart';

class _TinyDb extends GeneratedDatabase {
  _TinyDb(super.e);

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];

  @override
  int get schemaVersion => 1;
}

void main() {
  late _TinyDb writer;
  late _TinyDb readOnly;

  setUp(() async {
    // One in-memory database, reached through a plain connection that sets
    // it up and a read-only one in front of the same executor.
    final executor = NativeDatabase.memory();
    writer = _TinyDb(DatabaseConnection(executor));
    await writer.customStatement('CREATE TABLE t (id INTEGER PRIMARY KEY)');
    await writer.customStatement('INSERT INTO t (id) VALUES (1)');
    readOnly = _TinyDb(
      DatabaseConnection(executor).interceptWith(ReadOnlyQueryInterceptor()),
    );
  });

  tearDown(() => writer.close());

  test('refuses writes and lets reads through', () async {
    final rows = await readOnly.customSelect('SELECT id FROM t').get();
    expect(rows.single.read<int>('id'), 1);
    final withRows = await readOnly
        .customSelect('WITH x AS (SELECT 2 AS v) SELECT v FROM x')
        .getSingle();
    expect(withRows.read<int>('v'), 2);

    await expectLater(
      readOnly.customStatement('INSERT INTO t (id) VALUES (2)'),
      throwsA(isA<ReadOnlyViolation>()),
    );
    await expectLater(
      readOnly.customInsert('INSERT INTO t (id) VALUES (3)'),
      throwsA(isA<ReadOnlyViolation>()),
    );
    await expectLater(
      readOnly.customUpdate('UPDATE t SET id = 9'),
      throwsA(isA<ReadOnlyViolation>()),
    );
    await expectLater(
      readOnly.customUpdate('DELETE FROM t', updateKind: UpdateKind.delete),
      throwsA(isA<ReadOnlyViolation>()),
    );
    await expectLater(
      readOnly.transaction(() async {}),
      throwsA(isA<ReadOnlyViolation>()),
    );
    await expectLater(
      readOnly.batch((b) => b.customStatement('DELETE FROM t')),
      throwsA(isA<ReadOnlyViolation>()),
    );

    final after = await writer.customSelect('SELECT id FROM t').get();
    expect(after.map((r) => r.read<int>('id')), [1]);
  });

  test('a read pragma is allowed and a pragma that sets is refused', () async {
    final version = await readOnly
        .customSelect('PRAGMA user_version')
        .getSingle();
    // Drift stamped the schema version when the writer opened it.
    expect(version.read<int>('user_version'), writer.schemaVersion);
    await expectLater(
      readOnly.customStatement('PRAGMA user_version = 3'),
      throwsA(isA<ReadOnlyViolation>()),
    );
  });

  test('writes hidden behind a WITH are refused', () async {
    await expectLater(
      readOnly.customStatement(
        'WITH x AS (SELECT 1) INSERT INTO t (id) SELECT 5 FROM x',
      ),
      throwsA(isA<ReadOnlyViolation>()),
    );
    await expectLater(
      readOnly.customSelect('WITH x AS (SELECT 1) DELETE FROM t').get(),
      throwsA(isA<ReadOnlyViolation>()),
    );
  });

  test('only reading pragmas pass', () async {
    for (final pragma in [
      'PRAGMA optimize',
      'PRAGMA wal_checkpoint(TRUNCATE)',
      'PRAGMA incremental_vacuum',
    ]) {
      await expectLater(
        readOnly.customStatement(pragma),
        throwsA(isA<ReadOnlyViolation>()),
        reason: pragma,
      );
    }
    final info = await readOnly.customSelect('PRAGMA table_info(t)').get();
    expect(info, isNotEmpty);
  });

  test('a reading pragma given a value in parentheses is refused', () async {
    // `PRAGMA journal_mode(WAL)` sets, exactly like `= WAL`; only the
    // pragmas whose argument names a table or index read with one.
    for (final pragma in [
      'PRAGMA journal_mode(DELETE)',
      'PRAGMA user_version(7)',
      'PRAGMA foreign_keys(0)',
      'PRAGMA main.application_id(3)',
    ]) {
      await expectLater(
        readOnly.customSelect(pragma).get(),
        throwsA(isA<ReadOnlyViolation>()),
        reason: pragma,
      );
    }
    final version = await writer
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), writer.schemaVersion);
    final indexes = await readOnly.customSelect('PRAGMA index_list(t)').get();
    expect(indexes, isA<List<QueryRow>>());
  });

  test('a refusal is reported to the callback', () async {
    final reported = <String>[];
    final reporting = _TinyDb(
      DatabaseConnection(
        writer.executor,
      ).interceptWith(ReadOnlyQueryInterceptor(onRefused: reported.add)),
    );
    await expectLater(
      reporting.customStatement('DELETE FROM t'),
      throwsA(isA<ReadOnlyViolation>()),
    );
    expect(reported, ['DELETE FROM t']);
  });

  test('the write paths drift reaches only on its own are refused', () async {
    // Drift opens a transaction before a batch, and only an exclusive block
    // opens one exclusively, so the existing calls are refused before these
    // are reached. A future drift that took them directly must still fail.
    final interceptor = ReadOnlyQueryInterceptor();
    final executor = writer.executor;

    await expectLater(
      interceptor.runDelete(executor, 'DELETE FROM t', const []),
      throwsA(isA<ReadOnlyViolation>()),
    );
    await expectLater(
      interceptor.runBatched(
        executor,
        BatchedStatements(
          ['DELETE FROM t'],
          [ArgumentsForBatchedStatement(0, const [])],
        ),
      ),
      throwsA(isA<ReadOnlyViolation>()),
    );
    expect(
      () => interceptor.beginExclusive(executor),
      throwsA(isA<ReadOnlyViolation>()),
    );

    final rows = await writer.customSelect('SELECT id FROM t').get();
    expect(rows, hasLength(1));
  });

  test('a read sent as a statement goes through', () async {
    await readOnly.customStatement('PRAGMA user_version');
    await readOnly.customStatement('SELECT id FROM t');
  });

  test('a long refused statement is reported shortened', () async {
    final reported = <String>[];
    final reporting = _TinyDb(
      DatabaseConnection(
        writer.executor,
      ).interceptWith(ReadOnlyQueryInterceptor(onRefused: reported.add)),
    );
    final long =
        'DELETE FROM t WHERE id IN (${List.filled(40, '1').join(', ')})';
    expect(long.length, greaterThan(80));

    await expectLater(
      reporting.customStatement(long),
      throwsA(
        isA<ReadOnlyViolation>().having(
          (e) => e.message,
          'message',
          'read-only connection refused: ${long.substring(0, 80)}...',
        ),
      ),
    );
    expect(reported, ['${long.substring(0, 80)}...']);
  });

  test('a write chained after a SELECT is refused', () async {
    await expectLater(
      readOnly.customStatement('SELECT 1; DELETE FROM t'),
      throwsA(isA<ReadOnlyViolation>()),
    );
    final rows = await writer.customSelect('SELECT id FROM t').get();
    expect(rows, hasLength(1));
  });
}
