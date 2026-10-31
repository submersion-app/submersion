import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_dependencies.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_event.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_revert_plan.dart';

String _recordKey(String table, String id) => '$table|$id';

String _keyOf(ChangeLogEvent event) => _recordKey(event.table, event.recordId);

String _rootKeyOf(ChangeLogEvent event) =>
    _recordKey(event.root.table, event.root.id);

/// Works out which deleted records can return and which created records can
/// go, before anything is written.
class ChangeLogRecordPlanner {
  ChangeLogRecordPlanner(
    this._db,
    this._repository,
    this._dependencies,
    this._rewrittenColumns,
  );

  final AppDatabase _db;
  final ChangeLogRepository _repository;
  final ChangeLogDependencyIndex _dependencies;
  final Map<String, int> _rewrittenColumns;

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
    for (final event in deletes) {
      final block = await _restoreBlock(event);
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

  Future<ChangeLogBlock?> _restoreBlock(ChangeLogEvent event) async {
    if (await _repository.recordExists(event.table, event.recordId)) {
      return ChangeLogBlock.alreadyRestored;
    }
    for (final field in event.fields) {
      final rewrittenAt = _rewrittenColumns['${event.table}.${field.column}'];
      if (rewrittenAt != null && event.schemaVersion < rewrittenAt) {
        return ChangeLogBlock.rewritten;
      }
    }
    return null;
  }

  /// Removals for the inserts among [events]. A record that has already gone
  /// has nothing left to remove.
  Future<List<ChangeLogRevertItem>> planRemovals(
    List<ChangeLogEvent> events,
  ) async {
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
    ]);
  }

  /// Marks [items] that data outside them still uses. Keeping one can keep
  /// another that it points at, and everything that belongs to it, so this
  /// repeats until nothing changes.
  /// Both kinds of foreign key need this: a no-action key would fail the
  /// removal and roll back the whole undo, and a cascading one would silently
  /// strip the record from later data.
  Future<List<ChangeLogRevertItem>> settleRemovals(
    List<ChangeLogRevertItem> items,
  ) async {
    final removing = {for (final item in items) _keyOf(item.event)};
    final kept = <String>{};
    var changed = true;
    while (changed) {
      changed = false;
      for (final item in items) {
        final key = _keyOf(item.event);
        if (!removing.contains(key)) continue;
        final references = await _dependencies.referencesTo(
          item.event.table,
          item.event.recordId,
        );
        final inUse = references.any(
          (r) =>
              !r.isOwnedChild &&
              !removing.contains(_recordKey(r.table, r.recordId)),
        );
        // A record that stays keeps what belongs to it.
        if (!inUse && !kept.contains(_rootKeyOf(item.event))) continue;
        removing.remove(key);
        kept.add(key);
        changed = true;
      }
    }
    return [
      for (final item in items)
        kept.contains(_keyOf(item.event))
            ? ChangeLogRevertItem(
                event: item.event,
                block: ChangeLogBlock.inUse,
                changedSince: item.changedSince,
              )
            : item,
    ];
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
