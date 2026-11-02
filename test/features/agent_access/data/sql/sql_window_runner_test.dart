import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/agent_access/data/sql/sql_window.dart';
import 'package:submersion/features/agent_access/data/sql/sql_window_runner.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';

import 'sql_window_fixture.dart';

const _key = '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';

void main() {
  late SqlWindowFixture fixture;

  setUpAll(() async {
    fixture = await SqlWindowFixture.create();
  });
  tearDownAll(() => fixture.dispose());

  test('a call runs on a worker isolate and returns', () async {
    final runner = SqlWindowRunner(
      file: () async => SqlDatabaseFile(path: fixture.path),
    );
    final outcome = await runner.run(sql: 'SELECT count(*) FROM dives');
    expect((outcome as SqlWindowRows).rows, [
      [0],
    ]);
  });

  test('a refusal crosses the isolate boundary intact', () async {
    final runner = SqlWindowRunner(
      file: () async => SqlDatabaseFile(path: fixture.path),
    );
    final outcome = await runner.run(sql: 'SELECT * FROM connected_accounts');
    final failure = outcome as SqlWindowFailure;
    expect(failure.code, AgentToolErrorCode.sqlRefused);
    expect(failure.details, {'table': 'connected_accounts'});
  });

  test('a runaway statement does not hold the caller', () async {
    final worker = Completer<SqlWindowOutcome>();
    final runner = SqlWindowRunner(
      file: () async => SqlDatabaseFile(path: fixture.path),
      worker: (_) => worker.future,
      timeCap: Duration.zero,
      replyGrace: const Duration(milliseconds: 10),
    );

    final first = await runner.run(sql: 'SELECT 1') as SqlWindowRows;
    expect(first.timeCapHit, isTrue);
    expect(first.stillRunning, isTrue);
    expect(first.rows, isEmpty);

    final second = await runner.run(sql: 'SELECT 1') as SqlWindowFailure;
    expect(second.code, AgentToolErrorCode.sqlBusy);

    worker.complete(
      const SqlWindowRows(columns: [], rows: [], elapsed: Duration.zero),
    );
  });

  test('the busy flag clears once the worker ends', () async {
    final worker = Completer<SqlWindowOutcome>();
    var calls = 0;
    final runner = SqlWindowRunner(
      file: () async => SqlDatabaseFile(path: fixture.path),
      worker: (_) {
        calls++;
        return calls == 1
            ? worker.future
            : Future.value(
                const SqlWindowRows(
                  columns: [],
                  rows: [],
                  elapsed: Duration.zero,
                ),
              );
      },
      timeCap: Duration.zero,
      replyGrace: const Duration(milliseconds: 10),
    );
    await runner.run(sql: 'SELECT 1');
    worker.complete(
      const SqlWindowRows(columns: [], rows: [], elapsed: Duration.zero),
    );
    await pumpEventQueue();
    expect(await runner.run(sql: 'SELECT 2'), isA<SqlWindowRows>());
    expect(calls, 2);
  });

  test('a worker that fails after the reply is nobody\'s error', () async {
    final worker = Completer<SqlWindowOutcome>();
    var calls = 0;
    final runner = SqlWindowRunner(
      file: () async => SqlDatabaseFile(path: fixture.path),
      worker: (_) async {
        calls++;
        if (calls == 1) return worker.future;
        return const SqlWindowRows(
          columns: [],
          rows: [],
          elapsed: Duration.zero,
        );
      },
      timeCap: Duration.zero,
      replyGrace: const Duration(milliseconds: 10),
    );
    await runner.run(sql: 'SELECT 1');
    worker.completeError(StateError('late'));
    await pumpEventQueue();
    expect(await runner.run(sql: 'SELECT 1'), isA<SqlWindowRows>());
  });

  test('a failed file lookup leaves the runner usable', () async {
    var fail = true;
    final runner = SqlWindowRunner(
      file: () async {
        if (fail) throw StateError('no path');
        return SqlDatabaseFile(path: fixture.path);
      },
    );
    await expectLater(runner.run(sql: 'SELECT 1'), throwsStateError);
    fail = false;
    expect(await runner.run(sql: 'SELECT 1'), isA<SqlWindowRows>());
  });

  test('the file is read on each call, so a swap takes effect', () async {
    final other = await SqlWindowFixture.create();
    addTearDown(other.dispose);
    other.execute(
      "INSERT INTO tags (id, name, created_at, updated_at) "
      "VALUES ('t1', 'marked', 1, 1)",
    );
    var path = fixture.path;
    final runner = SqlWindowRunner(
      file: () async => SqlDatabaseFile(path: path),
    );
    const sql = "SELECT count(*) FROM tags WHERE id = 't1'";
    expect((await runner.run(sql: sql) as SqlWindowRows).rows, [
      [0],
    ]);
    path = other.path;
    expect((await runner.run(sql: sql) as SqlWindowRows).rows, [
      [1],
    ]);
  });

  test('a SQLCipher file opens with its key', () async {
    final encrypted = await SqlWindowFixture.create(keyHex: _key);
    addTearDown(encrypted.dispose);
    final runner = SqlWindowRunner(
      file: () async => SqlDatabaseFile(path: encrypted.path, keyHex: _key),
    );
    expect(
      await runner.run(sql: 'SELECT count(*) FROM dives'),
      isA<SqlWindowRows>(),
    );
  });

  test('the wrong key answers an error, not a crash', () async {
    final encrypted = await SqlWindowFixture.create(keyHex: _key);
    addTearDown(encrypted.dispose);
    final runner = SqlWindowRunner(
      file: () async => SqlDatabaseFile(path: encrypted.path),
    );
    final outcome = await runner.run(sql: 'SELECT count(*) FROM dives');
    expect(outcome, isA<SqlWindowFailure>());
  });

  test('a missing file answers database_unavailable', () async {
    final runner = SqlWindowRunner(
      file: () async => const SqlDatabaseFile(path: 'no-such-file.db'),
    );
    final outcome = await runner.run(sql: 'SELECT 1') as SqlWindowFailure;
    expect(outcome.code, AgentToolErrorCode.databaseUnavailable);
  });
}
