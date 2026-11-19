import 'package:flutter/foundation.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/change_log/record_sitting_writer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/services/set_history_diff.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';

/// Writes an equipment set page's editing sitting (issue #4527, phase 3):
/// its changed values, the default it demotes and the dives that follow
/// its gear, in one transaction and one History entry labelled with the
/// cards it changed.
class EquipmentSetEditSaveService {
  EquipmentSetEditSaveService(this._sets, this._dives);

  final EquipmentSetRepository _sets;
  final DiveRepository _dives;

  /// Saves [apply] onto set [setId] as stored now, so a value changed
  /// underneath on a card the diver never touched is kept. Writes, in
  /// order: the row with its members and bundle lists, the default flag,
  /// the geofences, then the change in the set's gear on the dives that
  /// carry it or a set that includes it: planned dives always, logged ones
  /// when [alsoLogged], else the logged ones stop naming the set and keep
  /// their gear (issues #4283, #4500, #4525). A failure anywhere writes
  /// nothing. Returns the set before and after, or null when nothing
  /// changed. Throws [StateError] when it no longer exists.
  Future<({EquipmentSet before, EquipmentSet after})?> save({
    required String setId,
    required EquipmentSet Function(EquipmentSet stored) apply,
    required Iterable<String> changedCardIds,
    bool alsoLogged = false,
  }) => writeRecordSitting<EquipmentSet>(
    table: 'equipment_sets',
    recordId: setId,
    changedCardIds: changedCardIds,
    read: () => _sets.getSetById(setId, includeGeofences: true),
    apply: apply,
    write: (stored, merged) => _write(stored, merged, alsoLogged: alsoLogged),
  );

  Future<void> _write(
    EquipmentSet stored,
    EquipmentSet merged, {
    required bool alsoLogged,
  }) async {
    // The gear the set applies is its own and that of the sets it includes:
    // with neither changed, no dive needs anything.
    final gearMayChange =
        !setEquals(stored.equipmentIds.toSet(), merged.equipmentIds.toSet()) ||
        !listEquals(stored.includedSetIds, merged.includedSetIds);
    // Every set of the owner before the save: the dives of a set that
    // includes this one carry its gear too.
    final allSets = gearMayChange
        ? await _sets.getAllSets(diverId: stored.diverId)
        : const <EquipmentSet>[];
    await _sets.updateSet(merged);
    if (merged.isDefault != stored.isDefault) {
      if (merged.isDefault) {
        await _sets.setAsDefault(merged.id);
      } else {
        await _sets.clearDefault(merged.id);
      }
    }
    await _writeGeofences(stored, merged);
    if (!gearMayChange) return;
    // The save drops members whose gear has gone, so the replay goes by
    // what was written.
    final written = await _sets.getSetById(merged.id);
    if (written == null) return;
    final changes = setHistoryRewrites(
      before: stored,
      after: written,
      allSets: allSets,
    );
    for (final change in changes) {
      await _dives.rewriteSetOnDives(
        change.setId,
        change.rewrites,
        alsoLogged: alsoLogged,
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
