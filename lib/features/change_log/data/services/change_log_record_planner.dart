import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:submersion/core/database/change_log/change_log_policy.dart';
import 'package:submersion/core/database/change_log/change_log_rewrites.dart';
import 'package:submersion/core/database/change_log/change_log_trigger_sql.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_dependencies.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_event.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_revert_plan.dart';

String _keyOf(ChangeLogEvent event) =>
    changeLogRecordKey(event.table, event.recordId);

String _rootKeyOf(ChangeLogEvent event) =>
    changeLogRecordKey(event.root.table, event.root.id);

/// A WHERE clause and its values.
typedef _ReadingSql = ({String sql, List<Variable<Object>> variables});

/// The table whose manual edits are never a reading.
const _profileTable = 'dive_profile_series';

/// Works out which deleted records can return and which created records can
/// go, before anything is written.
class ChangeLogRecordPlanner {
  ChangeLogRecordPlanner(
    this._db,
    this._repository,
    this._dependencies,
    this._rewrittenColumns, {
    Map<String, ChangeLogValueRepair> rewrittenValues =
        changeLogRewrittenValues,
  }) : _rewrittenValues = rewrittenValues;

  final AppDatabase _db;
  final ChangeLogRepository _repository;
  final ChangeLogDependencyIndex _dependencies;
  final Map<String, int> _rewrittenColumns;
  final Map<String, ChangeLogValueRepair> _rewrittenValues;

  /// Restores for the deletes among [events]. A record that cannot return
  /// takes down whatever needed it, so this repeats until nothing changes.
  Future<List<ChangeLogRevertItem>> planRestores(
    List<ChangeLogEvent> events,
  ) async {
    // A record deleted twice in one entry returns as it last stood.
    final deletes = {
      for (final event in events)
        if (event.action == ChangeLogAction.delete) _keyOf(event): event,
    }.values.toList();
    final blocks = <String, ChangeLogBlock>{};
    final restoring = <String>{};
    // The rows the same revert removes, which a replaced reading returns in
    // place of.
    final removing = {
      for (final event in events)
        if (event.action == ChangeLogAction.insert) _keyOf(event),
    };
    for (final event in deletes) {
      final block =
          await _restoreBlock(event) ??
          (await _superseded(event, removing)
              ? ChangeLogBlock.alreadyRestored
              : null);
      if (block == null) {
        restoring.add(_keyOf(event));
      } else {
        blocks[_keyOf(event)] = block;
      }
    }

    var changed = true;
    while (changed) {
      changed = false;
      for (final event in deletes) {
        final key = _keyOf(event);
        if (!restoring.contains(key)) continue;
        final row = {for (final f in event.fields) f.column: f.oldValue};
        final missing = await _dependencies.missingParents(
          event.table,
          row,
          restoring,
        );
        if (missing.isEmpty) continue;
        restoring.remove(key);
        blocks[key] = ChangeLogBlock.parentGone;
        changed = true;
      }
    }

    return [
      for (final event in deletes)
        ChangeLogRevertItem(event: event, block: blocks[_keyOf(event)]),
    ];
  }

  /// Whether a newer reading of the same source has replaced the row
  /// [event] deleted ([changeLogReadingColumns]): a live row of its reading,
  /// written since the delete, that this revert does not remove. Reverting
  /// an older re-parse after a newer one would otherwise bring the old strand
  /// back beside the new (issue #4848). A row older than the delete is one
  /// the operation kept, such as the unmarked edit a re-parse leaves beside
  /// the recording it replaces (issue #4529), and says nothing.
  Future<bool> _superseded(ChangeLogEvent event, Set<String> removing) async {
    final reading = _readingOf(event.table, _copyOf(event));
    final spec = _repository.specOf(event.table);
    if (reading == null || spec == null) return false;
    final rows = await _db
        .customSelect(
          'SELECT ${changeLogRecordIdSql('"${event.table}"', spec.keyColumns)} '
          'AS record_id FROM "${event.table}" '
          'WHERE ${reading.sql} AND created_at >= ?',
          variables: [
            ...reading.variables,
            Variable<int>(event.changedAt.millisecondsSinceEpoch),
          ],
        )
        .get();
    return rows.any(
      (row) => !removing.contains(
        changeLogRecordKey(event.table, row.read<String>('record_id')),
      ),
    );
  }

  /// Pairs each replaced reading with the rows that replaced it, so a revert
  /// leaves a source with neither two readings nor none (issue #4848). A new
  /// row stays while a row of the reading it replaced cannot return, as when
  /// that row's computer has since been deleted. A replaced row returns only
  /// with its replacement's removal, so it changed since when that removal
  /// did: a revert of only what did not change keeps both out. A reading
  /// that is already back loses nothing.
  Future<
    ({List<ChangeLogRevertItem> restores, List<ChangeLogRevertItem> removals})
  >
  pairReadings(
    List<ChangeLogRevertItem> restores,
    List<ChangeLogRevertItem> removals,
  ) async {
    String? keyOf(ChangeLogRevertItem item) =>
        _readingKey(item.event.table, _copyOf(item.event));
    final stranded = {
      for (final item in restores)
        if (item.block case final block?
            when block != ChangeLogBlock.alreadyRestored)
          ?keyOf(item),
    };
    final pairedRemovals = <ChangeLogRevertItem>[];
    final changed = <String>{};
    for (final item in removals) {
      final key = await _liveReadingKey(item.event);
      final kept = !item.isBlocked && key != null && stranded.contains(key);
      final paired = kept
          ? item.copyWith(block: ChangeLogBlock.parentGone)
          : item;
      if (key != null && !paired.isBlocked && paired.changedSince) {
        changed.add(key);
      }
      pairedRemovals.add(paired);
    }
    return (
      restores: [
        for (final item in restores)
          if (!item.isBlocked && changed.contains(keyOf(item)))
            item.copyWith(changedSince: true)
          else
            item,
      ],
      removals: pairedRemovals,
    );
  }

  /// The reading key of the live row [event] created, null when it has gone
  /// or its table has no readings.
  Future<String?> _liveReadingKey(ChangeLogEvent event) async {
    final columns = changeLogReadingColumns[event.table];
    final spec = _repository.specOf(event.table);
    if (columns == null || spec == null) return null;
    final match = changeLogKeyMatch(spec, event.recordId);
    final row = await _db
        .customSelect(
          'SELECT ${[...columns, 'computer_id', if (event.table == _profileTable) 'is_edit'].map((c) => '"$c"').join(', ')} '
          'FROM "${event.table}" WHERE ${match.where}',
          variables: match.variables,
        )
        .getSingleOrNull();
    return row == null ? null : _readingKey(event.table, row.data);
  }

  /// The reading [row] of [table] belongs to, as one comparable value, or
  /// null for a table with no readings or a manual edit, which is none.
  static String? _readingKey(String table, Map<String, Object?> row) {
    final named = _namedColumns(table, row);
    return named == null
        ? null
        : jsonEncode([
            table,
            for (final c in named) [c, row[c]],
          ]);
  }

  /// The columns that name the reading of [row] ([changeLogReadingColumns]),
  /// the computer only for a row with no source, or null when it has none.
  static List<String>? _namedColumns(String table, Map<String, Object?> row) {
    final columns = changeLogReadingColumns[table];
    if (columns == null) return null;
    if (table == _profileTable && _isTrue(row['is_edit'])) return null;
    return [...columns, if (row['source_id'] == null) 'computer_id'];
  }

  static Map<String, Object?> _copyOf(ChangeLogEvent event) => {
    for (final f in event.fields) f.column: f.oldValue,
  };

  /// The rows of [table] in the reading [row] belongs to, as SQL, or null
  /// for a table with no readings or a manual edit, which is none.
  static _ReadingSql? _readingOf(String table, Map<String, Object?> row) {
    final named = _namedColumns(table, row);
    if (named == null) return null;
    return (
      sql: [
        for (final c in named) '"$c" IS ?',
        if (table == _profileTable) 'COALESCE(is_edit, 0) = 0',
      ].join(' AND '),
      variables: [for (final c in named) Variable<Object>(row[c])],
    );
  }

  static bool _isTrue(Object? value) => value == 1 || value == true;

  Future<ChangeLogBlock?> _restoreBlock(ChangeLogEvent event) async {
    if (_repository.specOf(event.table) == null) {
      return ChangeLogBlock.columnGone;
    }
    if (await _repository.recordExists(event.table, event.recordId)) {
      return ChangeLogBlock.alreadyRestored;
    }
    for (final field in event.fields) {
      if (changeLogValueRewritten(
        _rewrittenColumns,
        event.table,
        field.column,
        event.schemaVersion,
        rewrittenValues: _rewrittenValues,
      )) {
        return ChangeLogBlock.rewritten;
      }
    }
    return null;
  }

  /// Removals for the inserts among [events]. A record that has already gone
  /// has nothing left to remove. [releasing] are the links the same revert
  /// takes back (see [settleRemovals]).
  Future<List<ChangeLogRevertItem>> planRemovals(
    List<ChangeLogEvent> events, {
    Map<String, Object?> releasing = const {},
  }) async {
    final created = <ChangeLogEvent>[];
    final changed = <String>{};
    for (final event in events) {
      if (event.action != ChangeLogAction.insert) continue;
      if (!await _repository.recordExists(event.table, event.recordId)) {
        continue;
      }
      created.add(event);
      if (await _changedSince(event)) changed.add(_keyOf(event));
    }
    // A dive skipped because it was edited keeps what belongs to it, so its
    // children count as changed along with it.
    return settleRemovals([
      for (final event in created)
        ChangeLogRevertItem(
          event: event,
          changedSince:
              changed.contains(_keyOf(event)) ||
              changed.contains(_rootKeyOf(event)),
        ),
    ], releasing: releasing);
  }

  /// The links [edits] put back, as [settleRemovals] takes them: each column
  /// an edit that applies returns to another value, by
  /// [changeLogLinkKey], with the value it returns to.
  static Map<String, Object?> releasedLinks(
    Iterable<ChangeLogRevertItem> edits,
  ) => {
    for (final item in edits)
      if (item.column case final column? when !item.isBlocked)
        changeLogLinkKey(item.event.table, item.event.recordId, column):
            item.target,
  };

  /// Marks [items] that data outside them still uses. Keeping one can keep
  /// another that it points at, and everything that belongs to it, so this
  /// repeats until nothing changes. A link the same revert sets back to
  /// another value, one of [releasing] (see [releasedLinks]), is no use:
  /// edits go back before created records go, so it has gone by then, as
  /// when an operation made a dive and linked a plan to it.
  /// Both kinds of foreign key need this: a no-action key would fail the
  /// removal and roll back the whole undo, and a cascading one would silently
  /// strip the record from later data.
  Future<List<ChangeLogRevertItem>> settleRemovals(
    List<ChangeLogRevertItem> items, {
    Map<String, Object?> releasing = const {},
  }) async {
    final removing = {for (final item in items) _keyOf(item.event)};
    final kept = <String>{};
    final referencesOf = <String, List<ChangeLogReference>>{};
    var changed = true;
    while (changed) {
      changed = false;
      for (final item in items) {
        final key = _keyOf(item.event);
        if (!removing.contains(key)) continue;
        final references = referencesOf[key] ??= await _dependencies
            .referencesTo(item.event.table, item.event.recordId);
        bool released(ChangeLogReference r) {
          final link = changeLogLinkKey(r.table, r.recordId, r.column);
          return releasing.containsKey(link) &&
              releasing[link] != item.event.recordId;
        }

        final inUse = references.any(
          (r) =>
              !r.isOwnedChild &&
              !removing.contains(changeLogRecordKey(r.table, r.recordId)) &&
              !released(r),
        );
        // A record that stays keeps what belongs to it.
        if (!inUse && !await _ownerKept(item.event, kept)) continue;
        removing.remove(key);
        kept.add(key);
        changed = true;
      }
    }
    return [
      for (final item in items)
        kept.contains(_keyOf(item.event))
            ? item.copyWith(block: ChangeLogBlock.inUse)
            : item,
    ];
  }

  /// Whether the record [event]'s row belongs to is staying: its root, or the
  /// row directly above it, which the repeat in [settleRemovals] carries down
  /// any further levels.
  Future<bool> _ownerKept(ChangeLogEvent event, Set<String> kept) async {
    if (kept.isEmpty) return false;
    if (kept.contains(_rootKeyOf(event))) return true;
    final parent = changeLogParents[event.table];
    if (parent == null) return false;
    final owner = await _repository.liveValue(
      event.table,
      event.recordId,
      parent.column,
    );
    return owner is String &&
        kept.contains(changeLogRecordKey(parent.rootTable, owner));
  }

  /// Whether anything happened to the record, or to a row that belongs to
  /// it, after [event]'s entry.
  Future<bool> _changedSince(ChangeLogEvent event) async {
    final later = await _db
        .customSelect(
          'SELECT 1 FROM change_log_events WHERE id > ? '
          'AND (operation_id IS NULL OR operation_id != ?) '
          'AND ((table_name = ? AND record_id = ?) '
          'OR (root_table = ? AND root_id = ?)) LIMIT 1',
          variables: [
            Variable<int>(event.id),
            Variable<String>(event.operationId),
            Variable<String>(event.table),
            Variable<String>(event.recordId),
            Variable<String>(event.table),
            Variable<String>(event.recordId),
          ],
        )
        .get();
    return later.isNotEmpty;
  }
}
