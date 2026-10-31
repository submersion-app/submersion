/// Generates the change log's capture triggers (issue #3922).
///
/// Pure string building, so it can be tested without a database. Every
/// statement fires inside someone's save, so nothing here may depend on data
/// that could be missing: see [ChangeLogTableSpec.narrowedTo].
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import 'package:submersion/core/database/change_log/change_log_policy.dart';

const kChangeLogTriggerPrefix = 'change_log_trg_';

/// Milliseconds since the epoch. `unixepoch('subsec')` is not on every
/// SQLCipher build we ship.
const _nowSql = "CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER)";

/// A table as the triggers see it.
class ChangeLogTableSpec {
  const ChangeLogTableSpec({
    required this.table,
    required this.keyColumns,
    required this.columns,
  });

  final String table;
  final List<String> keyColumns;
  final List<String> columns;

  /// This spec without the columns [present] lacks. SQLite accepts
  /// `OLD."missing"` when a trigger is created and fails when it fires, so a
  /// column drift declares that an upgraded file lacks would otherwise fail
  /// the diver's save.
  ChangeLogTableSpec narrowedTo(Set<String> present) => ChangeLogTableSpec(
    table: table,
    keyColumns: keyColumns,
    columns: [
      for (final column in columns)
        if (present.contains(column)) column,
    ],
  );
}

List<ChangeLogTableSpec> changeLogSpecsFor(GeneratedDatabase db) => [
  for (final table in db.allTables)
    ChangeLogTableSpec(
      table: table.actualTableName,
      keyColumns: [for (final column in table.$primaryKey) column.name],
      columns: [for (final column in table.$columns) column.name],
    ),
];

/// The record id, in the form `syncRecordId` gives it.
String changeLogRecordIdSql(String prefix, List<String> keyColumns) =>
    keyColumns.map((column) => '$prefix."$column"').join(" || '|' || ");

List<String> buildChangeLogTriggers(
  ChangeLogTableSpec spec,
  ChangeLogClass cls, {
  required int schemaVersion,
}) {
  if (cls == ChangeLogClass.excluded) return const [];
  // A key the file lacks would fail every write to this table.
  if (spec.keyColumns.isEmpty ||
      !spec.keyColumns.every(spec.columns.contains)) {
    return const [];
  }
  final update = _updateTrigger(spec, schemaVersion);
  return [
    if (cls == ChangeLogClass.tracked) _insertTrigger(spec, schemaVersion),
    if (cls == ChangeLogClass.tracked && update != null) update,
    _deleteTrigger(spec, schemaVersion),
  ];
}

String changeLogTriggersHash(List<String> statements) =>
    sha256.convert(utf8.encode(statements.join('\n'))).toString();

String _triggerName(String table, String action) =>
    '$kChangeLogTriggerPrefix${table}_$action';

String _guard(String table, String prefix) {
  final row = changeLogRowGuard(table, prefix);
  return [
    'COALESCE((SELECT suppressed_until FROM change_log_context WHERE id = 1), '
        '0) <= $_nowSql',
    ?row,
  ].join(' AND ');
}

String _eventInsert(
  ChangeLogTableSpec spec,
  String prefix,
  String action,
  int schemaVersion,
) =>
    'INSERT INTO change_log_events '
    '(operation_id, table_name, record_id, action, changed_at, '
    'schema_version) VALUES ('
    '(SELECT CASE WHEN scope_expires_at > $_nowSql THEN operation_id END '
    'FROM change_log_context WHERE id = 1), '
    "'${spec.table}', "
    '${changeLogRecordIdSql(prefix, spec.keyColumns)}, '
    "'$action', $_nowSql, $schemaVersion);";

String _insertTrigger(ChangeLogTableSpec spec, int schemaVersion) =>
    'CREATE TRIGGER "${_triggerName(spec.table, 'i')}" '
    'AFTER INSERT ON "${spec.table}" '
    'WHEN ${_guard(spec.table, 'NEW')} '
    'BEGIN ${_eventInsert(spec, 'NEW', 'I', schemaVersion)} END';

/// Null when no column of the table is worth recording.
String? _updateTrigger(ChangeLogTableSpec spec, int schemaVersion) {
  final ignored = changeLogIgnoredColumns(spec.table);
  final columns = spec.columns.where((c) => !ignored.contains(c)).toList();
  if (columns.isEmpty) return null;

  final differs = columns.map((c) => 'OLD."$c" IS NOT NEW."$c"').join(' OR ');
  // One row per column rather than a JSON object, because SQLite's function
  // argument limit is below the width of `diver_settings`.
  final values = columns
      .map((c) => "SELECT '$c' AS c, OLD.\"$c\" AS o, NEW.\"$c\" AS n")
      .join(' UNION ALL ');
  return 'CREATE TRIGGER "${_triggerName(spec.table, 'u')}" '
      'AFTER UPDATE ON "${spec.table}" '
      'WHEN ${_guard(spec.table, 'NEW')} AND ($differs) '
      'BEGIN ${_eventInsert(spec, 'NEW', 'U', schemaVersion)} '
      'INSERT INTO change_log_fields '
      '(event_id, column_name, old_value, new_value) '
      'SELECT last_insert_rowid(), c, o, n FROM ($values) WHERE o IS NOT n; '
      'END';
}

/// Keeps ignored columns, unlike an update, because a restore needs them.
String _deleteTrigger(ChangeLogTableSpec spec, int schemaVersion) {
  final values = spec.columns
      .where((c) => !changeLogDeleteCopySkips(c))
      .map((c) => "SELECT '$c' AS c, OLD.\"$c\" AS o")
      .join(' UNION ALL ');
  return 'CREATE TRIGGER "${_triggerName(spec.table, 'd')}" '
      'AFTER DELETE ON "${spec.table}" '
      'WHEN ${_guard(spec.table, 'OLD')} '
      'BEGIN ${_eventInsert(spec, 'OLD', 'D', schemaVersion)} '
      'INSERT INTO change_log_fields '
      '(event_id, column_name, old_value, new_value) '
      'SELECT last_insert_rowid(), c, o, NULL FROM ($values) '
      'WHERE o IS NOT NULL; '
      'END';
}
