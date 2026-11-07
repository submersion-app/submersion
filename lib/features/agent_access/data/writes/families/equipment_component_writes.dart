import 'package:meta/meta.dart';

import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/gear_history_rewrite.dart';

/// The parts of an assembly, through the repository its components card
/// uses: a part is added at the end, given a role, swapped for another item
/// in its place, moved to a position the assembly holds and removed. A part
/// that would make an item part of itself is refused, as the card refuses
/// it.
class EquipmentComponentWrites extends WritableEntry {
  EquipmentComponentWrites(this._r);

  final RecordRepositories _r;

  @override
  String get name => 'equipment_components';

  @override
  String get table => 'equipment_components';

  @override
  ChildOf get parent =>
      const ChildOf(entity: 'equipment', field: 'parent_equipment_id');

  @override
  late final Map<String, FieldCodec> fields = {
    'parent_equipment_id': const FieldCodec.reference('equipment'),
    'component_equipment_id': const FieldCodec.reference('equipment'),
    'role': const FieldCodec.text(maxLength: 60, allowBlank: true, trim: true),
    'sort_order': const FieldCodec.integer(min: 0, max: 999),
  };

  @override
  Set<String> get requiredOnCreate => const {'component_equipment_id'};

  /// A part is in an assembly once, so two changes in one set cannot put
  /// it there twice.
  @override
  UniqueClaim? uniqueKey(WriteCheck check) {
    final componentId = check.values['component_equipment_id'] as String?;
    if (componentId == null) return null;
    final parentId =
        check.values['parent_equipment_id'] as String? ??
        check.document!['parent_equipment_id']! as String;
    return UniqueClaim('$parentId/$componentId');
  }

  /// A part's place in its assembly, the number [update] takes: a removal
  /// leaves a gap in the stored order, so the stored number can run past it.
  @override
  Future<Map<String, Object?>> stored(
    String id,
    Map<String, Object?> document,
  ) async {
    final siblings = await _r.equipmentComponents.getComponents(
      document['parent_equipment_id']! as String,
    );
    return {...document, 'sort_order': siblings.indexWhere((c) => c.id == id)};
  }

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    if (check.kind == ChangeKind.delete) return null;
    final components = _r.equipmentComponents;
    final parentId =
        check.values['parent_equipment_id'] as String? ??
        check.document!['parent_equipment_id']! as String;
    final siblings = await components.getComponents(parentId);
    if (check.values['sort_order'] case final int slot) {
      if (check.kind == ChangeKind.create) {
        return const PlanBlock(
          BlockReason.invalidValue,
          'sort_order: a new part goes last; move it with an update once it '
          'is in the assembly.',
        );
      }
      if (slot >= siblings.length) {
        return PlanBlock(
          BlockReason.invalidValue,
          'sort_order: this assembly holds positions 0 to '
          '${siblings.length - 1}.',
        );
      }
    }
    final componentId = check.values['component_equipment_id'] as String?;
    if (componentId == null) return null;
    if (await _closesLoop(parentId, componentId, check.soFar)) {
      return const PlanBlock(
        BlockReason.invalidValue,
        'component_equipment_id: that would make an item part of itself.',
      );
    }
    if (siblings.any((c) => c.componentEquipmentId == componentId)) {
      return PlanBlock(
        BlockReason.duplicateRecord,
        'component_equipment_id: $componentId is a part of this assembly '
        'already.',
      );
    }
    return null;
  }

  /// Whether linking [componentId] under [parentId] makes an item part of
  /// itself, counting the links the set adds before this change, as
  /// `wouldCreateCycle` counts the stored ones.
  Future<bool> _closesLoop(
    String parentId,
    String componentId,
    SetSoFar soFar,
  ) async {
    if (componentId == parentId) return true;
    final parentsOf = <String, Set<String>>{};
    void link(String parent, String part) =>
        (parentsOf[part] ??= {}).add(parent);
    for (final row in await _r.equipmentComponents.getAllComponents()) {
      link(row.parentEquipmentId, row.componentEquipmentId);
    }
    for (final values in soFar.created[name] ?? const []) {
      link(
        values['parent_equipment_id']! as String,
        values['component_equipment_id']! as String,
      );
    }
    final seen = <String>{};
    final frontier = [parentId];
    while (frontier.isNotEmpty) {
      final next = frontier.removeLast();
      if (!seen.add(next)) continue;
      if (next == componentId) return true;
      frontier.addAll(parentsOf[next] ?? const {});
    }
    return false;
  }

  /// A part change follows on the planned dives that carry the assembly
  /// (issue #4283); an agent never rewrites logged dives.
  @override
  Future<Map<String, int>> createTouched(
    String diverId,
    Map<String, Object?> values,
  ) async => _plannedTouched(values['parent_equipment_id'] as String?);

  @override
  Future<SideEffects> sideEffects(
    String id,
    String? ownerId,
    RecordUpdate update,
    Map<String, Object?> document,
  ) async => update.values.containsKey('component_equipment_id')
      ? SideEffects(
          touched: await _plannedTouched(
            document['parent_equipment_id'] as String?,
          ),
        )
      : const SideEffects();

  @override
  Future<DeleteReach> deleteReach(
    String id, {
    Map<String, Set<String>> alongside = const {},
  }) async => DeleteReach(
    touched: await _plannedTouched((await _row(id))?.parentEquipmentId),
  );

  Future<Map<String, int>> _plannedTouched(String? assemblyId) async {
    if (assemblyId == null) return const {};
    final n = await _r.dives.countPlannedDivesWithAssembly(assemblyId);
    return {if (n > 0) 'dives': n};
  }

  /// The stored part [id], or null when it is gone.
  Future<EquipmentComponent?> _row(String id) async {
    for (final c in await _r.equipmentComponents.getAllComponents()) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// The planned dives this entity's writes rewrote, held for [afterApply].
  /// An apply that rolls back never reaches it, and the next apply's rescan
  /// then takes these along too: a rescan of an unchanged dive is harmless.
  final _rewrittenDives = <String>{};

  /// Inside the apply's transaction, so a revert takes it back with the
  /// part; the rescan waits for [afterApply], once the rows are committed.
  Future<void> _followOnPlannedDives(
    String assemblyId,
    GearHistoryRewrite rewrite,
  ) => _r.dives.rewriteAssemblyOnDives(
    assemblyId,
    [rewrite],
    alsoLogged: false,
    deferTo: _rewrittenDives,
  );

  /// The planned dives a part change rewrote are rescanned, as a save would
  /// (issue #2853), once the apply has committed. Sync hears of the apply
  /// from the applier itself.
  @override
  Future<void> afterApply(List<AppliedChange> changes, ApplyRun run) async {
    if (_rewrittenDives.isEmpty) return;
    final dives = Set.of(_rewrittenDives);
    _rewrittenDives.clear();
    scheduleQualityScan(dives);
  }

  @visibleForTesting
  Set<String> get pendingRescan => Set.unmodifiable(_rewrittenDives);

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async {
    final parentId = values['parent_equipment_id']! as String;
    final componentId = values['component_equipment_id']! as String;
    final row = await _r.equipmentComponents.addComponent(
      parentId: parentId,
      componentId: componentId,
      role: values['role'] as String? ?? '',
    );
    await _followOnPlannedDives(parentId, GearPartAdded(componentId));
    return row.id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final components = _r.equipmentComponents;
    final v = update.values;
    if (v['component_equipment_id'] case final String componentId) {
      // Read before the swap: the rewrite needs the part it replaces.
      final before = await _row(id);
      await components.replaceComponent(id, componentId);
      if (before != null) {
        await _followOnPlannedDives(
          before.parentEquipmentId,
          GearPartReplaced(
            oldPartId: before.componentEquipmentId,
            newPartId: componentId,
          ),
        );
      }
    }
    if (v['role'] case final String role) {
      await components.updateRole(id, role);
    }
    if (v['sort_order'] case final int slot) {
      // The assembly's parts trade places, so this one lands at [slot] and
      // the parts between shift by one, as a drag on the card does.
      final row = (await _row(id))!;
      final ordered = [
        for (final c in await components.getComponents(row.parentEquipmentId))
          if (c.id != id) c.id,
      ]..insert(slot, id);
      await components.reorder(row.parentEquipmentId, ordered);
    }
  }

  @override
  Future<void> delete(String id, String? ownerId) async {
    final before = await _row(id);
    await _r.equipmentComponents.removeComponent(id);
    if (before != null) {
      await _followOnPlannedDives(
        before.parentEquipmentId,
        GearPartRemoved(before.componentEquipmentId),
      );
    }
  }
}
