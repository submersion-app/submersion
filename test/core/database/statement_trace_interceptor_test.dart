import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/statement_trace_interceptor.dart';

/// A database with no tables, for running raw statements.
class _TraceDatabase extends GeneratedDatabase {
  _TraceDatabase(super.e);

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];

  @override
  int get schemaVersion => 1;
}

void main() {
  late List<String> lines;
  late _TraceDatabase db;

  setUp(() {
    lines = [];
    db = _TraceDatabase(
      NativeDatabase.memory().interceptWith(
        StatementTraceInterceptor(lines.add),
      ),
    );
  });

  tearDown(() => db.close());

  /// Each line's id and what it says, without the timing.
  List<String> shapes() => [
    for (final line in lines) line.replaceAll(RegExp(r' in \d+ ms'), ''),
  ];

  // drift opens the executor before every statement, and a transaction once
  // more for itself. In a browser using Web Locks that open is where a
  // statement or a transaction waits for the lock, so it is traced too.
  test('prints each statement as it starts and as it ends', () async {
    await db.customStatement('CREATE TABLE t (x INTEGER)');
    await db.customSelect('SELECT x FROM t').get();

    expect(shapes(), [
      '[db 1] start open',
      '[db 1] done',
      '[db 2] start custom: CREATE TABLE t (x INTEGER)',
      '[db 2] done',
      '[db 3] start open',
      '[db 3] done',
      '[db 4] start select: SELECT x FROM t',
      '[db 4] done',
    ]);
  });

  test('prints a transaction around the statements inside it', () async {
    await db.customStatement('CREATE TABLE t (x INTEGER)');
    lines.clear();

    await db.transaction(() async {
      await db.customInsert(
        'INSERT INTO t (x) VALUES (?)',
        variables: [Variable.withInt(1)],
      );
    });

    expect(shapes(), [
      '[db 3] start open',
      '[db 3] done',
      '[db 4] begin transaction',
      '[db 5] start open',
      '[db 5] done',
      '[db 6] start open',
      '[db 6] done',
      '[db 7] start insert: INSERT INTO t (x) VALUES (?)',
      '[db 7] done',
      '[db 8] start commit',
      '[db 8] done',
    ]);
  });

  test('prints a statement that fails, and still throws', () async {
    await expectLater(
      db.customSelect('SELECT x FROM missing').get(),
      throwsA(isA<SqliteException>()),
    );

    expect(lines.last, startsWith('[db 2] failed in '));
  });

  test('never prints the values bound to a statement', () async {
    await db.customStatement('CREATE TABLE t (x TEXT)');
    await db.customInsert(
      'INSERT INTO t (x) VALUES (?)',
      variables: [Variable.withString('private note')],
    );

    expect(lines.join('\n'), isNot(contains('private note')));
  });
}
