import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';

/// Makes [version] the item's recorded firmware (issue #5104), replacing
/// only the curated `firmware_version` row; every other attribute is written
/// back as it was. Does nothing for an item that no longer exists.
Future<void> setRecordedFirmwareVersion(
  EquipmentRepository equipment,
  String equipmentId,
  String version,
) async {
  final item = await equipment.getEquipmentById(equipmentId);
  if (item == null) return;
  if (item.firmwareVersion == version) return;
  await equipment.saveAttributes(equipmentId, [
    for (final a in item.attributes)
      if (a.isCustom || a.key != EquipmentAttrKeys.firmwareVersion) a,
    EquipmentAttribute.curated(
      equipmentId: equipmentId,
      key: EquipmentAttrKeys.firmwareVersion,
      valueText: version,
    ),
  ]);
}
