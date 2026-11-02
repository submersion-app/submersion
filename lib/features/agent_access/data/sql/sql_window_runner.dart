import 'dart:async';
import 'dart:isolate';

import 'package:submersion/features/agent_access/data/sql/sql_window.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';

/// How long past the time cap a call waits before answering without the
/// worker. The worker checks the cap between rows, so one that is keeping up
/// always answers first.
const Duration kSqlReplyGrace = Duration(seconds: 2);

/// The database file as it is right now.
class SqlDatabaseFile {
  const SqlDatabaseFile({required this.path, this.keyHex});

  final String path;
  final String? keyHex;
}

typedef SqlWindowWorker =
    Future<SqlWindowOutcome> Function(SqlWindowRequest request);

/// Top level, so the closure it hands to the isolate captures only [request].
Future<SqlWindowOutcome> _runOnWorkerIsolate(SqlWindowRequest request) =>
    Isolate.run(() => runSqlWindow(request));

/// Runs statements off the UI isolate, one at a time.
///
/// One runner serves the listener's whole life: the 2026 protocol builds a
/// server per request, and the busy flag has to outlive those.
///
/// A statement that stays inside one native step cannot be stopped. Nothing
/// here can reach it: `Isolate.kill` acts only when the step returns, and this
/// SQLite build has no progress callback. So the call answers anyway with
/// `still_running`, and later calls answer `sql_busy` until the worker ends,
/// which keeps a few bad statements from taking a thread each.
class SqlWindowRunner {
  SqlWindowRunner({
    required Future<SqlDatabaseFile> Function() file,
    SqlWindowWorker worker = _runOnWorkerIsolate,
    Duration timeCap = kSqlTimeCap,
    Duration replyGrace = kSqlReplyGrace,
  }) : _file = file,
       _worker = worker,
       _timeCap = timeCap,
       _replyGrace = replyGrace;

  final Future<SqlDatabaseFile> Function() _file;
  final SqlWindowWorker _worker;
  final Duration _timeCap;
  final Duration _replyGrace;

  bool _busy = false;

  Future<SqlWindowOutcome> run({
    required String sql,
    List<Object?> params = const [],
    int maxRows = kSqlDefaultRows,
  }) async {
    if (_busy) {
      return const SqlWindowFailure(
        AgentToolErrorCode.sqlBusy,
        'An earlier statement is still running and cannot be stopped. Try '
        'again later; quitting the app ends it.',
      );
    }
    _busy = true;
    final clock = Stopwatch()..start();
    final Future<SqlWindowOutcome> work;
    try {
      // The path and key are read per call: a restore, a storage move or an
      // encryption change between calls must take effect on the next one.
      final file = await _file();
      work = _worker(
        SqlWindowRequest(
          path: file.path,
          keyHex: file.keyHex,
          sql: sql,
          params: params,
          maxRows: maxRows,
          timeCap: _timeCap,
        ),
      );
    } catch (_) {
      _busy = false;
      rethrow;
    }
    final done = work.whenComplete(() => _busy = false);
    try {
      return await done.timeout(_timeCap + _replyGrace);
    } on TimeoutException {
      // The worker's own failure, if it ever fails, has nobody left to tell.
      done.ignore();
      return SqlWindowRows(
        columns: const [],
        rows: const [],
        elapsed: clock.elapsed,
        timeCapHit: true,
        stillRunning: true,
      );
    }
  }
}
