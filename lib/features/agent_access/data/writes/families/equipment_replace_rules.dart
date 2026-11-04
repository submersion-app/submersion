import 'package:submersion/features/agent_access/data/writes/families/equipment_item_rules.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// The field an equipment create names to replace a fitted part, as the
/// children card's Replace does: the new part copies the old one's name,
/// type, make and spec into its place, and the old one is retired.
const replacesKey = 'replaces_equipment_id';

/// What a create without [replacesKey] must name.
const newItemKeys = ['name', 'type'];

/// A block for [check]'s use of [replacesKey], or for a create that names
/// neither it nor what a new item needs. [load] reads an item.
Future<PlanBlock?> replacementProblem(
  WriteCheck check,
  Future<EquipmentItem?> Function(String id) load,
) async {
  final oldId = check.values[replacesKey] as String?;
  if (check.kind == ChangeKind.update) {
    return check.values.containsKey(replacesKey)
        ? const PlanBlock(
            BlockReason.invalidValue,
            '$replacesKey: only a new item replaces a part.',
          )
        : null;
  }
  if (oldId == null) {
    final missing = [
      for (final key in newItemKeys)
        if (!check.values.containsKey(key)) key,
    ];
    return missing.isEmpty
        ? null
        : PlanBlock(
            BlockReason.missingField,
            'A new equipment record needs ${missing.join(', ')}, or '
            '$replacesKey to replace a fitted part.',
          );
  }
  final others = check.values.keys.where((k) => k != replacesKey).toList();
  if (others.isNotEmpty) {
    return PlanBlock(
      BlockReason.invalidValue,
      '${others.join(', ')}: a replacement copies its part; change it with '
      'an update once it exists.',
    );
  }
  final old = await load(oldId);
  if (old == null) return null;
  if (old.parentEquipmentId == null ||
      !inKitSoFar(check.soFar, oldId, stored: old.isFitted)) {
    return const PlanBlock(
      BlockReason.invalidValue,
      '$replacesKey: only a part fitted to an item in the kit is replaced.',
    );
  }
  return null;
}
