import 'package:drift/drift.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/rules/data/repositories/rule_run_repository.dart';
import 'package:submersion/features/rules/data/services/dive_rule_applier.dart';
import 'package:submersion/features/rules/data/services/rule_applier_support.dart';
import 'package:submersion/features/rules/data/services/site_rule_applier.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/entities/rule_run.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';

/// What undoing a run did.
class RuleUndoResult {
  const RuleUndoResult({
    this.restoredTargets = 0,
    this.skippedEditedTargets = 0,
    this.skippedDeletedTargets = 0,
    this.nothingYet = false,
    this.alreadyUndone = false,
  });

  /// The outcome of undoing several runs at once (an import's runs, one per
  /// profile): counts add up; it is "nothing yet" only when no run was
  /// undone and one is still waiting, and "already undone" only when every
  /// run was.
  factory RuleUndoResult.combine(List<RuleUndoResult> results) {
    int sum(int Function(RuleUndoResult) f) =>
        results.fold(0, (total, r) => total + f(r));
    final undoneNow = results.any((r) => !r.nothingYet && !r.alreadyUndone);
    return RuleUndoResult(
      restoredTargets: sum((r) => r.restoredTargets),
      skippedEditedTargets: sum((r) => r.skippedEditedTargets),
      skippedDeletedTargets: sum((r) => r.skippedDeletedTargets),
      nothingYet: !undoneNow && results.any((r) => r.nothingYet),
      alreadyUndone: results.every((r) => r.alreadyUndone),
    );
  }

  /// Dives and sites with at least one change reverted.
  final int restoredTargets;

  /// Dives and sites with a change left alone because it was edited since.
  final int skippedEditedTargets;

  /// Dives and sites deleted since the run.
  final int skippedDeletedTargets;

  /// Nothing could be reverted (the run's edits may not have synced to this
  /// device yet); the run stays undoable.
  final bool nothingYet;
  final bool alreadyUndone;
}

enum _Outcome { restored, edited, deleted }

/// Reverses a rule run (#3513), restoring only what is still as the run
/// left it: a field still holding the run's value, an added item still
/// there, a removed item still absent, appended text still at the end.
/// Anything the diver changed since is left alone and counted.
class RuleUndoService {
  RuleUndoService({
    RuleRunRepository? runs,
    DiveRuleApplier? dives,
    SiteRuleApplier? sites,
  }) : _runs = runs ?? RuleRunRepository(),
       _dives = dives ?? DiveRuleApplier(),
       _sites = sites ?? SiteRuleApplier();

  final RuleRunRepository _runs;
  final DiveRuleApplier _dives;
  final SiteRuleApplier _sites;
  final SyncRepository _sync = SyncRepository();

  AppDatabase get _db => DatabaseService.instance.database;

  Future<RuleUndoResult> undo(String runId) async {
    final run = await _runs.getRun(runId);
    if (run == null || run.isUndone) {
      return const RuleUndoResult(alreadyUndone: true);
    }
    final changes = await _runs.getChanges(runId);
    // The run synced but its change rows have not arrived yet: nothing to
    // undo here so far, and the run must stay undoable.
    if (changes.isEmpty && run.changedCount > 0) {
      return const RuleUndoResult(nothingYet: true);
    }
    final result = await _db.transaction(() async {
      final byTarget = <String, Set<_Outcome>>{};
      for (final c in changes) {
        final outcome = await _undoInSavepoint(c);
        byTarget
            .putIfAbsent('${c.subject.name}:${c.targetId}', () => {})
            .add(outcome);
      }
      int count(_Outcome o) =>
          byTarget.values.where((s) => s.contains(o)).length;
      final restored = count(_Outcome.restored);
      if (restored == 0 && changes.isNotEmpty) {
        return RuleUndoResult(
          skippedEditedTargets: count(_Outcome.edited),
          skippedDeletedTargets: count(_Outcome.deleted),
          nothingYet: true,
        );
      }
      await _runs.markUndone(runId, DateTime.now());
      return RuleUndoResult(
        restoredTargets: restored,
        skippedEditedTargets: count(_Outcome.edited),
        skippedDeletedTargets: count(_Outcome.deleted),
      );
    });
    if (!result.nothingYet) SyncEventBus.notifyLocalChange();
    return result;
  }

  /// Undoes [c] in its own savepoint, so a change the database refuses to
  /// write (its old trip or dive centre was deleted since) is left alone
  /// and counted as edited instead of failing the whole undo. Any other
  /// failure fails the undo, which rolls back and leaves the run undoable.
  Future<_Outcome> _undoInSavepoint(RuleChange c) async {
    try {
      return await _db.transaction(() => _undoOne(c));
    } on SqliteException {
      return _Outcome.edited;
    }
  }

  Future<_Outcome> _undoOne(RuleChange c) async {
    final dive = c.subject == RuleSubject.dives;
    final table = dive ? 'dives' : 'dive_sites';
    if ((await existingIds(_db, table, [c.targetId])).isEmpty) {
      return _Outcome.deleted;
    }
    final collection = dive ? DiveCollection.values.asNameMap()[c.field] : null;
    final siteCollection = dive
        ? null
        : SiteCollection.values.asNameMap()[c.field];
    if (collection != null) return _undoDiveMembership(c, collection);
    if (siteCollection != null) return _undoSiteMembership(c, siteCollection);
    if (c.field == 'notes' || c.field == 'description') {
      return _undoAppend(c, table, c.field);
    }
    return _undoColumns(c, table);
  }

  /// The columns [table] really has, so a stored change can only ever name
  /// one of them.
  Set<String> _columnsOf(String table) {
    final TableInfo<Table, Object?> info = table == 'dives'
        ? _db.dives
        : _db.diveSites;
    return {for (final col in info.$columns) col.name};
  }

  Future<_Outcome> _undoColumns(RuleChange c, String table) async {
    final before = (c.before as Map?)?.cast<String, Object?>() ?? const {};
    final after = (c.after as Map?)?.cast<String, Object?>() ?? const {};
    final known = _columnsOf(table);
    if (after.isEmpty || !after.keys.every(known.contains)) {
      return _Outcome.edited;
    }
    final current = await columnValues(
      _db,
      table: table,
      columns: after.keys.toList(),
      ids: [c.targetId],
    );
    if (!sameColumns(current[c.targetId]!, after)) return _Outcome.edited;
    final now = DateTime.now().millisecondsSinceEpoch;
    final cols = before.keys.where(known.contains).toList();
    await _db.customUpdate(
      'UPDATE $table SET ${[for (final k in cols) '$k = ?'].join(', ')}, '
      'updated_at = ? WHERE id = ?',
      variables: [
        for (final k in cols) Variable(storedForm(before[k])),
        Variable.withInt(now),
        Variable.withString(c.targetId),
      ],
      updates: {table == 'dives' ? _db.dives : _db.diveSites},
    );
    await _sync.markRecordPending(
      entityType: table == 'dives' ? 'dives' : 'diveSites',
      recordId: c.targetId,
      localUpdatedAt: now,
    );
    return _Outcome.restored;
  }

  Future<_Outcome> _undoAppend(
    RuleChange c,
    String table,
    String column,
  ) async {
    final before = (c.before as String?) ?? '';
    final after = (c.after as String?) ?? '';
    if (after.length < before.length) return _Outcome.edited;
    final appended = after.substring(before.length);
    final current =
        (await columnValues(
              _db,
              table: table,
              columns: [column],
              ids: [c.targetId],
            ))[c.targetId]![column]
            as String? ??
        '';
    if (appended.isEmpty || !current.endsWith(appended)) {
      return _Outcome.edited;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.customUpdate(
      'UPDATE $table SET $column = ?, updated_at = ? WHERE id = ?',
      variables: [
        Variable.withString(
          current.substring(0, current.length - appended.length),
        ),
        Variable.withInt(now),
        Variable.withString(c.targetId),
      ],
      updates: {table == 'dives' ? _db.dives : _db.diveSites},
    );
    await _sync.markRecordPending(
      entityType: table == 'dives' ? 'dives' : 'diveSites',
      recordId: c.targetId,
      localUpdatedAt: now,
    );
    return _Outcome.restored;
  }

  /// Membership values are ids, or `{id, role}` maps for buddies.
  Map<String, String?> _items(Object? list) => {
    for (final m in (list as List?) ?? const [])
      if (m is Map)
        m['id'] as String: (m['role'] as String?)
      else
        m as String: null,
  };

  Future<_Outcome> _undoDiveMembership(
    RuleChange c,
    DiveCollection collection,
  ) async {
    final before = _items(c.before);
    final after = _items(c.after);
    final current = _items(
      (await _dives.members(collection, [c.targetId]))[c.targetId],
    );
    final removeNow = [
      for (final id in after.keys)
        if (!before.containsKey(id) && current.containsKey(id)) id,
    ];
    final addBack = [
      for (final id in before.keys)
        if (!after.containsKey(id) && !current.containsKey(id)) id,
    ];
    if (removeNow.isEmpty && addBack.isEmpty) return _Outcome.edited;
    if (removeNow.isNotEmpty) {
      await _dives.writeMembership(
        collection,
        add: false,
        diveIds: [c.targetId],
        ids: removeNow,
      );
    }
    for (final id in addBack) {
      await _dives.writeMembership(
        collection,
        add: true,
        diveIds: [c.targetId],
        ids: [id],
        buddyRoleId: before[id],
      );
    }
    return _Outcome.restored;
  }

  Future<_Outcome> _undoSiteMembership(
    RuleChange c,
    SiteCollection collection,
  ) async {
    final before = _items(c.before);
    final after = _items(c.after);
    final current = {
      ...?(await _sites.members(collection, [c.targetId]))[c.targetId],
    };
    final removeNow = [
      for (final id in after.keys)
        if (!before.containsKey(id) && current.contains(id)) id,
    ];
    final addBack = [
      for (final id in before.keys)
        if (!after.containsKey(id) && !current.contains(id)) id,
    ];
    if (removeNow.isEmpty && addBack.isEmpty) return _Outcome.edited;
    if (removeNow.isNotEmpty) {
      await _sites.writeMembership(
        collection,
        add: false,
        siteId: c.targetId,
        ids: removeNow,
      );
    }
    if (addBack.isNotEmpty) {
      await _sites.writeMembership(
        collection,
        add: true,
        siteId: c.targetId,
        ids: addBack,
      );
    }
    return _Outcome.restored;
  }
}
