import 'package:drift/drift.dart';

import 'package:submersion/core/database/change_log/change_log_policy.dart';
import 'package:submersion/core/database/change_log/change_log_trigger_sql.dart';
import 'package:submersion/core/database/database.dart';

/// A row that points at another through a foreign key.
class ChangeLogReference {
  const ChangeLogReference({
    required this.table,
    required this.column,
    required this.recordId,
  });

  final String table;
  final String column;
  final String recordId;

  /// Whether this row belongs to the record it points at, as a dive's tank
  /// does: it goes when that record goes, so it is an edit to the record
  /// rather than a use of it.
  bool get isOwnedChild {
    final parent = changeLogParents[table];
    return parent != null && parent.column == column;
  }
}

class _ForeignKey {
  const _ForeignKey(this.table, this.column, this.parent, this.parentColumn);

  final String table;
  final String column;
  final String parent;
  final String parentColumn;
}

/// The foreign keys of this file, read from `PRAGMA foreign_key_list`, so a
/// key added by a future rung is seen without a list to keep up to date.
class ChangeLogDependencyIndex {
  ChangeLogDependencyIndex._(this._db, this._keys, this._specs);

  final AppDatabase _db;
  final List<_ForeignKey> _keys;
  final Map<String, ChangeLogTableSpec> _specs;

  static Future<ChangeLogDependencyIndex> load(AppDatabase db) async {
    final rows = await db
        .customSelect(
          'SELECT m.name AS tbl, f."table" AS parent, f."from" AS col, '
          'f."to" AS target FROM sqlite_master m '
          "JOIN pragma_foreign_key_list(m.name) f WHERE m.type = 'table'",
        )
        .get();
    return ChangeLogDependencyIndex._(
      db,
      [
        for (final row in rows)
          _ForeignKey(
            row.read<String>('tbl'),
            row.read<String>('col'),
            row.read<String>('parent'),
            row.data['target'] as String? ?? 'id',
          ),
      ],
      {for (final spec in changeLogSpecsFor(db)) spec.table: spec},
    );
  }

  /// Rows of tracked tables that point at the record. Machine rows are left
  /// out: they belong to their record and go with it, so they never make it
  /// "in use".
  Future<List<ChangeLogReference>> referencesTo(
    String table,
    String recordId,
  ) async {
    final references = <ChangeLogReference>[];
    for (final key in _keys) {
      if (key.parent != table) continue;
      if (changeLogTables[key.table] != ChangeLogClass.tracked) continue;
      final spec = _specs[key.table];
      if (spec == null) continue;
      final rows = await _db
          .customSelect(
            'SELECT ${changeLogRecordIdSql('"${key.table}"', spec.keyColumns)} '
            'AS record_id FROM "${key.table}" WHERE "${key.column}" = ?',
            variables: [Variable<String>(recordId)],
          )
          .get();
      for (final row in rows) {
        references.add(
          ChangeLogReference(
            table: key.table,
            column: key.column,
            recordId: row.read<String>('record_id'),
          ),
        );
      }
    }
    return references;
  }

  /// The parents [row] needs that neither exist nor are in [restoring], each
  /// as `table|id`.
  Future<List<String>> missingParents(
    String table,
    Map<String, Object?> row,
    Set<String> restoring,
  ) async {
    final missing = <String>[];
    for (final key in _keys) {
      if (key.table != table) continue;
      final value = row[key.column];
      if (value == null) continue;
      final parent = '${key.parent}|$value';
      if (restoring.contains(parent)) continue;
      final found = await _db
          .customSelect(
            'SELECT 1 FROM "${key.parent}" WHERE "${key.parentColumn}" = ?',
            variables: [Variable<Object>(value)],
          )
          .getSingleOrNull();
      if (found == null) missing.add(parent);
    }
    return missing;
  }
}
