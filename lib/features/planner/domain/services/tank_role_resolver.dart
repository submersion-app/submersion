import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/segment_chain.dart';

/// Derives each cylinder's [TankRole] from the gas it carries and, on open
/// circuit, the segments that breathe it.
///
/// A plan's cylinders are described by name, size, start pressure and mix. The
/// role used to be a ninth thing the diver declared, and it could disagree
/// with the rest: a cylinder labelled Back Gas that no segment breathes, or a
/// Deco bottle leaner than the bottom mix. The plan already says which tank
/// every segment breathes and what each mix's MOD is, so the role follows.
///
/// A loop plan (CCR/SCR/PSCR) works the other way around: diluent is the
/// diver's one explicit choice, made on the tank itself, not inferred from
/// which segment breathes it. A stored role of [TankRole.diluent] is
/// honoured; everything else defaults to bailout, except a pure-O2 cylinder,
/// which is always the oxygen supply. This used to run in reverse -- a
/// cylinder was diluent only if a segment happened to reference it, bailout
/// otherwise -- so a diluent bottle the diver forgot to assign to a segment
/// silently became bailout with no indication why (issue #3135). Making
/// diluent the explicit flag means there is no silent default to fall into:
/// a cylinder is exactly what its own checkbox says.
///
/// Open circuit has no such ambiguity, and the tank editor does not even
/// offer the diluent flag there, so a stored diluent role on an OC plan is
/// left over from somewhere else and is re-derived like any other.
///
/// Nothing here is persisted. Callers apply it to their own copy of the plan
/// so the stored role remains the diver's raw input (diluent or nothing on a
/// loop plan), which keeps a derived role from later being mistaken for an
/// override.
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
    final bottomO2 = _tankById(plan, bottomTankId)?.gasMix.o2 ?? 21.0;
    final isLoop = plan.mode != domain.PlanMode.oc;

    return {
      for (final tank in plan.tanks)
        tank.id: _roleFor(
          tank,
          isLoop: isLoop,
          bottomTankId: bottomTankId,
          bottomO2: bottomO2,
        ),
    };
  }

  TankRole _roleFor(
    DiveTank tank, {
    required bool isLoop,
    required String? bottomTankId,
    required double bottomO2,
  }) {
    if (isLoop) {
      // Diluent is the diver's explicit choice, honoured only here: an
      // open-circuit plan has no such flag, so a stored diluent role there
      // is stale input and is re-derived like any other.
      if (tank.role == TankRole.diluent) return TankRole.diluent;

      // Pure O2 not explicitly marked diluent is the oxygen supply, never
      // bailout -- the one case left for the numbers to settle, since the
      // diver has no reason to tick bailout on it either.
      if (tank.gasMix.o2 >= 99.5) return TankRole.oxygenSupply;

      // Everything else carried on a loop dive is open-circuit bailout.
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
