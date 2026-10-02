import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/domain/services/equipment_arranger.dart';
import 'package:submersion/features/equipment/domain/services/gear_tree.dart';
import 'package:submersion/features/equipment/figure/domain/figure_inputs.dart';
import 'package:submersion/features/equipment/figure/domain/figure_model.dart';

/// A dive's top-level gear rows as the gear tree shows them: parts sit
/// inside their assembly's row, and the rows follow the diver's
/// arrangement. The tree and the dive figure both read this, so the
/// figure's numbers run down the tree's rows.
List<EquipmentGroup> arrangedDiveGear(
  List<GearLink> links,
  EquipmentArrangement arrangement, {
  required String Function(EquipmentType) typeLabel,
}) => arrangeEquipment(
  [for (final node in GearTree.build(links)) node.link.item],
  arrangement,
  typeLabel: typeLabel,
);

/// The dive-tank role of each gear item a dive tank is linked to
/// (`dive_tanks.equipment_id`). On a dive logged from several computers two
/// tanks can name the same item; the first by `order` wins.
Map<String, TankRole> tankRolesByItem(List<DiveTank> tanks) {
  final sorted = [...tanks]..sort((a, b) => a.order.compareTo(b.order));
  final roles = <String, TankRole>{};
  for (final tank in sorted) {
    final id = tank.equipmentId;
    if (id != null) roles.putIfAbsent(id, () => tank.role);
  }
  return roles;
}

/// Composer inputs for a dive's [topLevel] rows, in that order. Every row is
/// numbered, even one the tree promoted from an orphaned part, so each row's
/// badge has a label; a tank carries its dive role from [tankRoles].
List<FigureItemInput> figureInputsForDive(
  List<EquipmentItem> topLevel,
  Map<String, TankRole> tankRoles,
) => [
  for (final item in topLevel)
    FigureItemInput(
      id: item.id,
      type: item.type,
      name: item.name,
      attributes: figureAttributesOf(item),
      tankRole: tankRoles[item.id],
    ),
];
