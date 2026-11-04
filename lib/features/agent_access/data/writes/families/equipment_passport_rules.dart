import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/write_reach.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// The field an item's NFC or QR tag id is written through, as the link tag
/// dialog writes it (assignPassportId). The app keeps it as a system
/// attribute, which the attributes list leaves out.
const passportKey = 'passport_id';

/// A passport id as the tag payload carries it: a lower-case UUID.
final _uuidShape = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

/// [item]'s passport id, or null.
String? passportOf(EquipmentItem item) {
  for (final a in item.attributes) {
    if (!a.isCustom && a.key == EquipmentAttrKeys.passportId) {
      return a.valueText;
    }
  }
  return null;
}

/// A block for [check]'s passport id: one the tag payload could carry, and
/// not held by another item still in service, as the dialog refuses one.
Future<PlanBlock?> passportProblem(
  WriteCheck check,
  RecordRepositories r,
) async {
  final passport = check.values[passportKey];
  if (passport is! String) return null;
  if (!_uuidShape.hasMatch(passport)) {
    return const PlanBlock(
      BlockReason.invalidValue,
      'passport_id: a lower-case UUID, as a tag carries it.',
    );
  }
  final holder = await r.cylinderPassports.findHolderByPassportId(
    passport,
    diverId: check.ownerId,
  );
  if (holder == null || holder.equipmentId == check.id) return null;
  final held = await r.equipment.getEquipmentById(holder.equipmentId);
  if (held == null || !held.isFitted) return null;
  return PlanBlock(
    BlockReason.duplicateRecord,
    'passport_id: ${held.name} (${held.id}) is in service with that tag.',
  );
}

/// The fills a new passport id moves onto [itemId]: those under the id
/// that no cylinder holds yet, and those under the item's old id.
Future<Map<String, int>> passportTouched(
  String itemId,
  String passport,
  String? previous,
) async {
  final loose = await countRows(
    'cylinder_fills',
    'passport_id = ?1 AND (equipment_id IS NULL OR equipment_id != ?2)',
    passport,
    [itemId],
  );
  final rekeyed = previous == null || previous == passport
      ? 0
      : await countRows('cylinder_fills', 'passport_id = ?1', previous);
  final n = loose + rekeyed;
  return {if (n > 0) 'cylinder_fills': n};
}
