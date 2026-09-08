import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/segment_chain.dart';

/// Derives each cylinder's [TankRole] from the gas it carries and the
/// segments that breathe it.
///
/// A plan's cylinders are described by name, size, start pressure and mix. The
/// role used to be a ninth thing the diver declared, and it could disagree
/// with the rest: a cylinder labelled Back Gas that no segment breathes, or a
/// Deco bottle leaner than the bottom mix. The plan already says which tank
/// every segment breathes and what each mix's MOD is, so the role follows.
///
/// The single exception is a CCR bailout cylinder. On a loop plan a 100% O2
/// cylinder is either the oxygen supply or a bailout/deco bottle, and the
/// numbers cannot tell those apart - calling a bailout bottle the O2 supply
/// would quietly drop it out of the bailout calculation. So `bailout` stays an
/// explicit choice: on a loop plan a stored role of [TankRole.bailout] is
/// honoured as the diver's override and never re-derived.
///
/// Only on a loop plan. Open circuit has no such ambiguity, and the tank
/// editor does not even offer the flag there, so a stored bailout role on an
/// OC plan is left over from somewhere else and is re-derived like any
/// other.
///
/// Nothing here is persisted. Callers apply it to their own copy of the plan
/// so the stored role remains the diver's raw input (bailout or nothing),
/// which keeps a derived role from later being mistaken for an override.
class TankRoleResolver {
  const TankRoleResolver();

  /// [plan] with every cylinder's role derived.
  domain.DivePlan apply(domain.DivePlan plan) {
    if (plan.tanks.isEmpty) return plan;
    final roles = rolesFor(plan);
    return plan.copyWith(
      tanks: [
        for (final tank in plan.tanks)
          tank.role == roles[tank.id]
              ? tank
              : tank.copyWith(role: roles[tank.id]),
      ],
    );
  }

  /// The derived role of every cylinder, by tank id.
  Map<String, TankRole> rolesFor(domain.DivePlan plan) {
    final bottomTankId = _bottomTankId(plan);
    final breathed = plan.segments.map((s) => s.tankId).toSet();
    final bottomO2 = _tankById(plan, bottomTankId)?.gasMix.o2 ?? 21.0;
    final isLoop = plan.mode != domain.PlanMode.oc;

    return {
      for (final tank in plan.tanks)
        tank.id: _roleFor(
          tank,
          isLoop: isLoop,
          bottomTankId: bottomTankId,
          bottomO2: bottomO2,
          breathed: breathed,
        ),
    };
  }

  TankRole _roleFor(
    DiveTank tank, {
    required bool isLoop,
    required String? bottomTankId,
    required double bottomO2,
    required Set<String> breathed,
  }) {
    if (isLoop) {
      // The diver's only explicit choice, and honoured only here: on a loop
      // plan a 100% cylinder is either the oxygen supply or a bailout bottle
      // and the numbers cannot tell them apart. An open-circuit plan has no
      // such ambiguity, so a stored bailout role there is stale input - a
      // cylinder carried over from a loop plan, or picked from a saved
      // configuration - and is re-derived like any other. Honouring it would
      // hide the bottle from the lost-gas contingency, which only looks at
      // deco, stage and travel gas.
      if (tank.role == TankRole.bailout) return TankRole.bailout;

      // Pure O2 that nothing breathes directly is the oxygen supply; the gas
      // the segments actually breathe is the diluent; anything else carried
      // on a loop dive is open-circuit bailout.
      if (tank.gasMix.o2 >= 99.5 && !breathed.contains(tank.id)) {
        return TankRole.oxygenSupply;
      }
      if (breathed.contains(tank.id)) return TankRole.diluent;
      return TankRole.bailout;
    }

    // A travel gas is leaner than the bottom mix, so the "richer than the
    // bottom gas" test below would file it as a stage anyway - but say so
    // explicitly, because it must not become the back gas (turn pressure and
    // rock-bottom apply to the back gas alone).
    if (tank.isTravelGas) return TankRole.stage;

    if (tank.id == bottomTankId) return TankRole.backGas;

    // Richer than the bottom mix means a shallower MOD: a deco gas.
    if (tank.gasMix.o2 > bottomO2) return TankRole.deco;

    // Same or leaner than the bottom mix, but not the tank the bottom is
    // planned on: a stage or pony. Not the back gas, so no turn pressure.
    return TankRole.stage;
  }

  /// The cylinder the deepest leg breathes, or the first cylinder when the
  /// plan has no segments yet.
  String? _bottomTankId(domain.DivePlan plan) {
    if (plan.segments.isEmpty) {
      return plan.tanks.isEmpty ? null : plan.tanks.first.id;
    }
    final ordered = List.of(plan.segments)
      ..sort((a, b) => a.order.compareTo(b.order));
    final legs = const SegmentChain().resolve(ordered);
    ResolvedLeg? deepest;
    for (final leg in legs) {
      if (deepest == null || leg.endDepth >= deepest.endDepth) deepest = leg;
    }
    return deepest?.tankId ?? plan.tanks.first.id;
  }

  DiveTank? _tankById(domain.DivePlan plan, String? id) {
    if (id == null) return null;
    for (final tank in plan.tanks) {
      if (tank.id == id) return tank;
    }
    return null;
  }
}
