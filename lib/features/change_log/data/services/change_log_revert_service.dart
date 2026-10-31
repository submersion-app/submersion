import 'package:collection/collection.dart';
import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/change_log/change_log_policy.dart';
import 'package:submersion/core/database/change_log/change_log_rewrites.dart';
import 'package:submersion/core/database/change_log/change_log_trigger_sql.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/core/services/sync/sync_fact_groups.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_dependencies.dart';
import 'package:submersion/features/change_log/data/services/change_log_record_planner.dart';
import 'package:submersion/features/change_log/domain/change_log_entities.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_event.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_revert_plan.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/trip_cylinder_links.dart';
import 'package:submersion/features/rules/data/services/rule_applier_support.dart';

/// Puts logged changes back (issue #3922). A revert is a new edit, as an undo
/// is since #2705: it writes the value, marks the record pending under a fresh
/// clock and never restores a logged one, so peers accept it, and it is logged
/// in its own right, so it can be reverted too.
class ChangeLogRevertService {
  ChangeLogRevertService({
    ChangeLogRepository? repository,
    SyncRepository? sync,
    Map<String, int> rewrittenColumns = changeLogRewrittenColumns,
    void Function(Iterable<String> diveIds)? afterDiveWrites,
  }) : _repository = repository ?? ChangeLogRepository(),
       _sync = sync ?? SyncRepository(),
       _rewrittenColumns = rewrittenColumns,
       _afterDiveWrites = afterDiveWrites ?? refreshAfterRuleWrites;

  final ChangeLogRepository _repository;
  final SyncRepository _sync;
  final Map<String, int> _rewrittenColumns;
  final void Function(Iterable<String> diveIds) _afterDiveWrites;

  AppDatabase get _db => DatabaseService.instance.database;

  Future<ChangeLogRevertPlan> planField(int eventId, String column) async {
    final event = await _repository.getEvent(eventId);
    if (event == null) {
      throw ArgumentError.value(eventId, 'eventId', 'No such change log event');
    }
    // Every save to this field in the entry, not just this one: a Revert
    // goes back to what the entry found.
    final events = await _repository.getEvents(event.operationId);
    final items = await _planEdits(
      [
        for (final other in events)
          if (other.table == event.table && other.recordId == event.recordId)
            other,
      ],
      only: column,
      dependencies: await ChangeLogDependencyIndex.load(_db),
    );
    final operation = await _repository.getOperation(event.operationId);
    return ChangeLogRevertPlan(
      operationId: event.operationId,
      items: items,
      wholeOperation:
          operation?.eventCount == events.length &&
          netFieldChanges(events).length == 1,
    );
  }

  Future<ChangeLogRevertPlan> planEvent(int eventId) async {
    final event = await _repository.getEvent(eventId);
    if (event == null) {
      throw ArgumentError.value(eventId, 'eventId', 'No such change log event');
    }
    final operation = await _repository.getOperation(event.operationId);
    return ChangeLogRevertPlan(
      operationId: event.operationId,
      items: await _plan([event]),
      wholeOperation: operation?.eventCount == 1,
    );
  }

  Future<ChangeLogRevertPlan> planOperation(String operationId) async {
    final events = await _repository.getEvents(
      operationId,
      includeMachineRows: true,
    );
    return ChangeLogRevertPlan(
      operationId: operationId,
      items: await _plan(events),
      wholeOperation: true,
    );
  }

  /// Everything undoing [events] involves. An edit to a record the same
  /// events created goes with the record, so it is not listed.
  Future<List<ChangeLogRevertItem>> _plan(List<ChangeLogEvent> events) async {
    final dependencies = await ChangeLogDependencyIndex.load(_db);
    final planner = _plannerWith(dependencies);
    final created = {
      for (final event in events)
        if (event.action == ChangeLogAction.insert)
          (event.table, event.recordId),
    };
    final restores = await planner.planRestores(events);
    final restoring = {
      for (final item in restores)
        if (!item.isBlocked) '${item.event.table}|${item.event.recordId}',
    };
    return [
      ...restores,
      ...await _planEdits(
        [
          for (final event in events)
            if (!created.contains((event.table, event.recordId))) event,
        ],
        dependencies: dependencies,
        restoring: restoring,
      ),
      ...await planner.planRemovals(events),
    ];
  }

  ChangeLogRecordPlanner _plannerWith(ChangeLogDependencyIndex dependencies) =>
      ChangeLogRecordPlanner(_db, _repository, dependencies, _rewrittenColumns);

  /// The column edits among [events], oldest first. Several edits to one
  /// column in an entry count as one: the value goes back to what the first
  /// found, and "changed since" compares with what the last left. A record
  /// in [restoring] returns from its delete copy first, which is the edited
  /// row, so its edits still apply.
  Future<List<ChangeLogRevertItem>> _planEdits(
    List<ChangeLogEvent> events, {
    String? only,
    required ChangeLogDependencyIndex dependencies,
    Set<String> restoring = const {},
  }) async {
    final items = <ChangeLogRevertItem>[];
    for (final (:event, :field) in netFieldChanges(events)) {
      final column = field.column;
      if (only != null && column != only) continue;
      final logged = field.newValue;
      final target = field.oldValue;
      final returning = restoring.contains('${event.table}|${event.recordId}');
      final block = await _editBlock(
        event,
        column,
        target,
        dependencies: dependencies,
        restoring: restoring,
        returning: returning,
      );
      if (block != null) {
        items.add(
          ChangeLogRevertItem(
            event: event,
            column: column,
            logged: logged,
            target: target,
            block: block,
          ),
        );
        continue;
      }
      final current = returning
          ? logged
          : await _liveValue(event.table, event.recordId, column);
      if (_same(current, target)) continue;
      items.add(
        ChangeLogRevertItem(
          event: event,
          column: column,
          logged: logged,
          target: target,
          current: current,
          changedSince: !_same(current, logged),
        ),
      );
    }
    return items;
  }

  Future<ChangeLogBlock?> _editBlock(
    ChangeLogEvent event,
    String column,
    Object? target, {
    required ChangeLogDependencyIndex dependencies,
    required Set<String> restoring,
    required bool returning,
  }) async {
    final columns = await _repository.liveColumns(event.table);
    if (!columns.contains(column)) return ChangeLogBlock.columnGone;
    final rewrittenAt = _rewrittenColumns['${event.table}.$column'];
    if (rewrittenAt != null && event.schemaVersion < rewrittenAt) {
      return ChangeLogBlock.rewritten;
    }
    if (!returning &&
        !await _repository.recordExists(event.table, event.recordId)) {
      return ChangeLogBlock.recordGone;
    }
    final missing = await dependencies.missingParents(event.table, {
      column: target,
    }, restoring);
    return missing.isEmpty ? null : ChangeLogBlock.parentGone;
  }

  Future<Object?> _liveValue(
    String table,
    String recordId,
    String column,
  ) async {
    final match = changeLogKeyMatch(_repository.specOf(table)!, recordId);
    final row = await _db
        .customSelect(
          'SELECT "$column" AS v FROM "$table" WHERE ${match.where}',
          variables: match.variables,
        )
        .getSingle();
    return row.data['v'];
  }

  bool _same(Object? a, Object? b) =>
      const DeepCollectionEquality().equals(a, b);

  /// Applies [plan] in one transaction, after any running sync, so a revert
  /// cannot interleave with a merge: deleted records return, then edits go
  /// back, then created records go, newest first. A failure rolls everything
  /// back and rethrows.
  Future<ChangeLogRevertResult> execute(
    ChangeLogRevertPlan plan, {
    bool includeChangedSince = true,
  }) => SyncCoordinator.run(() async {
    bool applies(ChangeLogRevertItem item) =>
        !item.isBlocked && (includeChangedSince || !item.changedSince);

    // Skipping a record can leave what it uses in use, and a plan can be
    // older than the data, so removals are checked again here.
    final planner = _plannerWith(await ChangeLogDependencyIndex.load(_db));
    final removals = await planner.settleRemovals([
      for (final item in plan.items)
        if (item.removesRecord && applies(item)) item,
    ]);
    final decided = [
      for (final item in plan.items)
        if (!item.removesRecord || !applies(item)) item,
      ...removals,
    ];
    final applying = decided.where(applies).toList();
    final kept = decided.whereNot(applies).toList();
    if (applying.isEmpty) {
      return ChangeLogRevertResult(
        reverted: 0,
        kept: kept.length,
        keptItems: kept,
      );
    }

    final operationId = await ChangeLogScope.run(
      _db,
      source: ChangeLogSource.revert,
      revertOfId: plan.operationId,
      body: () async {
        await _db.transaction(() async {
          // Records can arrive in any order; a parent that cannot return was
          // blocked when the plan was made.
          await _db.customStatement('PRAGMA defer_foreign_keys = ON');
          final now = DateTime.now().millisecondsSinceEpoch;
          for (final item in applying.where((i) => i.restoresRecord)) {
            await _restoreRecord(item.event, now);
          }
          await _writeEdits([
            for (final item in applying)
              if (item.column != null) item,
          ]);
          await _removeRecords([
            for (final item in applying)
              if (item.removesRecord) item.event,
          ]);
        });
        return ChangeLogScope.currentOperationId;
      },
    );
    await _finish(plan, applying, kept, operationId);
    return ChangeLogRevertResult(
      reverted: applying.length,
      kept: kept.length,
      keptItems: kept,
      operationId: operationId,
    );
  });

  /// Inserts a deleted record from its delete copy, leaving out columns the
  /// schema has since dropped. A table with an `updated_at` gets [now] there:
  /// a peer holding the tombstone revives a row only for a copy edited after
  /// the delete. The clock comes from the pending mark, never from the log.
  Future<void> _restoreRecord(ChangeLogEvent event, int now) async {
    final table = event.table;
    final columns = await _repository.liveColumns(table);
    final values = <String, Object?>{
      for (final column in await _repository.nullableDefaultedColumns(table))
        if (!changeLogDeleteCopySkips(column)) column: null,
      for (final field in event.fields)
        if (columns.contains(field.column)) field.column: field.oldValue,
      if (columns.contains('updated_at')) 'updated_at': now,
    };
    await _db.customInsert(
      'INSERT INTO "$table" (${values.keys.map((c) => '"$c"').join(', ')}) '
      'VALUES (${List.filled(values.length, '?').join(', ')})',
      variables: [for (final value in values.values) Variable<Object>(value)],
      updates: {_infoOf(table)},
    );
    final entity = changeLogEntityType(table);
    await _sync.removeDeletion(entityType: entity, recordId: event.recordId);
    await _sync.markRecordPending(
      entityType: entity,
      recordId: event.recordId,
      localUpdatedAt: now,
      alsoStamp: SyncFactGroups.of(entity),
    );
  }

  /// Newest first, so a child goes before its parent. Dives go through
  /// [DiveRepository.bulkDeleteDives], which keeps media and route cascades
  /// right, and take their children with them.
  Future<void> _removeRecords(List<ChangeLogEvent> events) async {
    final dives = [
      for (final event in events)
        if (event.table == 'dives') event.recordId,
    ];
    if (dives.isNotEmpty) await DiveRepository().bulkDeleteDives(dives);
    for (final event in events.reversed) {
      if (event.table == 'dives') continue;
      if (event.root.table == 'dives' && dives.contains(event.root.id)) {
        continue;
      }
      final match = changeLogKeyMatch(
        _repository.specOf(event.table)!,
        event.recordId,
      );
      await _db.customUpdate(
        'DELETE FROM "${event.table}" WHERE ${match.where}',
        variables: match.variables,
        updates: {_infoOf(event.table)},
        updateKind: UpdateKind.delete,
      );
      await _sync.logDeletion(
        entityType: changeLogEntityType(event.table),
        recordId: event.recordId,
      );
    }
  }

  TableInfo<Table, Object?> _infoOf(String table) =>
      _db.allTables.firstWhere((t) => t.actualTableName == table);

  /// One update per record, so a record's fields move together.
  Future<void> _writeEdits(List<ChangeLogRevertItem> items) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final byRecord = groupBy(
      items,
      (ChangeLogRevertItem item) => (item.event.table, item.event.recordId),
    );
    for (final MapEntry(key: (table, recordId), value: edits)
        in byRecord.entries) {
      await _writeRecord(table, recordId, edits, now);
    }
  }

  Future<void> _writeRecord(
    String table,
    String recordId,
    List<ChangeLogRevertItem> edits,
    int now,
  ) async {
    final hasUpdatedAt = (await _repository.liveColumns(
      table,
    )).contains('updated_at');
    final match = changeLogKeyMatch(_repository.specOf(table)!, recordId);
    await _db.customUpdate(
      'UPDATE "$table" SET '
      '${[for (final edit in edits) '"${edit.column}" = ?', if (hasUpdatedAt) '"updated_at" = ?'].join(', ')} WHERE ${match.where}',
      variables: [
        for (final edit in edits) Variable<Object>(edit.target),
        if (hasUpdatedAt) Variable<Object>(now),
        ...match.variables,
      ],
      updates: {_infoOf(table)},
    );

    final entity = changeLogEntityType(table);
    final columns = {for (final edit in edits) edit.column!};
    final groups = [
      for (final group in SyncFactGroups.of(entity))
        if (group.columns.values.any(columns.contains)) group,
    ];
    final onlyFacts = columns.every(
      (c) => groups.any((g) => g.columns.containsValue(c)),
    );
    await _sync.markRecordPending(
      entityType: entity,
      recordId: recordId,
      localUpdatedAt: now,
      alsoStamp: groups,
      stampClock: !onlyFacts,
    );

    // A dive put back on its old trip keeps no tank link into the trip it
    // leaves, as every other trip change does.
    if (table == 'dives' && columns.contains('trip_id')) {
      final trip = edits.firstWhere((e) => e.column == 'trip_id').target;
      await clearForeignTripCylinderLinks(
        _db,
        _sync,
        recordId,
        tripId: trip as String?,
        now: now,
      );
    }
  }

  /// What every write of the app does after a commit, and the link from the
  /// original entry to its revert. An entry shows as reverted only when all
  /// of it went back, so what a partial undo kept can be tried again.
  /// Reverting a revert puts the entry it undid back as it was.
  Future<void> _finish(
    ChangeLogRevertPlan plan,
    List<ChangeLogRevertItem> applied,
    List<ChangeLogRevertItem> kept,
    String? operationId,
  ) async {
    _afterDiveWrites({
      for (final item in applied)
        if (item.event.root.table == 'dives') item.event.root.id,
    });
    SyncEventBus.notifyLocalChange();
    if (!plan.wholeOperation || kept.isNotEmpty || operationId == null) return;
    await _db.customUpdate(
      'UPDATE change_log_operations SET reverted_by_id = ? WHERE id = ?',
      variables: [
        Variable<String>(operationId),
        Variable<String>(plan.operationId),
      ],
      updates: {_db.changeLogOperations},
    );
    await _db.customUpdate(
      'UPDATE change_log_operations SET reverted_by_id = NULL WHERE id = '
      '(SELECT revert_of_id FROM change_log_operations WHERE id = ?)',
      variables: [Variable<String>(plan.operationId)],
      updates: {_db.changeLogOperations},
    );
  }
}
