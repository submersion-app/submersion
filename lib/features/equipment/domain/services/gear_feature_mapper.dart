import 'package:submersion/core/buoyancy/gear_buoyancy_traits.dart';
import 'package:submersion/core/buoyancy/gear_feature.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// Converts an equipment item to a buoyancy-engine feature.
///
/// The single bridge between the equipment data model and `core/buoyancy`,
/// which stays free of any [EquipmentAttribute] import. Both the Weight
/// Planner and the buoyancy twin's rig assembler go through here, so a logged
/// dive and a planned dive derive the same priors from the same attributes
/// (before #1103 the assembler had its own copy that dropped [traits], so a
/// trilaminate drysuit or a rated wing informed the planner but not the
/// dive-detail Buoyancy section).
///
/// Returns null for the excluded types: lead ([EquipmentType.weights]) is the
/// predicted quantity -- see `EquipmentLead` for how it is counted instead --
/// and tanks are modeled from the tank list.
GearFeature? gearFeatureFromEquipment(EquipmentItem item) {
  if (item.type == EquipmentType.weights || item.type == EquipmentType.tank) {
    return null;
  }
  // Index the curated attributes once. attrText/attrNum are each an O(n)
  // scan, and reading them individually would rescan thickness_mm three
  // times; putIfAbsent preserves their first-match semantics.
  final attrs = <String, EquipmentAttribute>{};
  for (final a in item.attributes) {
    if (!a.isCustom) attrs.putIfAbsent(a.key, () => a);
  }
  final thicknessText = attrs[EquipmentAttrKeys.thicknessMm]?.valueText;
  return GearFeature.fromEquipment(
    id: item.id,
    type: item.type,
    name: item.name,
    size: attrs[EquipmentAttrKeys.size]?.valueText,
    thickness: thicknessText,
    buoyancyKg: attrs[EquipmentAttrKeys.buoyancyKg]?.valueNum,
    weightKg: attrs[EquipmentAttrKeys.dryWeightKg]?.valueNum,
    traits: GearBuoyancyTraits(
      primaryThicknessMm: attrs[EquipmentAttrKeys.thicknessMm]?.valueNum,
      panelThicknessesMm: thicknessText == null
          ? const []
          : GearBuoyancyTraits.parsePanelsMm(thicknessText),
      suitStyle: attrs[EquipmentAttrKeys.suitStyle]?.valueText,
      shellMaterial: attrs[EquipmentAttrKeys.shellMaterial]?.valueText,
      bcdStyle: attrs[EquipmentAttrKeys.bcdStyle]?.valueText,
      liftCapacityKg: attrs[EquipmentAttrKeys.liftCapacityKg]?.valueNum,
      gloveType: attrs[EquipmentAttrKeys.gloveType]?.valueText,
    ),
  );
}
