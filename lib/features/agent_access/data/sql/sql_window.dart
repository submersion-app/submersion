import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';

/// Rows a call returns when it does not ask for a number.
const int kSqlDefaultRows = 500;

/// The most rows a call may ask for.
const int kSqlMaxRows = 5000;

/// How long a statement may run, checked between rows.
const Duration kSqlTimeCap = Duration(seconds: 10);

/// The rough size of a result, which a row cap alone would not bound.
const int kSqlMaxResultBytes = 2 * 1024 * 1024;

/// The largest string or blob SQLite may build or read on this connection,
/// where the library lets it be set. See [limitSqlValueSize].
const int kSqlMaxValueBytes = 16 * 1024 * 1024;

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
