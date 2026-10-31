import 'package:drift/drift.dart';

import 'package:submersion/core/database/change_log/change_log_policy.dart';
import 'package:submersion/core/database/change_log/change_log_trigger_sql.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_event.dart';

/// A row that points at another through a foreign key.
class ChangeLogReference {
  const ChangeLogReference({
    required this.table,
    required this.column,
    required this.recordId,
    this.cascades = false,
    this.deletes = false,
  });

  final String table;
  final String column;
  final String recordId;

  /// Whether removing the record it points at also clears this row.
  final bool cascades;

  /// Whether removing the record it points at deletes this row, rather than
  /// only clearing the link.
  final bool deletes;

  /// Whether this row belongs to the record it points at, as a dive's tank
  /// does: it goes when that record goes, so it is an edit to the record
  /// rather than a use of it. A key with no delete action needs a child
  /// removed first, so such a row counts as a use.
  bool get isOwnedChild {
    final parent = changeLogParents[table];
    return cascades && parent != null && parent.column == column;
  }
}

/// Columns that hold another row's id with no constraint behind them, so
/// `PRAGMA foreign_key_list` cannot see them.
const List<({String table, String column, String parent})> _softReferences = [
  (table: 'trips', column: 'parent_trip_id', parent: 'trips'),
  (
    table: 'service_records',
    column: 'service_kind_id',
    parent: 'service_kinds',
  ),
  (
    table: 'service_schedules',
    column: 'service_kind_id',
    parent: 'service_kinds',
  ),
  (table: 'dive_dive_types', column: 'dive_type_id', parent: 'dive_types'),
  (table: 'site_site_types', column: 'site_type_id', parent: 'site_types'),
  (table: 'dive_plan_mission_members', column: 'buddy_id', parent: 'buddies'),
  (
    table: 'dive_plan_mission_members',
    column: 'scooter_equipment_id',
    parent: 'equipment',
  ),
];

class _ForeignKey {
  const _ForeignKey(
    this.table,
    this.column,
    this.parent,
    this.parentColumn,
    this.onDelete, {
    this.soft = false,
  });

  final String table;
  final String column;
  final String parent;
  final String parentColumn;

  /// SQLite's delete action, `NO ACTION` for a soft reference.
  final String onDelete;

  /// No constraint backs it, so nothing fails if the parent is missing.
  final bool soft;

  bool get deletes => onDelete == 'CASCADE';

  bool get cascades => deletes || onDelete == 'SET NULL';
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
          'f."to" AS target, f.on_delete AS on_delete FROM sqlite_master m '
          "JOIN pragma_foreign_key_list(m.name) f WHERE m.type = 'table'",
        )
        .get();
    final specs = {for (final spec in changeLogSpecsFor(db)) spec.table: spec};
    return ChangeLogDependencyIndex._(db, [
      for (final row in rows)
        _ForeignKey(
          row.read<String>('tbl'),
          row.read<String>('col'),
          row.read<String>('parent'),
          row.data['target'] as String? ?? 'id',
          row.read<String>('on_delete'),
        ),
      for (final soft in _softReferences)
        if (specs[soft.table]?.columns.contains(soft.column) ?? false)
          _ForeignKey(
            soft.table,
            soft.column,
            soft.parent,
            'id',
            'NO ACTION',
            soft: true,
          ),
    ], specs);
  }

  /// Rows that point at the record. Machine and excluded rows on a cascading
  /// key are left out: they go with the record, so they never make it "in
  /// use". On a key with no delete action any row counts, since the delete
  /// would fail.
  Future<List<ChangeLogReference>> referencesTo(
    String table,
    String recordId,
  ) async {
    final references = <ChangeLogReference>[];
    for (final key in _keys) {
      if (key.parent != table) continue;
      final tracked = changeLogTables[key.table] == ChangeLogClass.tracked;
      if (!tracked && key.cascades) continue;
      final keyColumns = _specs[key.table]?.keyColumns ?? const <String>[];
      final idSql = keyColumns.isEmpty
          ? "''"
          : changeLogRecordIdSql('"${key.table}"', keyColumns);
      final rows = await _db
          .customSelect(
            'SELECT $idSql AS record_id FROM "${key.table}" '
            'WHERE "${key.column}" = ?',
            variables: [Variable<String>(recordId)],
          )
          .get();
      for (final row in rows) {
        references.add(
          ChangeLogReference(
            table: key.table,
            column: key.column,
            recordId: row.read<String>('record_id'),
            cascades: key.cascades,
            deletes: key.deletes,
          ),
        );
      }
    }
    return references;
  }

  /// The tracked rows that a delete of the record takes with it, at any depth.
  /// SQLite writes no deletion log for these, so whoever deletes the record
  /// has to tombstone them.
  Future<List<ChangeLogReference>> cascadedRows(
    String table,
    String recordId,
  ) async {
    final found = <String, ChangeLogReference>{};
    Future<void> walk(String table, String recordId) async {
      for (final row in await referencesTo(table, recordId)) {
        if (!row.deletes) continue;
        final key = changeLogRecordKey(row.table, row.recordId);
        if (found.containsKey(key)) continue;
        found[key] = row;
        await walk(row.table, row.recordId);
      }
    }

    await walk(table, recordId);
    return found.values.toList();
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
      if (key.table != table || key.soft) continue;
      final value = row[key.column];
      if (value == null) continue;
      final parent = changeLogRecordKey(key.parent, value);
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
