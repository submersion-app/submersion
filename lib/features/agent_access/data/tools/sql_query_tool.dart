import 'package:submersion/features/agent_access/data/sql/sql_window.dart';
import 'package:submersion/features/agent_access/data/sql/sql_window_runner.dart';
import 'package:submersion/features/agent_access/data/tools/tool_args.dart';
import 'package:submersion/features/agent_access/domain/agent_tool.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';

/// Runs one read-only SQL statement for a question the other tools miss.
class SqlQueryTool implements AgentTool {
  SqlQueryTool({required SqlWindowRunner runner}) : _runner = runner;

  final SqlWindowRunner _runner;

  @override
  String get name => 'sql_query';

  @override
  String get description =>
      'Run one read-only SQL statement (SELECT, WITH or VALUES) against the '
      'logbook, for statistics the other tools do not provide. Read the '
      'submersion://schema resource first for the tables, columns and join '
      'keys. It reads every diver profile; filter on diver_id to answer for '
      'one. Values are returned as stored, not converted: lengths in metres, '
      'temperatures in Celsius, pressures in bar, weights in kg. Dive times '
      'are integers holding the local wall clock of the dive flagged as UTC, '
      'so do not shift them to another time zone. Pass values as params '
      'through ? placeholders. Results stop at max_rows (default '
      '$kSqlDefaultRows, at most $kSqlMaxRows), after '
      '${kSqlTimeCap.inSeconds} seconds, or at about '
      '${kSqlMaxResultBytes ~/ (1024 * 1024)} MiB, and row_cap_hit, '
      'time_cap_hit and size_cap_hit say which happened. One statement runs '
      'at a time, and a call made during another is refused with sql_busy. '
      'The time limit is checked between rows, so a statement that sorts or '
      'aggregates for a long time before its first row cannot be stopped: '
      'the tool answers with still_running true, and sql_busy continues '
      'until that statement ends. Add a LIMIT to recursive queries. '
      'Credentials, keys, media URLs, sync state, the change log and '
      'virtual tables (pragma_ functions, json_each) are refused with '
      'sql_refused. Blobs come back as their size. A string or blob over '
      '${kSqlMaxValueBytes ~/ (1024 * 1024)} MiB can fail the statement with '
      'sql_error, so name the columns you need instead of using * on a table '
      'that holds large blobs, and do not build huge strings.';

  @override
  Map<String, Object?> get inputSchema => const {
    'type': 'object',
    'properties': {
      'sql': {
        'type': 'string',
        'description': 'A single SELECT, WITH or VALUES statement.',
      },
      'params': {
        'type': 'array',
        'description':
            'Values for the ? placeholders, in order: strings, numbers, '
            'booleans or null.',
        'items': <String, Object?>{},
      },
      'max_rows': {
        'type': 'integer',
        'description':
            'The most rows to return. Default $kSqlDefaultRows, at most '
            '$kSqlMaxRows.',
      },
    },
    'required': ['sql'],
    'additionalProperties': false,
  };

  @override
  Future<Map<String, Object?>> call(
    Map<String, Object?> args,
    AgentToolContext context,
  ) async {
    final outcome = await _runner.run(
      sql: _sqlArg(args),
      params: _paramsArg(args),
      maxRows: intArg(
        args,
        'max_rows',
        fallback: kSqlDefaultRows,
        min: 1,
        max: kSqlMaxRows,
      ),
    );
    return switch (outcome) {
      final SqlWindowRows rows => rows.toJson(),
      final SqlWindowFailure failure => throw AgentToolException(
        failure.code,
        failure.message,
        details: failure.details,
      ),
    };
  }
}

String _sqlArg(Map<String, Object?> args) {
  final sql = args['sql'];
  if (sql is String && sql.trim().isNotEmpty) return sql;
  throw const AgentToolException(
    AgentToolErrorCode.invalidArgument,
    'sql must be a statement.',
  );
}

List<Object?> _paramsArg(Map<String, Object?> args) {
  final raw = args['params'];
  if (raw == null) return const [];
  if (raw is! List) {
    throw const AgentToolException(
      AgentToolErrorCode.invalidArgument,
      'params must be a list.',
    );
  }
  return [
    for (final value in raw)
      switch (value) {
        null || String() || num() => value,
        // SQLite has no boolean: the app stores them as 0 and 1.
        final bool flag => flag ? 1 : 0,
        _ => throw const AgentToolException(
          AgentToolErrorCode.invalidArgument,
          'Each of params must be a string, a number, a boolean or null.',
        ),
      },
  ];
}
