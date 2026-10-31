import 'package:collection/collection.dart';
import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/change_log/change_log_rewrites.dart';
import 'package:submersion/core/database/change_log/change_log_trigger_sql.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/core/services/sync/sync_fact_groups.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/domain/change_log_entities.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_event.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_revert_plan.dart';
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

  Map<String, ChangeLogTableSpec>? _specCache;
  Map<String, ChangeLogTableSpec> get _specs => _specCache ??= {
    for (final spec in changeLogSpecsFor(_db)) spec.table: spec,
  };

  Future<ChangeLogRevertPlan> planField(int eventId, String column) async {
    final event = await _repository.getEvent(eventId);
    if (event == null) {
      throw ArgumentError.value(eventId, 'eventId', 'No such change log event');
    }
    final items = await _planEdits([event], only: column);
    final operation = await _repository.getOperation(event.operationId);
    return ChangeLogRevertPlan(
      operationId: event.operationId,
      items: items,
      wholeOperation: operation?.eventCount == 1 && event.fields.length == 1,
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
      items: await _planEdits([event]),
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
      items: await _planEdits(events),
      wholeOperation: true,
    );
  }

  /// The column edits among [events], oldest first. Several edits to one
  /// column in an entry count as one: the value goes back to what the first
  /// found, and "changed since" compares with what the last left.
  Future<List<ChangeLogRevertItem>> _planEdits(
    List<ChangeLogEvent> events, {
    String? only,
  }) async {
    final first = <(String, String, String), ChangeLogFieldChange>{};
    final last = <(String, String, String), (ChangeLogEvent, Object?)>{};
    for (final event in events) {
      if (event.action != ChangeLogAction.update) continue;
      for (final field in event.fields) {
        if (only != null && field.column != only) continue;
        final key = (event.table, event.recordId, field.column);
        first[key] ??= field;
        last[key] = (event, field.newValue);
      }
    }

    final items = <ChangeLogRevertItem>[];
    for (final MapEntry(:key, value: (event, logged)) in last.entries) {
      final (table, recordId, column) = key;
      final target = first[key]!.oldValue;
      final block = await _editBlock(event, column);
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
      final current = await _liveValue(table, recordId, column);
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
  ) async {
    final columns = await _repository.liveColumns(event.table);
    if (!columns.contains(column)) return ChangeLogBlock.columnGone;
    final rewrittenAt = _rewrittenColumns['${event.table}.$column'];
    if (rewrittenAt != null && event.schemaVersion < rewrittenAt) {
      return ChangeLogBlock.rewritten;
    }
    if (!await _repository.recordExists(event.table, event.recordId)) {
      return ChangeLogBlock.recordGone;
    }
    return null;
  }

  Future<Object?> _liveValue(
    String table,
    String recordId,
    String column,
  ) async {
    final match = changeLogKeyMatch(_specs[table]!, recordId);
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
  /// cannot interleave with a merge. A failure rolls everything back and
  /// rethrows.
  Future<ChangeLogRevertResult> execute(
    ChangeLogRevertPlan plan, {
    bool includeChangedSince = true,
  }) {
    bool applies(ChangeLogRevertItem item) =>
        !item.isBlocked && (includeChangedSince || !item.changedSince);
    final kept = plan.items.whereNot(applies).toList();
    final applying = plan.items.where(applies).toList();
    if (applying.isEmpty) {
      return Future.value(
        ChangeLogRevertResult(reverted: 0, kept: kept.length, keptItems: kept),
      );
    }

    return SyncCoordinator.run(() async {
      final operationId = await ChangeLogScope.run(
        _db,
        source: ChangeLogSource.revert,
        revertOfId: plan.operationId,
        body: () async {
          await _db.transaction(() => _writeEdits(applying));
          return ChangeLogScope.currentOperationId;
        },
      );
      await _finish(plan, applying, operationId);
      return ChangeLogRevertResult(
        reverted: applying.length,
        kept: kept.length,
        keptItems: kept,
        operationId: operationId,
      );
    });
  }

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
    final info = _db.allTables.firstWhere((t) => t.actualTableName == table);
    final hasUpdatedAt = (await _repository.liveColumns(
      table,
    )).contains('updated_at');
    final match = changeLogKeyMatch(_specs[table]!, recordId);
    await _db.customUpdate(
      'UPDATE "$table" SET '
      '${[for (final edit in edits) '"${edit.column}" = ?', if (hasUpdatedAt) '"updated_at" = ?'].join(', ')} WHERE ${match.where}',
      variables: [
        for (final edit in edits) Variable<Object>(edit.target),
        if (hasUpdatedAt) Variable<Object>(now),
        ...match.variables,
      ],
      updates: {info},
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
  /// original entry to its revert.
  Future<void> _finish(
    ChangeLogRevertPlan plan,
    List<ChangeLogRevertItem> applied,
    String? operationId,
  ) async {
    _afterDiveWrites({
      for (final item in applied)
        if (item.event.root.table == 'dives') item.event.root.id,
    });
    SyncEventBus.notifyLocalChange();
    if (plan.wholeOperation && operationId != null) {
      await _db.customUpdate(
        'UPDATE change_log_operations SET reverted_by_id = ? WHERE id = ?',
        variables: [
          Variable<String>(operationId),
          Variable<String>(plan.operationId),
        ],
        updates: {_db.changeLogOperations},
      );
    }
  }
}
