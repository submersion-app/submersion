/// A cylinder's maximum operating depth (issue #3567).
///
/// Every cylinder has a default MOD, worked out from its O2 fraction and the
/// ppO2 limit its role calls for: the deco limit for a deco gas, the bottom
/// limit for everything else. The diver can set a different MOD by hand,
/// held in [DiveTank.decoSwitchDepth]; that override is kept as typed, while
/// a default follows the limits whenever they change.
///
/// The planner switches to each gas at its MOD, so what a cylinder shows is
/// where the plan breathes it from.
library;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/deco/max_operating_depth.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// O2 percentage above which a bailout cylinder counts as a deco gas. A
/// bailout richer than air is carried for the ascent; air or anything
/// leaner is bottom bailout.
const double _airO2Percent = 21;

/// Which ppO2 limit a cylinder's default MOD follows (issue #3567): not the
/// limit's value, which two of these can coincidentally share, but which one
/// it is. A caller that needs to tell "the same limit" from "a different
/// one" (the cylinder editor's set-aside cache) keys on this, not on
/// [modPpO2For]'s result.
enum ModLimitClass { deco, bottom, diluent }

/// Which limit [role] with [gas] follows. See [ModLimitClass].
ModLimitClass modLimitClassFor(TankRole role, GasMix gas) => switch (role) {
  TankRole.diluent => ModLimitClass.diluent,
  _ => usesDecoLimit(role, gas) ? ModLimitClass.deco : ModLimitClass.bottom,
};

/// The ppO2 limit [role] calls for with [gas] in the cylinder.
///
/// The deco limit for a deco gas and the CCR oxygen supply, and for a
/// bailout richer than air. The bottom limit for everything else: back gas,
/// stages, sidemount, pony, and air or leaner bailout. A diluent uses its own
/// CCR Dil MOD limit, [diluentPpO2], when the caller has one to hand; a
/// caller where a diluent role is meaningless (bailout, the OC calculator)
/// can leave it out and falls back to [bottomPpO2], as before.
double modPpO2For(
  TankRole role,
  GasMix gas, {
  required double bottomPpO2,
  required double decoPpO2,
  double? diluentPpO2,
}) => switch (role) {
  TankRole.diluent => diluentPpO2 ?? bottomPpO2,
  _ => usesDecoLimit(role, gas) ? decoPpO2 : bottomPpO2,
};

/// Whether [role] with [gas] is held to the deco limit rather than the
/// bottom one. See [modPpO2For].
bool usesDecoLimit(TankRole role, GasMix gas) => switch (role) {
  TankRole.deco || TankRole.oxygenSupply => true,
  TankRole.bailout => gas.o2 > _airO2Percent,
  TankRole.backGas ||
  TankRole.stage ||
  TankRole.sidemountLeft ||
  TankRole.sidemountRight ||
  TankRole.pony ||
  TankRole.diluent => false,
};

/// The MOD in metres [gas] has in a cylinder of [role], at the limit that
/// role calls for. Unrounded: the planner switches on it, and a depth shown
/// to the diver is rounded down at display time.
double defaultModMeters(
  TankRole role,
  GasMix gas, {
  required double bottomPpO2,
  required double decoPpO2,
  double? diluentPpO2,
}) => maxOperatingDepthMeters(
  gas.o2 / 100.0,
  maxPpO2: modPpO2For(
    role,
    gas,
    bottomPpO2: bottomPpO2,
    decoPpO2: decoPpO2,
    diluentPpO2: diluentPpO2,
  ),
);

/// [tank]'s MOD: the one set by hand when there is one, otherwise its
/// default. [tank]'s role must already be resolved (TankRoleResolver), since
/// a plan stores most roles as a placeholder.
double effectiveModMeters(
  DiveTank tank, {
  required double bottomPpO2,
  required double decoPpO2,
  double? diluentPpO2,
}) =>
    tank.decoSwitchDepth ??
    defaultModMeters(
      tank.role,
      tank.gasMix,
      bottomPpO2: bottomPpO2,
      decoPpO2: decoPpO2,
      diluentPpO2: diluentPpO2,
    );

/// ppO2 of [gas] at [depthMeters], on the same flat 10 m per bar model the
/// MOD is worked out on, so a gas at its default MOD reads back its limit.
double ppO2AtDepth(GasMix gas, double depthMeters) =>
    gas.o2 / 100.0 * (depthMeters / 10.0 + 1.0);

/// What a MOD set by hand means for [tank]: the ppO2 it reaches there and
/// the limit its role calls for. Null when [tank] has no override. See
/// [modOverrideCheckFor] for [environment].
({double ppO2, double limitPpO2, bool exceedsLimit})? modOverrideCheck(
  DiveTank tank, {
  required double bottomPpO2,
  required double decoPpO2,
  double? diluentPpO2,
  DiveEnvironment? environment,
}) => switch (tank.decoSwitchDepth) {
  final override? => modOverrideCheckFor(
    tank.role,
    tank.gasMix,
    override,
    bottomPpO2: bottomPpO2,
    decoPpO2: decoPpO2,
    diluentPpO2: diluentPpO2,
    environment: environment,
  ),
  null => null,
};

/// What [overrideMeters] set by hand on a cylinder of [role] with [gas]
/// means: the ppO2 it reaches there and the limit the role calls for.
///
/// Without [environment] the ppO2 is on the flat 10 m per bar model a MOD
/// table uses, as the cylinder editors show it. The planner passes the
/// plan's water, the one its schedule's ppO2 is computed in, so a reported
/// ppO2 matches the table line and an override at the flat default (EAN40
/// at 30 m in seawater, 1.61) is caught the way a default switch is (issue
/// #3566, see [gasSwitchDepthMeters]).
({double ppO2, double limitPpO2, bool exceedsLimit}) modOverrideCheckFor(
  TankRole role,
  GasMix gas,
  double overrideMeters, {
  required double bottomPpO2,
  required double decoPpO2,
  double? diluentPpO2,
  DiveEnvironment? environment,
}) {
  final ppO2 = environment == null
      ? ppO2AtDepth(gas, overrideMeters)
      : gas.o2 / 100.0 * environment.pressureAtDepth(overrideMeters);
  final limit = modPpO2For(
    role,
    gas,
    bottomPpO2: bottomPpO2,
    decoPpO2: decoPpO2,
    diluentPpO2: diluentPpO2,
  );
  // On the flat model, a hair of slack: an override typed at exactly the
  // default MOD lands on the limit, give or take float noise, and is not
  // "above" it. In the plan's water, the slack a default switch gets.
  final slack = environment == null ? 1e-9 : gasSwitchPpO2Tolerance;
  return (ppO2: ppO2, limitPpO2: limit, exceedsLimit: ppO2 > limit + slack);
}

/// The gases an open-circuit ascent can breathe, one per tank, each eligible
/// from its MOD up. [tanks] must carry resolved roles.
///
/// A MOD set by hand is used as typed. A default one is the switch depth for
/// the role's limit in [environment], the water the schedule's ppO2 is
/// computed in (issue #3566, see [gasSwitchDepthMeters]), so no table line
/// shows a gas above its limit.
List<AvailableGas> ascentGasesFor(
  Iterable<DiveTank> tanks, {
  required double bottomPpO2,
  required double decoPpO2,
  required DiveEnvironment environment,
  double? diluentPpO2,
}) => [
  for (final tank in tanks)
    AvailableGas(
      fN2: (100.0 - tank.gasMix.o2 - tank.gasMix.he) / 100.0,
      fHe: tank.gasMix.he / 100.0,
      maxPpO2Mod:
          tank.decoSwitchDepth ??
          gasSwitchDepthMeters(
            tank.gasMix.o2 / 100.0,
            maxPpO2: modPpO2For(
              tank.role,
              tank.gasMix,
              bottomPpO2: bottomPpO2,
              decoPpO2: decoPpO2,
              diluentPpO2: diluentPpO2,
            ),
            environment: environment,
          ),
    ),
];
