import 'package:flutter/foundation.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/change_log/record_sitting_writer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/services/set_history_diff.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';

/// The save would change the dives of a set the diver was not asked about
/// ("Update past dives?" covered other sets): the sets that include this
/// one changed after the question. Nothing is written; ask again.
class SetHistoryNotConfirmed implements Exception {
  const SetHistoryNotConfirmed(this.setIds);

  /// The sets whose dives would change without the diver's answer.
  final Set<String> setIds;

  @override
  String toString() => 'SetHistoryNotConfirmed($setIds)';
}

/// Writes an equipment set page's editing sitting (issue #4527, phase 3):
/// its changed values, the default it demotes and the dives that follow
/// its gear, in one transaction and one History entry labelled with the
/// cards it changed.
class EquipmentSetEditSaveService {
  EquipmentSetEditSaveService(
    this._sets,
    this._dives, {
    void Function(Iterable<String> diveIds) scheduleScan = scheduleQualityScan,
  }) : _scheduleScan = scheduleScan;

  final EquipmentSetRepository _sets;
  final DiveRepository _dives;

  /// Queues the quality rescan of dives whose gear the save rewrote.
  final void Function(Iterable<String> diveIds) _scheduleScan;

  /// Saves [apply] onto set [setId] as stored now, so a value changed
  /// underneath on a card the diver never touched is kept. Writes, in
  /// order: the row with its members and bundle lists, the default flag,
  /// the geofences, then the change in the set's gear on the dives that
  /// carry it or a set that includes it: planned dives always, logged ones
  /// when [alsoLogged], else the logged ones stop naming the set and keep
  /// their gear (issues #4283, #4500, #4525). A failure anywhere writes
  /// nothing, and the dives it rewrote are queued for a quality rescan
  /// only once it has committed. Returns the set before and after, or null
  /// when nothing changed. Throws [StateError] when it no longer exists.
  ///
  /// [coveredSetIds] are the sets whose dives "Update past dives?" was
  /// asked about (none when it was not asked): a save that would change the
  /// dives of another, because the sets including this one changed since,
  /// throws [SetHistoryNotConfirmed] and writes nothing. Null skips the
  /// check.
  Future<({EquipmentSet before, EquipmentSet after})?> save({
    required String setId,
    required EquipmentSet Function(EquipmentSet stored) apply,
    required Iterable<String> changedCardIds,
    bool alsoLogged = false,
    Set<String>? coveredSetIds,
  }) async {
    final rewritten = <String>{};
    final result = await writeRecordSitting<EquipmentSet>(
      table: 'equipment_sets',
      recordId: setId,
      changedCardIds: changedCardIds,
      read: () => _sets.getSetById(setId, includeGeofences: true),
      apply: apply,
      write: (stored, merged) => _write(
        stored,
        merged,
        alsoLogged: alsoLogged,
        rewritten: rewritten,
        coveredSetIds: coveredSetIds,
      ),
    );
    // As a rewrite outside a sitting does (issue #2853): a gear overlap can
    // appear or go with the gear.
    if (rewritten.isNotEmpty) _scheduleScan(rewritten);
    return result;
  }

  /// Creates [set], a new set's or a clone's sitting (issue #4527, phase
  /// 3, plan 11), keeping its id: the row with its members and bundle
  /// lists, the default (demoting the diver's other default) and each
  /// geofence, then [alsoWrite], in one transaction and one History entry
  /// naming [changedCardIds]. A new set has no dives, so none are asked
  /// about or rewritten. If any write throws nothing is left. Throws
  /// [StateError] when [set] has no id, or one a stored set has.
  Future<EquipmentSet> create({
    required EquipmentSet set,
    required Iterable<String> changedCardIds,
    Future<void> Function()? alsoWrite,
  }) => createRecordSitting<EquipmentSet>(
    table: 'equipment_sets',
    recordId: set.id,
    changedCardIds: changedCardIds,
    isStored: () async => await _sets.getSetById(set.id) != null,
    insert: () async {
      await _sets.createSet(set);
      if (set.isDefault) await _sets.setAsDefault(set.id);
      for (final fence in set.geofences) {
        await _sets.addGeofence(fence.copyWith(setId: set.id));
      }
    },
    alsoWrite: alsoWrite,
    readBack: () => _sets.getSetById(set.id, includeGeofences: true),
    created: set,
  );

  Future<void> _write(
    EquipmentSet stored,
    EquipmentSet merged, {
    required bool alsoLogged,
    required Set<String> rewritten,
    required Set<String>? coveredSetIds,
  }) async {
    final written = await _sets.updateSet(merged);
    if (merged.isDefault != stored.isDefault) {
      if (merged.isDefault) {
        await _sets.setAsDefault(merged.id);
      } else {
        await _sets.clearDefault(merged.id);
      }
    }
    await _writeGeofences(stored, merged);
    // The gear the set applies is its own and that of the sets it includes,
    // and the replay goes by what the save wrote: it drops members whose
    // gear has gone. With neither changed, no dive needs anything.
    if (written.added.isEmpty &&
        written.removed.isEmpty &&
        listEquals(stored.includedSetIds, merged.includedSetIds)) {
      return;
    }
    final after = await _sets.getSetById(merged.id);
    if (after == null) return;
    // Every set of the owner: the dives of a set that includes this one
    // carry its gear too. This set is compared as it was and as written.
    final allSets = await _sets.getAllSets(diverId: stored.diverId);
    final changes = setHistoryRewrites(
      before: stored,
      after: after,
      allSets: allSets,
    );
    if (coveredSetIds != null) {
      final unasked = {
        for (final change in changes)
          if (!coveredSetIds.contains(change.setId)) change.setId,
      };
      if (unasked.isNotEmpty) throw SetHistoryNotConfirmed(unasked);
    }
    for (final change in changes) {
      // The sitting tells sync once it commits, and the rescan follows it.
      rewritten.addAll(
        await _dives.rewriteSetOnDives(
          change.setId,
          change.rewrites,
          alsoLogged: alsoLogged,
          notify: false,
        ),
      );
      if (!alsoLogged) await _dives.unlinkSetFromLoggedDives(change.setId);
    }
  }

  /// Writes the difference between the geofences [stored] has and those
  /// [merged] has.
  Future<void> _writeGeofences(EquipmentSet stored, EquipmentSet merged) async {
    final before = {for (final g in stored.geofences) g.id: g};
    final after = {for (final g in merged.geofences) g.id: g};
    for (final id in before.keys) {
      if (!after.containsKey(id)) await _sets.removeGeofence(id);
    }
    for (final fence in merged.geofences) {
      final was = before[fence.id];
      final withSet = fence.copyWith(setId: merged.id);
      if (was == null) {
        await _sets.addGeofence(withSet);
      } else if (!was.sameEdit(fence)) {
        await _sets.updateGeofence(withSet);
      }
    }
  }
}

final equipmentSetEditSaveServiceProvider =
    Provider<EquipmentSetEditSaveService>(
      (ref) => EquipmentSetEditSaveService(
        ref.watch(equipmentSetRepositoryProvider),
        ref.watch(diveRepositoryProvider),
      ),
    );
