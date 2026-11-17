import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/scr_calculator.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/diluent_switch_time.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The gas a semi-closed plan's loop is fed from (issue #4660): the first
/// segment breathed on the loop, else the diluent cylinder, else the first
/// cylinder, else air. The engine treats each loop segment's gas as its
/// supply, so a plan with segments shows what its first loop leg breathes.
GasMix loopSupplyGas(domain.DivePlan plan) {
  for (final segment in plan.segments) {
    if (modeFor(plan, segment) != domain.PlanMode.oc) return segment.gasMix;
  }
  for (final tank in plan.tanks) {
    if (tank.role == TankRole.diluent) return tank.gasMix;
  }
  if (plan.tanks.isNotEmpty) return plan.tanks.first.gasMix;
  return const GasMix(o2: 21);
}

/// One line beside the SCR inputs (issue #4660): the steady-state loop O2 a
/// constant mass flow loop gives on [supply] at [vo2Lpm], at rest and at hard
/// work, so a diver can check it against their unit's documentation. A VO2
/// the flow cannot sustain reads as "flow too low" in its slot.
class LoopFlowSummary extends StatelessWidget {
  const LoopFlowSummary({
    super.key,
    required this.injectionRateLpm,
    required this.vo2Lpm,
    required this.supply,
  });

  final double injectionRateLpm;
  final double vo2Lpm;
  final GasMix supply;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String at(double vo2) {
      final fO2 = ScrCalculator.calculateCmfSteadyStateFo2(
        injectionRateLpm: injectionRateLpm,
        supplyO2Percent: supply.o2,
        vo2: vo2,
      );
      return fO2 == null
          ? l10n.plannerCanvas_scr_flowTooLow
          : '${(fO2 * 100).round()}%';
    }

    return Text(
      l10n.plannerCanvas_scr_loopSummary(
        supply.name,
        at(vo2Lpm),
        at(ScrCalculator.restingVo2),
        at(ScrCalculator.hardWorkVo2),
      ),
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}
