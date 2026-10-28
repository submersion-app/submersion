/// The ppO2 limit a logged cylinder's MOD is shown at (issue #3752).
///
/// The planner's role rule (issue #3567, [modLimitClassFor]) applied to a
/// logged dive: the deco limit for a deco gas, the oxygen supply and a
/// bailout richer than air; the CCR Dil MOD limit for a diluent; the bottom
/// limit for everything else.
///
/// A logged role is stored as recorded, never derived, so the dive's mode
/// settles the one role that depends on it: a diluent on an open-circuit
/// dive is left over from somewhere else and is held to the bottom limit,
/// as the planner holds a diluent on an open-circuit plan.
library;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/services/tank_mod.dart';

/// Which limit the MOD of a cylinder of [role] with [gas] follows on a dive
/// logged in [diveMode].
ModLimitClass loggedTankModLimit(
  TankRole role,
  GasMix gas,
  DiveMode diveMode,
) => role == TankRole.diluent && !_isLoop(diveMode)
    ? ModLimitClass.bottom
    : modLimitClassFor(role, gas);

/// The ppO2 [limit] stands for.
double modLimitPpO2(
  ModLimitClass limit, {
  required double bottomPpO2,
  required double decoPpO2,
  required double diluentPpO2,
}) => switch (limit) {
  ModLimitClass.bottom => bottomPpO2,
  ModLimitClass.deco => decoPpO2,
  ModLimitClass.diluent => diluentPpO2,
};

bool _isLoop(DiveMode diveMode) => switch (diveMode) {
  DiveMode.ccr || DiveMode.scr => true,
  DiveMode.oc || DiveMode.gauge => false,
};
