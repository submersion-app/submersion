import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart'
    show Database, OpenMode, PreparedStatement, SqliteException;

import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/agent_access/data/sql/sql_read_catalog.dart';
import 'package:submersion/features/agent_access/data/sql/sql_statement_guard.dart';
import 'package:submersion/features/agent_access/data/sql/sql_value_limit.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';

/// Rows a call returns when it does not ask for a number.
const int kSqlDefaultRows = 500;

/// The most rows a call may ask for.
const int kSqlMaxRows = 5000;

/// How long a statement may run, checked between rows.
const Duration kSqlTimeCap = Duration(seconds: 10);

/// The rough size of a result, which a row cap alone would not bound.
const int kSqlMaxResultBytes = 2 * 1024 * 1024;

/// The largest string or blob SQLite may build or read on this connection.
const int kSqlMaxValueBytes = 16 * 1024 * 1024;

/// Every cell costs at least this, so a million NULLs still count.
const int _cellBaseBytes = 8;

/// One statement to run. Plain data, so it can cross to a worker isolate.
class SqlWindowRequest {
  const SqlWindowRequest({
    required this.path,
    required this.sql,
    this.keyHex,
    this.params = const [],
    this.maxRows = kSqlDefaultRows,
    this.timeCap = kSqlTimeCap,
    this.maxBytes = kSqlMaxResultBytes,
  });

  final String path;
  final String? keyHex;
  final String sql;
  final List<Object?> params;
  final int maxRows;
  final Duration timeCap;
  final int maxBytes;
}

/// What a call came to. Plain data, for the same reason.
sealed class SqlWindowOutcome {
  const SqlWindowOutcome();
}

/// The statement ran, as far as its caps allowed.
class SqlWindowRows extends SqlWindowOutcome {
  const SqlWindowRows({
    required this.columns,
    required this.rows,
    required this.elapsed,
    this.rowCapHit = false,
    this.timeCapHit = false,
    this.sizeCapHit = false,
    this.stillRunning = false,
  });

  final List<String> columns;
  final List<List<Object?>> rows;
  final Duration elapsed;
  final bool rowCapHit;
  final bool timeCapHit;
  final bool sizeCapHit;

  /// The worker is still inside a native step. See [SqlWindowRunner].
  final bool stillRunning;

  Map<String, Object?> toJson() => {
    'columns': columns,
    'rows': rows,
    'row_count': rows.length,
    'row_cap_hit': rowCapHit,
    'time_cap_hit': timeCapHit,
    'size_cap_hit': sizeCapHit,
    'still_running': stillRunning,
    'elapsed_ms': elapsed.inMilliseconds,
  };
}

/// The statement was refused or failed.
class SqlWindowFailure extends SqlWindowOutcome {
  const SqlWindowFailure(this.code, this.message, {this.details});

  final AgentToolErrorCode code;
  final String message;
  final Map<String, Object?>? details;
}

/// Runs one statement on a read-only connection of its own and closes it.
///
/// Synchronous: a step blocks the isolate it runs on, so the app calls this
/// through [SqlWindowRunner] and never on the UI isolate.
SqlWindowOutcome runSqlWindow(SqlWindowRequest request) {
  final clock = Stopwatch()..start();
  final keyword = sqlLeadingKeyword(request.sql);
  if (keyword == null || !kSqlAllowedKeywords.contains(keyword)) {
    return const SqlWindowFailure(
      AgentToolErrorCode.sqlRefused,
      'Only a single SELECT, WITH or VALUES statement may run.',
    );
  }

  final Database db;
  try {
    db = DatabaseService.openRaw(
      request.path,
      mode: OpenMode.readOnly,
      keyHex: request.keyHex,
    );
  } on SqliteException catch (e) {
    return SqlWindowFailure(
      AgentToolErrorCode.databaseUnavailable,
      'The database could not be opened: ${e.message}.',
    );
  }
  try {
    limitSqlValueSize(db, kSqlMaxValueBytes);
    db.execute('PRAGMA query_only = ON');
    db.execute('BEGIN');
    // Before anything is compiled: BEGIN is deferred and compiling holds no
    // lock, so this first read is what fixes the snapshot. The root pages and
    // the program inspected against them then cannot disagree.
    final catalog = SqlReadCatalog.load(db);
    return _run(db, request, catalog, clock);
  } on SqliteException catch (e) {
    return SqlWindowFailure(AgentToolErrorCode.sqlError, e.message);
  } finally {
    db.close();
  }
}

SqlWindowOutcome _run(
  Database db,
  SqlWindowRequest request,
  SqlReadCatalog catalog,
  Stopwatch clock,
) {
  final PreparedStatement statement;
  try {
    statement = db.prepare(request.sql, checkNoTail: true);
  } on ArgumentError {
    return const SqlWindowFailure(
      AgentToolErrorCode.sqlRefused,
      'Only one statement may run per call.',
    );
  }
  try {
    if (!statement.isReadOnly) {
      return const SqlWindowFailure(
        AgentToolErrorCode.sqlRefused,
        'Only read-only statements may run.',
      );
    }
    if (statement.parameterCount != request.params.length) {
      return SqlWindowFailure(
        AgentToolErrorCode.invalidArgument,
        'The statement has ${statement.parameterCount} parameters but '
        '${request.params.length} were given.',
      );
    }
    final refusal = inspectSqlProgram(_explain(db, request), catalog);
    if (refusal != null) {
      return SqlWindowFailure(
        AgentToolErrorCode.sqlRefused,
        refusal.message,
        details: refusal.details,
      );
    }
    return _collect(statement, request, clock);
  } finally {
    statement.close();
  }
}

List<SqlExplainStep> _explain(Database db, SqlWindowRequest request) => [
  for (final row in db.select('EXPLAIN ${request.sql}', request.params))
    SqlExplainStep(
      opcode: row['opcode'] as String,
      p1: row['p1'] as int,
      p2: row['p2'] as int,
      p3: row['p3'] as int,
      p5: row['p5'] as int,
    ),
];

SqlWindowRows _collect(
  PreparedStatement statement,
  SqlWindowRequest request,
  Stopwatch clock,
) {
  final cursor = statement.selectCursor(request.params);
  final columns = cursor.columnNames;
  final rows = <List<Object?>>[];
  var bytes = 0;
  var rowCapHit = false;
  var timeCapHit = false;
  var sizeCapHit = false;
  while (cursor.moveNext()) {
    if (rows.length == request.maxRows) {
      rowCapHit = true;
      break;
    }
    final row = cursor.current;
    final cells = [
      for (var i = 0; i < columns.length; i++) _cell(row.columnAt(i)),
    ];
    bytes += cells.fold(0, (sum, cell) => sum + _cellBytes(cell));
    if (bytes > request.maxBytes) {
      sizeCapHit = true;
      break;
    }
    rows.add(cells);
    if (clock.elapsed >= request.timeCap) {
      timeCapHit = true;
      break;
    }
  }
  return SqlWindowRows(
    columns: columns,
    rows: rows,
    elapsed: clock.elapsed,
    rowCapHit: rowCapHit,
    timeCapHit: timeCapHit,
    sizeCapHit: sizeCapHit,
  );
}

/// A value as JSON can carry it. Bytes stay out of a tool result, as they do
/// from every document, and JSON has no infinity.
Object? _cell(Object? value) => switch (value) {
  final Uint8List bytes => {'blob_bytes': bytes.length},
  final double number when !number.isFinite => number.toString(),
  _ => value,
};

int _cellBytes(Object? cell) =>
    _cellBaseBytes + (cell is String ? cell.length : 0);
