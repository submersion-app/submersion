import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_passports/domain/services/passport_attribute_keys.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';

/// The curated attribute rows that record a new cylinder's spec, for an item
/// passed to `EquipmentRepository.createEquipment` (which fills in the
/// equipment id). Shared by a scanned tag's "Add to my gear" and by a
/// cylinder made from a dive's tank (issue #4494). [valveChoice] is a tank
/// catalog valve key; [suitInflation] records `cylinder_use`, which is left
/// unset for breathing gas as the catalog's default.
List<EquipmentAttribute> cylinderSpecAttributes({
  double? volumeL,
  double? workingPressureBar,
  TankMaterial? material,
  String? valveChoice,
  bool suitInflation = false,
}) => [
  if (volumeL != null)
    EquipmentAttribute.curated(
      equipmentId: '',
      key: EquipmentAttrKeys.volumeL,
      valueNum: volumeL,
    ),
  if (workingPressureBar != null)
    EquipmentAttribute.curated(
      equipmentId: '',
      key: EquipmentAttrKeys.workingPressureBar,
      valueNum: workingPressureBar,
    ),
  if (material != null)
    EquipmentAttribute.curated(
      equipmentId: '',
      key: EquipmentAttrKeys.tankMaterial,
      valueText: tankMaterialChoiceKey(material),
    ),
  if (valveChoice != null)
    EquipmentAttribute.curated(
      equipmentId: '',
      key: 'valve_type',
      valueText: valveChoice,
    ),
  if (suitInflation)
    EquipmentAttribute.curated(
      equipmentId: '',
      key: EquipmentAttrKeys.cylinderUse,
      valueText: 'suit_inflation',
    ),
];
