import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/max_operating_depth.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

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

/// O2 percentage above which a bailout cylinder counts as a deco gas. A
/// bailout richer than air is carried for the ascent; air or anything
/// leaner is bottom bailout.
const double _airO2Percent = 21;

/// The ppO2 limit [role] calls for with [gas] in the cylinder.
///
/// The deco limit for a deco gas and the CCR oxygen supply, and for a
/// bailout richer than air. The bottom limit for everything else: back gas,
/// stages, sidemount, pony, diluent, and air or leaner bailout.
double modPpO2For(
  TankRole role,
  GasMix gas, {
  required double bottomPpO2,
  required double decoPpO2,
}) => usesDecoLimit(role, gas) ? decoPpO2 : bottomPpO2;

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
}) => maxOperatingDepthMeters(
  gas.o2 / 100.0,
  maxPpO2: modPpO2For(role, gas, bottomPpO2: bottomPpO2, decoPpO2: decoPpO2),
);

/// [tank]'s MOD: the one set by hand when there is one, otherwise its
/// default. [tank]'s role must already be resolved (TankRoleResolver), since
/// a plan stores most roles as a placeholder.
double effectiveModMeters(
  DiveTank tank, {
  required double bottomPpO2,
  required double decoPpO2,
}) =>
    tank.decoSwitchDepth ??
    defaultModMeters(
      tank.role,
      tank.gasMix,
      bottomPpO2: bottomPpO2,
      decoPpO2: decoPpO2,
    );

/// ppO2 of [gas] at [depthMeters], on the same flat 10 m per bar model the
/// MOD is worked out on, so a gas at its default MOD reads back its limit.
double ppO2AtDepth(GasMix gas, double depthMeters) =>
    gas.o2 / 100.0 * (depthMeters / 10.0 + 1.0);

/// What a MOD set by hand means for [tank]: the ppO2 it reaches there and
/// the limit its role calls for. Null when [tank] has no override.
({double ppO2, double limitPpO2, bool exceedsLimit})? modOverrideCheck(
  DiveTank tank, {
  required double bottomPpO2,
  required double decoPpO2,
}) {
  final override = tank.decoSwitchDepth;
  if (override == null) return null;
  final ppO2 = ppO2AtDepth(tank.gasMix, override);
  final limit = modPpO2For(
    tank.role,
    tank.gasMix,
    bottomPpO2: bottomPpO2,
    decoPpO2: decoPpO2,
  );
  // A hair of slack: an override typed at exactly the default MOD lands on
  // the limit, give or take float noise, and is not "above" it.
  return (ppO2: ppO2, limitPpO2: limit, exceedsLimit: ppO2 > limit + 1e-9);
}

/// The gases an open-circuit ascent can breathe, one per tank, each eligible
/// from its MOD up. [tanks] must carry resolved roles.
List<AvailableGas> ascentGasesFor(
  Iterable<DiveTank> tanks, {
  required double bottomPpO2,
  required double decoPpO2,
}) => [
  for (final tank in tanks)
    AvailableGas(
      fN2: (100.0 - tank.gasMix.o2 - tank.gasMix.he) / 100.0,
      fHe: tank.gasMix.he / 100.0,
      maxPpO2Mod: effectiveModMeters(
        tank,
        bottomPpO2: bottomPpO2,
        decoPpO2: decoPpO2,
      ),
    ),
];
