import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import 'package:submersion/core/services/logger_service.dart';

const _log = LoggerService('ReadOnlyQueryInterceptor');

/// A write a read-only connection refused.
class ReadOnlyViolation extends StateError {
  ReadOnlyViolation(String statement)
    : super('read-only connection refused: $statement');
}

/// Lets reads through and refuses every write (issue #5078).
///
/// A desktop pop-out window shares the main window's database and must never
/// change it, not even with something a provider derives and saves as a side
/// effect of viewing. Anything that tries is logged, so a missed writer shows
/// up in testing, and fails, so the database is never touched.
class ReadOnlyQueryInterceptor extends QueryInterceptor {
  static final _readStatement = RegExp(
    r'^\s*(SELECT|WITH)\b|^\s*PRAGMA\b[^=]*$',
    caseSensitive: false,
  );

  Never _refuse(String statement) {
    final shown = statement.length > 80
        ? '${statement.substring(0, 80)}...'
        : statement;
    _log.warning('pop-out refused a write: $shown');
    // Also on the console in debug builds, where a missed writer shows up
    // while the pop-out is being tried by hand.
    if (kDebugMode) debugPrint('pop-out refused a write: $shown');
    throw ReadOnlyViolation(shown);
  }

  void _checkRead(String statement) {
    if (!_readStatement.hasMatch(statement)) _refuse(statement);
  }

  @override
  TransactionExecutor beginTransaction(QueryExecutor parent) =>
      _refuse('BEGIN TRANSACTION');

  @override
  QueryExecutor beginExclusive(QueryExecutor parent) =>
      _refuse('BEGIN EXCLUSIVE');

  @override
  Future<void> runBatched(
    QueryExecutor executor,
    BatchedStatements statements,
  ) async => _refuse(statements.statements.join('; '));

  @override
  Future<void> runCustom(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    _checkRead(statement);
    return executor.runCustom(statement, args);
  }

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async => _refuse(statement);

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async => _refuse(statement);

  @override
  Future<int> runDelete(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) async => _refuse(statement);

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    _checkRead(statement);
    return executor.runSelect(statement, args);
  }
}
