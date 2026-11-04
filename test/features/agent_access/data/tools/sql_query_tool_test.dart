import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/agent_access/data/sql/sql_window.dart';
import 'package:submersion/features/agent_access/data/sql/sql_window_runner.dart';
import 'package:submersion/features/agent_access/data/tools/sql_query_tool.dart';
import 'package:submersion/features/agent_access/domain/agent_tool.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';

import '../../../../helpers/test_database.dart';
import '../sql/sql_window_fixture.dart';

void main() {
  late SqlWindowFixture fixture;
  late AppDatabase db;
  late SqlQueryTool tool;

  setUpAll(() async {
    fixture = await SqlWindowFixture.create();
  });
  tearDownAll(() => fixture.dispose());

  setUp(() async {
    db = createTestDatabase();
    tool = SqlQueryTool(
      runner: SqlWindowRunner(
        file: () async => SqlDatabaseFile(path: fixture.path),
      ),
    );
  });
  tearDown(() => db.close());

  Future<Map<String, Object?>> call(Map<String, Object?> args) =>
      tool.call(args, AgentToolContext(db: db, clientName: null));

  Matcher refusedWith(AgentToolErrorCode code) =>
      throwsA(isA<AgentToolException>().having((e) => e.code, 'code', code));

  test('returns the documented result', () async {
    final result = await call({'sql': 'SELECT 1 AS one'});
    expect(result, {
      'columns': ['one'],
      'rows': [
        [1],
      ],
      'row_count': 1,
      'row_cap_hit': false,
      'time_cap_hit': false,
      'size_cap_hit': false,
      'still_running': false,
      'elapsed_ms': isA<int>(),
    });
  });

  test('passes params through, booleans as SQLite stores them', () async {
    final result = await call({
      'sql': 'SELECT ?, ?, ?, ?',
      'params': ['a', 1.5, true, null],
    });
    expect(result['rows'], [
      ['a', 1.5, 1, null],
    ]);
  });

  test('honours max_rows', () async {
    final result = await call({'sql': 'VALUES (1), (2), (3)', 'max_rows': 2});
    expect(result['row_count'], 2);
    expect(result['row_cap_hit'], true);
  });

  test('a denied table answers sql_refused with the table', () async {
    await expectLater(
      call({'sql': 'SELECT * FROM connected_accounts'}),
      throwsA(
        isA<AgentToolException>()
            .having((e) => e.code, 'code', AgentToolErrorCode.sqlRefused)
            .having((e) => e.details, 'details', {
              'table': 'connected_accounts',
            }),
      ),
    );
  });

  test('a bad statement answers sql_error', () async {
    await expectLater(
      call({'sql': 'SELECT nonsense_column FROM dives'}),
      refusedWith(AgentToolErrorCode.sqlError),
    );
  });

  test('refuses arguments that are not what the schema says', () async {
    for (final args in <Map<String, Object?>>[
      {},
      {'sql': 3},
      {'sql': '   '},
      {'sql': 'SELECT 1', 'params': 'x'},
      {
        'sql': 'SELECT ?',
        'params': [
          ['nested'],
        ],
      },
      {'sql': 'SELECT 1', 'max_rows': 0},
      {'sql': 'SELECT 1', 'max_rows': kSqlMaxRows + 1},
    ]) {
      await expectLater(
        call(args),
        refusedWith(AgentToolErrorCode.invalidArgument),
        reason: '$args',
      );
    }
  });

  test('the description warns of what an agent cannot see coming', () {
    final text = tool.description;
    expect(text, contains('submersion://schema'));
    expect(text, contains('$kSqlDefaultRows'));
    expect(text, contains('$kSqlMaxRows'));
    expect(text, contains('still_running'));
    expect(text, contains('sql_busy'));
    expect(text, contains('do not shift'));
    expect(text, contains('json_each'));
  });
}
