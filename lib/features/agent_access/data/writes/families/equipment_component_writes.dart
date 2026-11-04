import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';

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

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async =>
      (await _r.equipmentComponents.addComponent(
        parentId: values['parent_equipment_id']! as String,
        componentId: values['component_equipment_id']! as String,
        role: values['role'] as String? ?? '',
      )).id;

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final components = _r.equipmentComponents;
    final v = update.values;
    if (v['component_equipment_id'] case final String componentId) {
      await components.replaceComponent(id, componentId);
    }
    if (v['role'] case final String role) {
      await components.updateRole(id, role);
    }
    if (v['sort_order'] case final int slot) {
      // The assembly's parts trade places, so this one lands at [slot] and
      // the parts between shift by one, as a drag on the card does.
      final row = (await components.getAllComponents()).firstWhere(
        (c) => c.id == id,
      );
      final ordered = [
        for (final c in await components.getComponents(row.parentEquipmentId))
          if (c.id != id) c.id,
      ]..insert(slot, id);
      await components.reorder(row.parentEquipmentId, ordered);
    }
  }

  @override
  Future<void> delete(String id, String? ownerId) =>
      _r.equipmentComponents.removeComponent(id);
}
