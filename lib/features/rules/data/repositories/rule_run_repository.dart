import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/rules/data/services/rule_applier_support.dart';
import 'package:submersion/features/rules/domain/entities/rule_run.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';

/// The history of rule runs (#3513): one `rule_runs` row per run that
/// changed something, with one `rule_run_changes` row per field changed.
/// Both sync per diver.
class RuleRunRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(RuleRunRepository);

  static const runEntity = 'ruleRuns';
  static const changeEntity = 'ruleRunChanges';

  /// Emits whenever the history changes (a run, an undo, a delete, a sync).
  Stream<void> watchRunsChanges() => _db.tableUpdates(
    TableUpdateQuery.allOf([
      TableUpdateQuery.onTable(_db.ruleRuns),
      TableUpdateQuery.onTable(_db.ruleRunChanges),
    ]),
  );

  /// Records a run and its [changes]. Does not notify: the caller (the
  /// engine) notifies once for the whole run. Safe inside a transaction.
  Future<String> insertRun({
    required String diverId,
    required RuleRunTrigger trigger,
    String? sourceLabel,
    String? deviceLabel,
    required List<RuleChange> changes,
    DateTime? ranAt,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    final targets = {
      for (final c in changes) '${c.subject.name}:${c.targetId}',
    };
    await _db
        .into(_db.ruleRuns)
        .insert(
          RuleRunsCompanion.insert(
            id: id,
            diverId: Value(diverId),
            trigger: trigger.name,
            sourceLabel: Value(sourceLabel),
            deviceLabel: Value(deviceLabel),
            ranAt: (ranAt ?? DateTime.now()).millisecondsSinceEpoch,
            changedCount: targets.length,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await _syncRepository.markRecordPending(
      entityType: runEntity,
      recordId: id,
      localUpdatedAt: now,
    );
    final rows = [
      for (var i = 0; i < changes.length; i++)
        RuleRunChangesCompanion.insert(
          id: _uuid.v4(),
          runId: id,
          subject: changes[i].subject.name,
          targetId: changes[i].targetId,
          ruleId: Value(changes[i].ruleId),
          ruleName: changes[i].ruleName,
          field: changes[i].field,
          beforeJson: jsonEncode(changes[i].before),
          afterJson: jsonEncode(changes[i].after),
          sortOrder: Value(i),
          createdAt: now,
          updatedAt: now,
        ),
    ];
    await _db.batch((b) => b.insertAll(_db.ruleRunChanges, rows));
    for (final row in rows) {
      await _syncRepository.markRecordPending(
        entityType: changeEntity,
        recordId: row.id.value,
        localUpdatedAt: now,
      );
    }
    return id;
  }

  /// [diverId]'s runs, newest first, each with its rules' names.
  Future<List<RuleRun>> getRuns(String diverId) async {
    final rows =
        await (_db.select(_db.ruleRuns)
              ..where((t) => t.diverId.equals(diverId))
              ..orderBy([(t) => OrderingTerm.desc(t.ranAt)]))
            .get();
    final names = <String, List<String>>{};
    final nameRows = await _db
        .customSelect(
          'SELECT DISTINCT c.run_id, c.rule_name FROM rule_run_changes c '
          'JOIN rule_runs r ON r.id = c.run_id WHERE r.diver_id = ? '
          'ORDER BY c.run_id, c.sort_order',
          variables: [Variable.withString(diverId)],
          readsFrom: {_db.ruleRunChanges, _db.ruleRuns},
        )
        .get();
    for (final r in nameRows) {
      final list = names.putIfAbsent(r.read<String>('run_id'), () => []);
      final name = r.read<String>('rule_name');
      if (!list.contains(name)) list.add(name);
    }
    return [for (final r in rows) ?_runFromRow(r, names[r.id] ?? const [])];
  }

  /// [ids]'s runs, newest first, whichever diver each belongs to: one
  /// multi-profile import's runs (#3513).
  Future<List<RuleRun>> getRunsByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final rows =
        await (_db.select(_db.ruleRuns)
              ..where((t) => t.id.isIn(ids))
              ..orderBy([(t) => OrderingTerm.desc(t.ranAt)]))
            .get();
    final names = <String, List<String>>{};
    final nameRows =
        await (_db.select(_db.ruleRunChanges)
              ..where((t) => t.runId.isIn(ids))
              ..orderBy([
                (t) => OrderingTerm.asc(t.runId),
                (t) => OrderingTerm.asc(t.sortOrder),
              ]))
            .get();
    for (final r in nameRows) {
      final list = names.putIfAbsent(r.runId, () => []);
      if (!list.contains(r.ruleName)) list.add(r.ruleName);
    }
    return [for (final r in rows) ?_runFromRow(r, names[r.id] ?? const [])];
  }

  Future<RuleRun?> getRun(String id) async {
    final row = await (_db.select(
      _db.ruleRuns,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _runFromRow(row);
  }

  /// [runId]'s changes in the order the run made them.
  Future<List<RuleChange>> getChanges(String runId) async {
    final rows =
        await (_db.select(_db.ruleRunChanges)
              ..where((t) => t.runId.equals(runId))
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get();
    return [for (final r in rows) ?_changeFromRow(r)];
  }

  /// How many of [runId]'s dives and sites have a change row here, read
  /// from the rows as stored (a subject this version does not know
  /// counts): fewer than the run's changedCount means some have not
  /// synced yet.
  Future<int> arrivedTargetCount(String runId) async {
    final row = await _db
        .customSelect(
          'SELECT COUNT(*) AS n FROM (SELECT DISTINCT subject, target_id '
          'FROM rule_run_changes WHERE run_id = ?)',
          variables: [Variable.withString(runId)],
          readsFrom: {_db.ruleRunChanges},
        )
        .getSingle();
    return row.read<int>('n');
  }

  Future<void> markUndone(String id, DateTime at) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.ruleRuns)..where((t) => t.id.equals(id))).write(
      RuleRunsCompanion(
        undoneAt: Value(at.millisecondsSinceEpoch),
        updatedAt: Value(now),
      ),
    );
    await _syncRepository.markRecordPending(
      entityType: runEntity,
      recordId: id,
      localUpdatedAt: now,
    );
  }

  Future<void> deleteRun(String id) => _deleteRuns([id]);

  Future<void> deleteAllRuns(String diverId) async {
    final ids =
        await (_db.selectOnly(_db.ruleRuns)
              ..addColumns([_db.ruleRuns.id])
              ..where(_db.ruleRuns.diverId.equals(diverId)))
            .map((r) => r.read(_db.ruleRuns.id)!)
            .get();
    await _deleteRuns(ids);
  }

  Future<void> _deleteRuns(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      final chunks = ruleIdChunks(ids).toList();
      final changeIds = [
        for (final chunk in chunks)
          ...await (_db.selectOnly(_db.ruleRunChanges)
                ..addColumns([_db.ruleRunChanges.id])
                ..where(_db.ruleRunChanges.runId.isIn(chunk)))
              .map((r) => r.read(_db.ruleRunChanges.id)!)
              .get(),
      ];
      await _db.transaction(() async {
        for (final chunk in chunks) {
          await (_db.delete(
            _db.ruleRunChanges,
          )..where((t) => t.runId.isIn(chunk))).go();
          await (_db.delete(_db.ruleRuns)..where((t) => t.id.isIn(chunk))).go();
        }
      });
      await _syncRepository.logDeletions(
        entityType: changeEntity,
        recordIds: changeIds,
      );
      await _syncRepository.logDeletions(entityType: runEntity, recordIds: ids);
      SyncEventBus.notifyLocalChange();
    } catch (e, st) {
      _log.error('Failed to delete rule runs', error: e, stackTrace: st);
      rethrow;
    }
  }

  RuleRun? _runFromRow(RuleRunRow r, [List<String> ruleNames = const []]) {
    final trigger = RuleRunTrigger.values.asNameMap()[r.trigger];
    if (trigger == null) return null;
    return RuleRun(
      id: r.id,
      diverId: r.diverId,
      trigger: trigger,
      sourceLabel: r.sourceLabel,
      deviceLabel: r.deviceLabel,
      ranAt: DateTime.fromMillisecondsSinceEpoch(r.ranAt),
      changedCount: r.changedCount,
      undoneAt: r.undoneAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(r.undoneAt!),
      ruleNames: ruleNames,
    );
  }

  RuleChange? _changeFromRow(RuleRunChangeRow r) {
    final subject = RuleSubject.values.asNameMap()[r.subject];
    if (subject == null) return null;
    return RuleChange(
      subject: subject,
      targetId: r.targetId,
      ruleId: r.ruleId,
      ruleName: r.ruleName,
      field: r.field,
      before: jsonDecode(r.beforeJson),
      after: jsonDecode(r.afterJson),
    );
  }
}
