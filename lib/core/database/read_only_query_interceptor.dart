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
  /// [onRefused] hears each refused statement as well: a pop-out passes it
  /// to the main window, whose log is the one written to a file.
  ReadOnlyQueryInterceptor({this.onRefused});

  final void Function(String statement)? onRefused;

  static final _select = RegExp(r'^\s*SELECT\b', caseSensitive: false);
  static final _with = RegExp(r'^\s*WITH\b', caseSensitive: false);
  static final _writeVerb = RegExp(
    r'\b(INSERT|UPDATE|DELETE|REPLACE|UPSERT|CREATE|DROP|ALTER)\b',
    caseSensitive: false,
  );
  static final _pragma = RegExp(
    r'^\s*PRAGMA\s+(?:\w+\.)?(\w+)\s*(?:\([^)]*\))?\s*;?\s*$',
    caseSensitive: false,
  );

  /// Pragmas that only report. Others (optimize, wal_checkpoint,
  /// incremental_vacuum, any with "=") change the database.
  static const _readingPragmas = {
    'application_id',
    'cipher_version',
    'collation_list',
    'compile_options',
    'data_version',
    'database_list',
    'encoding',
    'foreign_key_list',
    'foreign_keys',
    'freelist_count',
    'function_list',
    'index_info',
    'index_list',
    'index_xinfo',
    'journal_mode',
    'page_count',
    'page_size',
    'pragma_list',
    'schema_version',
    'table_info',
    'table_list',
    'table_xinfo',
    'user_version',
  };

  /// A second statement after a `;`, which sqlite runs too.
  static final _chained = RegExp(r';\s*\S');

  static bool _isRead(String statement) {
    if (_chained.hasMatch(statement)) return false;
    if (_select.hasMatch(statement)) return true;
    if (_with.hasMatch(statement)) return !_writeVerb.hasMatch(statement);
    final pragma = _pragma.firstMatch(statement);
    return pragma != null &&
        _readingPragmas.contains(pragma.group(1)!.toLowerCase());
  }

  Never _refuse(String statement) {
    final shown = statement.length > 80
        ? '${statement.substring(0, 80)}...'
        : statement;
    _log.warning('pop-out refused a write: $shown');
    // Also on the console in debug builds, where a missed writer shows up
    // while the pop-out is being tried by hand.
    if (kDebugMode) debugPrint('pop-out refused a write: $shown');
    onRefused?.call(shown);
    throw ReadOnlyViolation(shown);
  }

  void _checkRead(String statement) {
    if (!_isRead(statement)) _refuse(statement);
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
