import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';

/// The roles that are a diver's main gas supply: what a new dive's starter
/// tank, or a new plan's default tank, stands in for until the diver says
/// what they are carrying. Back gas, a twin set, a sidemount pair, and a
/// rebreather's diluent and oxygen.
///
/// Stages, deco, bailout, pony and suit inflation cylinders are carried in
/// addition to a main supply, never instead of one.
const Set<TankRole> mainSupplyRoles = {
  TankRole.backGas,
  TankRole.twinSet,
  TankRole.sidemountLeft,
  TankRole.sidemountRight,
  TankRole.diluent,
  TankRole.oxygenSupply,
};

/// Whether [cylinders] include a main supply (issue #4525). A set that
/// brings one replaces the untouched starter tank; a set that brings only
/// a stage or a deco cylinder leaves the starter where it is and adds its
/// own beside it, since a dive with a stage and no main gas is not a rig.
bool bringsMainSupply(Iterable<CylinderConfigItem> cylinders) =>
    cylinders.any((c) => mainSupplyRoles.contains(c.tankRole));
