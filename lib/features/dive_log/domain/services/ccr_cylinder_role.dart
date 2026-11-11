import 'package:submersion/core/constants/app_enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_tank.dart';

/// The role a CCR dive's cylinder plays in `classifyCcrGasChanges` and in
/// its bailout ascent gases: an untagged (back gas) cylinder is loop gas, the
/// O2 supply when it holds pure O2 and otherwise a diluent (see
/// `classifyCcrGasChanges`). A Twin Set is a role the diver chose, so it is
/// open-circuit gas on a CCR dive (issue #3374).
///
/// Kept apart from `ccr_gas_schedule.dart` so the Insights SQL functions,
/// which the browser's database worker loads, reach no UI code (issue #4420).
TankRole ccrCylinderRole(DiveTank tank) {
  if (tank.role != TankRole.backGas) return tank.role;
  return tank.gasMix.o2 >= 99.0 ? TankRole.oxygenSupply : TankRole.diluent;
}
