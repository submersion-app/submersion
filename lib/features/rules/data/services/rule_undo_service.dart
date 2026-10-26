import 'package:drift/drift.dart';
import 'package:sqlite3/sqlite3.dart' show SqliteException;

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/existing_row_ids.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/data/repositories/trip_cylinder_links.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';
import 'package:submersion/features/rules/data/repositories/rule_run_repository.dart';
import 'package:submersion/features/rules/data/services/dive_rule_applier.dart';
import 'package:submersion/features/rules/data/services/rule_applier_support.dart';
import 'package:submersion/features/rules/data/services/rule_target_scope.dart';
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

  /// Dives and sites with a change left alone because it was edited since,
  /// or because it can no longer be put back.
  final int skippedEditedTargets;

  /// Dives and sites deleted since the run.
  final int skippedDeletedTargets;

  /// Nothing could be reverted (the run's edits may not have synced to this
  /// device yet); the run stays undoable.
  final bool nothingYet;
  final bool alreadyUndone;
}

/// How undoing one change went.
enum _Outcome {
  restored,

  /// Not as the run left it: an edit since, or the run's own edits not
  /// synced here yet.
  edited,

  deleted,

  /// Left alone for good: out of the rules' reach now (a site added to a
  /// club library since), or what it would put back is gone.
  blocked,
}

/// SQLITE_CONSTRAINT_FOREIGNKEY, and SQLite's exact `errmsg` for it, matched
/// when the code is out of reach: the app's database runs on a worker
/// isolate, from which a failure arrives re-wrapped (as for
/// `isDatabaseBusyError`).
const _foreignKeyFailed = 787;
const _foreignKeyMessage = 'FOREIGN KEY constraint failed';

/// Reverses a rule run (#3513), restoring only what is still as the run
/// left it: a field still holding the run's value, an added item still
/// there, a removed item still absent, appended text still the last line.
/// Anything the diver changed since is left alone and counted.
class RuleUndoService {
  RuleUndoService({
    RuleRunRepository? runs,
    DiveRuleApplier? dives,
    SiteRuleApplier? sites,
    RuleTargetScope? scope,
    void Function(Iterable<String> diveIds)? afterDiveWrites,
  }) : _runs = runs ?? RuleRunRepository(),
       _dives = dives ?? DiveRuleApplier(),
       _sites = sites ?? SiteRuleApplier(),
       _scope = scope ?? RuleTargetScope(),
       _afterDiveWrites = afterDiveWrites ?? refreshAfterRuleWrites;

  final RuleRunRepository _runs;
  final DiveRuleApplier _dives;
  final SiteRuleApplier _sites;
  final RuleTargetScope _scope;
  final void Function(Iterable<String> diveIds) _afterDiveWrites;
  final SyncRepository _sync = SyncRepository();

  AppDatabase get _db => DatabaseService.instance.database;

  Future<RuleUndoResult> undo(String runId) async {
    final run = await _runs.getRun(runId);
    if (run == null || run.isUndone) {
      return const RuleUndoResult(alreadyUndone: true);
    }
    // The run synced but some of its change rows have not arrived yet:
    // undoing only those here would mark the run undone and leave the rest
    // applied for good, so it waits, undoable.
    if (await _runs.arrivedTargetCount(runId) < run.changedCount) {
      return const RuleUndoResult(nothingYet: true);
    }
    final changes = await _runs.getChanges(runId);
    final restoredDives = <String>{};
    final result = await _db.transaction(() async {
      // Checked again inside: transactions run one at a time, so an undo
      // that raced this one (a double tap) has marked the run by now.
      if ((await _runs.getRun(runId))?.isUndone ?? true) {
        return const RuleUndoResult(alreadyUndone: true);
      }
      final inScope = await _inScope(run.diverId, changes);
      final byTarget = <String, Set<_Outcome>>{};
      // Newest first: a later rule's change to the same field or list sits
      // on top of an earlier one's, so it must come off before the earlier
      // change can find its own value still in place.
      for (final c in changes.reversed) {
        final key = '${c.subject.name}:${c.targetId}';
        final outcome = await _undoInSavepoint(
          c,
          inScope: inScope.contains(key),
        );
        byTarget.putIfAbsent(key, () => {}).add(outcome);
        if (outcome == _Outcome.restored && c.subject == RuleSubject.dives) {
          restoredDives.add(c.targetId);
        }
      }
      int count(bool Function(Set<_Outcome>) test) =>
          byTarget.values.where(test).length;
      final restored = count((s) => s.contains(_Outcome.restored));
      final skippedEdited = count(
        (s) => s.contains(_Outcome.edited) || s.contains(_Outcome.blocked),
      );
      final skippedDeleted = count((s) => s.contains(_Outcome.deleted));
      // Nothing restored, but something not yet as the run left it: the
      // run's own edits may still be on their way, so it stays undoable.
      // Deleted and blocked targets will not change by syncing.
      if (restored == 0 &&
          byTarget.values.any((s) => s.contains(_Outcome.edited))) {
        return RuleUndoResult(
          skippedEditedTargets: skippedEdited,
          skippedDeletedTargets: skippedDeleted,
          nothingYet: true,
        );
      }
      await _runs.markUndone(runId, DateTime.now());
      return RuleUndoResult(
        restoredTargets: restored,
        skippedEditedTargets: skippedEdited,
        skippedDeletedTargets: skippedDeleted,
      );
    });
    if (!result.nothingYet && !result.alreadyUndone) {
      SyncEventBus.notifyLocalChange();
      _afterDiveWrites(restoredDives);
    }
    return result;
  }

  /// The changes' targets the run's diver's rules may still change, as
  /// `subject:id` keys: undo reaches no further than the rules do. A run
  /// with no diver (one is always written with its diver) reaches nothing.
  Future<Set<String>> _inScope(
    String? diverId,
    List<RuleChange> changes,
  ) async {
    if (diverId == null) return const {};
    final bySubject = <RuleSubject, Set<String>>{};
    for (final c in changes) {
      bySubject.putIfAbsent(c.subject, () => {}).add(c.targetId);
    }
    return {
      for (final e in bySubject.entries)
        for (final id in await _scope.matches(null, e.key, diverId, e.value))
          '${e.key.name}:$id',
    };
  }

  /// Undoes [c] in its own savepoint, so a change the database refuses to
  /// write (its old trip or dive centre was deleted since) is left alone
  /// instead of failing the whole undo. Any other failure fails the undo,
  /// which rolls back and leaves the run undoable.
  Future<_Outcome> _undoInSavepoint(
    RuleChange c, {
    required bool inScope,
  }) async {
    try {
      return await _db.transaction(() => _undoOne(c, inScope: inScope));
    } catch (e) {
      if (_refusedReference(e)) return _Outcome.blocked;
      rethrow;
    }
  }

  /// A write the database refused for naming a row deleted since.
  static bool _refusedReference(Object e) => e is SqliteException
      ? e.extendedResultCode == _foreignKeyFailed
      : e.toString().contains(_foreignKeyMessage);

  Future<_Outcome> _undoOne(RuleChange c, {required bool inScope}) async {
    if ((await existingRowIds(_db, _table(c.subject).info, [
      c.targetId,
    ])).isEmpty) {
      return _Outcome.deleted;
    }
    // A site added to a club library since is the club's now: no rule may
    // change it, so no undo of one may either.
    if (!inScope) return _Outcome.blocked;
    if (c.subject == RuleSubject.dives) {
      if (DiveCollection.values.asNameMap()[c.field] case final collection?) {
        return _undoDiveMembership(c, collection);
      }
    } else if (SiteCollection.values.asNameMap()[c.field]
        case final collection?) {
      return _undoSiteMembership(c, collection);
    }
    if (c.field == 'notes' || c.field == 'description') {
      return _undoAppend(c);
    }
    return _undoColumns(c);
  }

  /// [s]'s table, its Drift info and its sync entity.
  ({String name, TableInfo<Table, Object?> info, String entity}) _table(
    RuleSubject s,
  ) => switch (s) {
    RuleSubject.dives => (name: 'dives', info: _db.dives, entity: 'dives'),
    RuleSubject.sites => (
      name: 'dive_sites',
      info: _db.diveSites,
      entity: 'diveSites',
    ),
  };

  /// Writes [values] to [id]'s row, bumping it and marking it for sync.
  Future<void> _write(
    RuleSubject s,
    String id,
    Map<String, Object?> values,
  ) async {
    final t = _table(s);
    final now = DateTime.now().millisecondsSinceEpoch;
    // The column names are the table's own (checked by the caller), never
    // stored data alone.
    await _db.customUpdate(
      'UPDATE ${t.name} SET ${[for (final k in values.keys) '$k = ?'].join(', ')}, '
      'updated_at = ? WHERE id = ?',
      variables: [
        for (final v in values.values) Variable(storedForm(v)),
        Variable.withInt(now),
        Variable.withString(id),
      ],
      updates: {t.info},
    );
    await _sync.markRecordPending(
      entityType: t.entity,
      recordId: id,
      localUpdatedAt: now,
    );
    // A dive put back on its old trip keeps no tank link into the trip it
    // leaves, as every other trip change does.
    if (s == RuleSubject.dives && values.containsKey('trip_id')) {
      await clearForeignTripCylinderLinks(
        _db,
        _sync,
        id,
        tripId: values['trip_id'] as String?,
        now: now,
      );
    }
  }

  Future<_Outcome> _undoColumns(RuleChange c) async {
    final t = _table(c.subject);
    final before = (c.before as Map?)?.cast<String, Object?>() ?? const {};
    final after = (c.after as Map?)?.cast<String, Object?>() ?? const {};
    final known = {for (final col in t.info.$columns) col.name};
    if (after.isEmpty || !after.keys.every(known.contains)) {
      return _Outcome.edited;
    }
    final current = await columnValues(
      _db,
      table: t.name,
      columns: after.keys.toList(),
      ids: [c.targetId],
    );
    if (!sameColumns(current[c.targetId]!, after)) return _Outcome.edited;
    final restore = {
      for (final k in after.keys)
        if (before.containsKey(k)) k: before[k],
    };
    if (restore.isEmpty) return _Outcome.edited;
    await _write(c.subject, c.targetId, restore);
    return _Outcome.restored;
  }

  Future<_Outcome> _undoAppend(RuleChange c) async {
    final before = (c.before as String?) ?? '';
    final after = (c.after as String?) ?? '';
    if (!after.startsWith(before)) return _Outcome.edited;
    // The rule's text is a line of its own: after a newline, or alone when
    // the text was empty. A sentence the diver wrote since that merely ends
    // the same way is theirs.
    final appended = after.substring(before.length);
    final line = appended.startsWith('\n') ? appended.substring(1) : appended;
    if (line.isEmpty) return _Outcome.edited;
    final current =
        (await columnValues(
              _db,
              table: _table(c.subject).name,
              columns: [c.field],
              ids: [c.targetId],
            ))[c.targetId]![c.field]
            as String? ??
        '';
    final String kept;
    if (current.endsWith('\n$line')) {
      kept = current.substring(0, current.length - line.length - 1);
    } else if (current == line) {
      kept = '';
    } else {
      return _Outcome.edited;
    }
    await _write(c.subject, c.targetId, {c.field: kept});
    return _Outcome.restored;
  }

  /// Membership values by id: plain ids map to null, buddies and gear to
  /// their `{id, ...}` maps.
  Map<String, Map<Object?, Object?>?> _items(Object? list) => {
    for (final m in (list as List?) ?? const [])
      if (m is Map) m['id'] as String: m else m as String: null,
  };

  /// Every role a buddy held, from `{id, roles}` (or an older `{id, role}`).
  List<String> _roles(Map<Object?, Object?>? m) => switch (m?['roles']) {
    final List<Object?> roles => [for (final r in roles) r! as String],
    _ => [if (m?['role'] case final String role) role],
  };

  /// Undoing one membership change: the run's additions still as it left
  /// them come off ([asLeft], when given, says per item whether it is),
  /// and its removals still absent go back unless deleted since, in which
  /// case the change is [blocked] for good.
  Future<({List<String> removeNow, List<String> addBack, bool blocked})> _plan(
    Map<String, Map<Object?, Object?>?> before,
    Map<String, Map<Object?, Object?>?> after,
    Map<String, Map<Object?, Object?>?> current,
    TableInfo<Table, dynamic> refTable, {
    bool Function(String id)? asLeft,
  }) async {
    final removeNow = [
      for (final id in after.keys)
        if (!before.containsKey(id) &&
            current.containsKey(id) &&
            (asLeft?.call(id) ?? true))
          id,
    ];
    final absent = [
      for (final id in before.keys)
        if (!after.containsKey(id) && !current.containsKey(id)) id,
    ];
    final exists = await existingRowIds(_db, refTable, absent);
    final addBack = [
      for (final id in absent)
        if (exists.contains(id)) id,
    ];
    return (removeNow: removeNow, addBack: addBack, blocked: absent.isNotEmpty);
  }

  GearProvenance _gear(String id, Map<Object?, Object?>? m) => GearProvenance(
    equipmentId: id,
    viaEquipmentId: m?['via'] as String?,
    viaSetId: m?['set'] as String?,
  );

  Future<_Outcome> _undoDiveMembership(
    RuleChange c,
    DiveCollection collection,
  ) async {
    final before = _items(c.before);
    final after = _items(c.after);
    final current = _items(
      (await _dives.members(collection, [c.targetId]))[c.targetId],
    );
    final (:removeNow, :addBack, :blocked) = await _plan(
      before,
      after,
      current,
      DiveRuleApplier.refTable(_db, collection),
      // A buddy whose roles the diver changed since stays.
      asLeft: collection == DiveCollection.buddies
          ? (id) => '${_roles(current[id])}' == '${_roles(after[id])}'
          : null,
    );
    if (removeNow.isEmpty && addBack.isEmpty) {
      return blocked ? _Outcome.blocked : _Outcome.edited;
    }
    final diveId = c.targetId;
    switch (collection) {
      case DiveCollection.diveTypes:
        // Each type goes back where it stood, so a removed representative
        // type is first again.
        final types = [
          for (final t in current.keys)
            if (!removeNow.contains(t)) t,
        ];
        final order = before.keys.toList();
        for (final t in addBack) {
          types.insert(order.indexOf(t).clamp(0, types.length), t);
        }
        await _dives.replaceDiveTypes(diveId, types);
      case DiveCollection.equipment:
        await _dives.replaceGear(
          diveId,
          _restoredGear(before, current, removeNow, addBack),
        );
      case DiveCollection.buddies:
        if (removeNow.isNotEmpty) {
          await _dives.writeMembership(
            collection,
            add: false,
            diveIds: [diveId],
            ids: removeNow,
          );
        }
        if (addBack.isNotEmpty) {
          await _dives.addBuddiesWithRoles(diveId, {
            for (final b in addBack) b: _roles(before[b]),
          });
        }
      case DiveCollection.tags || DiveCollection.courses:
        if (removeNow.isNotEmpty) {
          await _dives.writeMembership(
            collection,
            add: false,
            diveIds: [diveId],
            ids: removeNow,
          );
        }
        if (addBack.isNotEmpty) {
          await _dives.writeMembership(
            collection,
            add: true,
            diveIds: [diveId],
            ids: addBack,
          );
        }
    }
    return _Outcome.restored;
  }

  /// The dive's gear with the run's additions taken off and its removals
  /// put back. A part the run's assembly adopted goes back to how it was
  /// before (taking the assembly off would otherwise take the part with
  /// it), and a row whose assembly is no longer on the dive stands alone.
  List<GearProvenance> _restoredGear(
    Map<String, Map<Object?, Object?>?> before,
    Map<String, Map<Object?, Object?>?> current,
    List<String> removeNow,
    List<String> addBack,
  ) {
    final gone = removeNow.toSet();
    final rows = [
      for (final e in current.entries)
        if (!gone.contains(e.key))
          switch (_gear(e.key, e.value)) {
            final g when gone.contains(g.viaEquipmentId) =>
              before.containsKey(e.key)
                  ? _gear(e.key, before[e.key])
                  : GearProvenance(equipmentId: e.key),
            final g => g,
          },
      for (final id in addBack) _gear(id, before[id]),
    ];
    final onDive = {for (final r in rows) r.equipmentId};
    return [
      for (final r in rows)
        r.viaEquipmentId == null || onDive.contains(r.viaEquipmentId)
            ? r
            : r.copyWith(clearViaEquipmentId: true),
    ];
  }

  Future<_Outcome> _undoSiteMembership(
    RuleChange c,
    SiteCollection collection,
  ) async {
    final (:removeNow, :addBack, :blocked) = await _plan(
      _items(c.before),
      _items(c.after),
      _items((await _sites.members(collection, [c.targetId]))[c.targetId]),
      SiteRuleApplier.refTable(_db, collection),
    );
    if (removeNow.isEmpty && addBack.isEmpty) {
      return blocked ? _Outcome.blocked : _Outcome.edited;
    }
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
