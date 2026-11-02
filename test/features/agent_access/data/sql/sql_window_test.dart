import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/agent_access/data/sql/sql_denied_set.dart';
import 'package:submersion/features/agent_access/data/sql/sql_window.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';

import 'sql_window_fixture.dart';

void main() {
  late SqlWindowFixture fixture;

  setUpAll(() async {
    fixture = await SqlWindowFixture.create();
  });
  tearDownAll(() => fixture.dispose());

  SqlWindowOutcome run(
    String sql, {
    List<Object?> params = const [],
    int maxRows = kSqlDefaultRows,
    int maxBytes = kSqlMaxResultBytes,
    Duration timeCap = kSqlTimeCap,
  }) => runSqlWindow(
    SqlWindowRequest(
      path: fixture.path,
      sql: sql,
      params: params,
      maxRows: maxRows,
      maxBytes: maxBytes,
      timeCap: timeCap,
    ),
  );

  SqlWindowRows rows(
    String sql, {
    List<Object?> params = const [],
    int maxRows = kSqlDefaultRows,
    int maxBytes = kSqlMaxResultBytes,
    Duration timeCap = kSqlTimeCap,
  }) {
    final outcome = run(
      sql,
      params: params,
      maxRows: maxRows,
      maxBytes: maxBytes,
      timeCap: timeCap,
    );
    if (outcome is SqlWindowFailure) fail(outcome.message);
    return outcome as SqlWindowRows;
  }

  void expectRefused(String sql, {String? mentions}) {
    final outcome = run(sql);
    expect(outcome, isA<SqlWindowFailure>(), reason: sql);
    final failure = outcome as SqlWindowFailure;
    expect(failure.code, AgentToolErrorCode.sqlRefused, reason: sql);
    if (mentions != null) expect(failure.message, contains(mentions));
  }

  group('results', () {
    test('returns columns, rows and how long it took', () {
      final result = rows("SELECT 1 AS one, 'two' AS two");
      expect(result.columns, ['one', 'two']);
      expect(result.rows, [
        [1, 'two'],
      ]);
      final json = result.toJson();
      expect(json['row_count'], 1);
      expect(json['row_cap_hit'], false);
      expect(json['time_cap_hit'], false);
      expect(json['elapsed_ms'], isA<int>());
    });

    test('keeps a column whose name repeats', () {
      expect(rows('SELECT 1 AS a, 2 AS a').rows, [
        [1, 2],
      ]);
    });

    test('binds parameters', () {
      expect(rows('SELECT ? + ?', params: [2, 3]).rows, [
        [5],
      ]);
    });

    test('names a parameter count that does not match', () {
      final outcome = run('SELECT ? + ?', params: [2]) as SqlWindowFailure;
      expect(outcome.code, AgentToolErrorCode.invalidArgument);
      expect(outcome.message, contains('2'));
    });

    test('stops at max_rows and says more rows exist', () {
      final result = rows(
        'WITH RECURSIVE c(x) AS (SELECT 1 UNION ALL SELECT x + 1 FROM c '
        'WHERE x < 10) SELECT x FROM c',
        maxRows: 3,
      );
      expect(result.rows, hasLength(3));
      expect(result.rowCapHit, isTrue);
    });

    test('a result that exactly fills max_rows is not capped', () {
      final result = rows('VALUES (1), (2)', maxRows: 2);
      expect(result.rows, hasLength(2));
      expect(result.rowCapHit, isFalse);
    });

    test('stops between rows at the time cap', () {
      final result = rows(
        'WITH RECURSIVE c(x) AS (SELECT 1 UNION ALL SELECT x + 1 FROM c) '
        'SELECT x FROM c',
        timeCap: Duration.zero,
      );
      expect(result.timeCapHit, isTrue);
      expect(result.rows, hasLength(1));
    });

    test('stops at the size cap', () {
      final result = rows(
        "VALUES (printf('%.*c', 2000, 'x')), (printf('%.*c', 2000, 'x'))",
        maxBytes: 3000,
      );
      expect(result.sizeCapHit, isTrue);
      expect(result.rows, hasLength(1));
    });

    test('never returns the bytes of a blob', () {
      expect(rows('SELECT zeroblob(5)').rows, [
        [
          {'blob_bytes': 5},
        ],
      ]);
    });

    test('renders infinity as text', () {
      expect(rows('SELECT 9e999').rows, [
        ['Infinity'],
      ]);
    });

    test('has the app functions', () {
      expect(rows("SELECT unicode_lower('Éponge')").rows, [
        ['éponge'],
      ]);
      expect(rows('SELECT dive_ambient_bar(10, NULL, NULL, NULL)').rows, [
        [isA<double>()],
      ]);
    });

    test('reads the schema catalogue', () {
      final names = rows(
        "SELECT name FROM sqlite_schema WHERE type = 'table' AND name = 'dives'",
      );
      expect(names.rows, [
        ['dives'],
      ]);
    });

    test('joins and aggregates over real tables', () {
      final result = rows(
        'SELECT d.id, count(t.id) FROM dives d '
        'LEFT JOIN dive_tanks t ON t.dive_id = d.id GROUP BY d.id',
      );
      expect(result.columns, hasLength(2));
    });
  });

  group('statement kinds', () {
    for (final sql in const [
      "ATTACH '/nowhere' AS x",
      'BEGIN',
      'PRAGMA query_only = 0',
      'PRAGMA table_info(dives)',
      'EXPLAIN SELECT 1',
      'EXPLAIN QUERY PLAN SELECT 1',
      "DELETE FROM dives WHERE id = 'x'",
      "UPDATE dives SET name = 'x'",
      "INSERT INTO tags (id) VALUES ('x')",
      'DROP TABLE dives',
      'VACUUM',
      '/* SELECT */ PRAGMA user_version',
      '',
    ]) {
      test('refuses ${sql.isEmpty ? 'an empty statement' : sql}', () {
        expectRefused(sql);
      });
    }

    test('refuses a write hidden behind a CTE', () {
      expectRefused("WITH c AS (SELECT 1) DELETE FROM dives WHERE id = 'x'");
    });

    test('refuses a second statement', () {
      expectRefused('SELECT 1; SELECT 2');
      expectRefused('SELECT 1; DROP TABLE dives');
    });

    test('allows a trailing semicolon and comment', () {
      expect(rows('SELECT 1; -- done').rows, [
        [1],
      ]);
    });

    test('a syntax error is an SQL error, not a refusal', () {
      final outcome = run('SELECT FROM') as SqlWindowFailure;
      expect(outcome.code, AgentToolErrorCode.sqlError);
    });
  });

  group('denied tables', () {
    test('every denied table exists to be attacked', () {
      final names = rows(
        'SELECT name FROM sqlite_schema',
      ).rows.map((row) => row.first).toSet();
      expect(kSqlDeniedTables.difference(names.cast<String>()), isEmpty);
    });

    for (final table in kSqlDeniedTables) {
      test('no denied table is reachable: $table', () {
        for (final sql in [
          'SELECT * FROM $table',
          'SELECT count(*) FROM $table',
          'SELECT * FROM main.$table',
          'SELECT * FROM ${deniedViewOf(table)}',
          'SELECT (SELECT count(*) FROM $table)',
          'SELECT 1 WHERE EXISTS (SELECT 1 FROM $table)',
          'WITH c AS (SELECT * FROM $table) SELECT * FROM c',
          'SELECT 1 UNION ALL SELECT count(*) FROM $table',
          'SELECT d.id FROM dives d, $table t',
        ]) {
          expectRefused(sql, mentions: table);
        }
        // A WITHOUT ROWID table fails to compile this instead, reading
        // nothing either way.
        expect(run('SELECT rowid FROM $table'), isA<SqlWindowFailure>());
      });
    }

    test('a table the policy does not know is refused', () {
      expectRefused('SELECT * FROM probe_unclassified');
    });

    test('a virtual table is refused', () {
      expectRefused("SELECT * FROM pragma_table_info('dives')");
      expectRefused("SELECT value FROM json_each('[1]')");
      expectRefused('SELECT * FROM dbstat');
    });

    test('the temp catalogue is refused', () {
      expectRefused('SELECT * FROM sqlite_temp_schema');
    });
  });

  group('denied columns', () {
    test('the rest of the table reads', () {
      final result = rows(
        'SELECT id, manifest_url, display_name FROM media_subscriptions',
      );
      expect(result.rows, [
        ['sub-1', 'https://example.test/feed', 'Feed'],
      ]);
    });

    test('a denied column is refused however it is named', () {
      for (final sql in const [
        'SELECT credentials_host_id FROM media_subscriptions',
        'SELECT * FROM media_subscriptions',
        'SELECT 1 FROM media_subscriptions WHERE credentials_host_id IS NULL',
        "SELECT 1 FROM media_subscriptions WHERE credentials_host_id > 'a'",
        'SELECT length(credentials_host_id) FROM media_subscriptions',
        'SELECT typeof(credentials_host_id) FROM media_subscriptions',
        'SELECT coalesce(credentials_host_id, 1) FROM media_subscriptions',
        'WITH c AS (SELECT * FROM media_subscriptions) '
            'SELECT credentials_host_id FROM c',
        'SELECT id FROM media_subscriptions ORDER BY credentials_host_id',
        'SELECT credentials_host_id, count(*) FROM media_subscriptions '
            'GROUP BY 1',
      ]) {
        expectRefused(sql, mentions: 'credentials_host_id');
      }
    });

    test('no table in the real schema gives up a denied column', () {
      final tables = rows(
        "SELECT name, sql FROM sqlite_schema WHERE type = 'table'",
      ).rows;
      var attacked = 0;
      for (final [name as String, sql as String?] in tables) {
        for (final column in kSqlDeniedColumns) {
          if (sql == null || !sql.contains('"$column"')) continue;
          attacked++;
          expectRefused('SELECT "$column" FROM "$name"');
        }
      }
      expect(attacked, greaterThanOrEqualTo(kSqlDeniedColumns.length));
    });

    test('a refusal never carries the value', () {
      final outcome =
          run('SELECT credentials_host_id FROM media_subscriptions')
              as SqlWindowFailure;
      expect('${outcome.message} ${outcome.details}', isNot(contains('host-')));
    });
  });
}
