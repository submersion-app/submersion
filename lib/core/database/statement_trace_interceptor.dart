import 'package:drift/drift.dart';

/// Writes a line as each statement and transaction step starts and another
/// as it ends, so a step that never returns names itself: the last `start`
/// with no matching `done`.
///
/// Only the statement text is written, never the values bound to it. The
/// browser turns it on for a page whose local storage asks for it (issue
/// #4186): in Chromium a transaction there waited forever on the runners
/// the web smoke test runs on, and nowhere else.
class StatementTraceInterceptor extends QueryInterceptor {
  StatementTraceInterceptor(this._write);

  final void Function(String line) _write;
  int _last = 0;

  @override
  TransactionExecutor beginTransaction(QueryExecutor parent) {
    _write('[db ${++_last}] begin transaction');
    return parent.beginTransaction();
  }

  @override
  QueryExecutor beginExclusive(QueryExecutor parent) {
    _write('[db ${++_last}] begin exclusive');
    return parent.beginExclusive();
  }

  @override
  Future<bool> ensureOpen(QueryExecutor executor, QueryExecutorUser user) =>
      _trace('open', () => executor.ensureOpen(user));

  @override
  Future<void> commitTransaction(TransactionExecutor inner) =>
      _trace('commit', inner.send);

  @override
  Future<void> rollbackTransaction(TransactionExecutor inner) =>
      _trace('rollback', inner.rollback);

  @override
  Future<void> runBatched(
    QueryExecutor executor,
    BatchedStatements statements,
  ) => _trace(
    'batch of ${statements.arguments.length}',
    () => executor.runBatched(statements),
  );

  @override
  Future<void> runCustom(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _trace(
    'custom: ${_short(statement)}',
    () => executor.runCustom(statement, args),
  );

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _trace(
    'insert: ${_short(statement)}',
    () => executor.runInsert(statement, args),
  );

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _trace(
    'update: ${_short(statement)}',
    () => executor.runUpdate(statement, args),
  );

  @override
  Future<int> runDelete(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _trace(
    'delete: ${_short(statement)}',
    () => executor.runDelete(statement, args),
  );

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) => _trace(
    'select: ${_short(statement)}',
    () => executor.runSelect(statement, args),
  );

  Future<T> _trace<T>(String what, Future<T> Function() run) async {
    final id = ++_last;
    final watch = Stopwatch()..start();
    _write('[db $id] start $what');
    try {
      final result = await run();
      _write('[db $id] done in ${watch.elapsedMilliseconds} ms');
      return result;
    } catch (e) {
      _write(
        '[db $id] failed in ${watch.elapsedMilliseconds} ms: '
        '${e.runtimeType}',
      );
      rethrow;
    }
  }

  /// Long statements (an insert naming every column) are cut, keeping the
  /// part that says which table they touch.
  static String _short(String statement) {
    final flat = statement.replaceAll(RegExp(r'\s+'), ' ').trim();
    return flat.length > 120 ? '${flat.substring(0, 120)}...' : flat;
  }
}
