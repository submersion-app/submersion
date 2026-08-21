import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/domain/entities/branch_state.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_request.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_settings.dart';
import 'package:submersion/features/dive_lab/domain/services/replay_schedule_rewriter.dart';
import 'package:submersion/features/dive_lab/domain/services/tank_schedule.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;

/// The planner input the re-plan pipeline feeds to PlanEngine.
class CompiledScenario {
  const CompiledScenario({
    required this.plan,
    required this.forcedTankId,
    required this.extraLastStopSeconds,
  });

  final domain.DivePlan plan;

  /// The tank the remaining bottom breathes when an intervention switches
  /// gas at the branch (switchGas, bailOut); null = the recorded schedule.
  final String? forcedTankId;

  /// Seconds the synthesizer appends to the final stop (ascentPolicy).
  final int extraLastStopSeconds;
}

/// The tank the remaining bottom must breathe for [interventions], resolved
/// before compiling segments: the switchGas tank, or the best bailout tank
/// at the branch depth. Null when the recorded schedule stands.
String? forcedTankIdFor({
  required List<ScenarioIntervention> interventions,
  required List<DiveTank> tanks,
  required double branchDepth,
  required double maxPpO2,
}) {
  for (final i in interventions) {
    if (i is SwitchGasIntervention) return i.tank.tankId;
  }
  for (final i in interventions) {
    if (i is BailOutIntervention) {
      final pool = bailoutPool(i, tanks);
      return bestTankForDepth(pool, branchDepth, maxPpO2: maxPpO2)?.id;
    }
  }
  return null;
}

CompiledScenario compileScenarioPlan({
  required ScenarioRequest request,
  required BranchState branch,
  required ScenarioSettings settings,
  required List<ScenarioIntervention> interventions,
  required List<PlanSegment> remainingBottom,
}) {
  final scenario = request.scenario;

  DiveTank atBranch(DiveTank t) {
    final p = branch.pressureFor(t.id);
    return p != null ? t.copyWith(startPressure: p) : t;
  }

  var tanks = <DiveTank>[for (final t in request.tanks) atBranch(t)];
  var mode = switch (request.diveMode) {
    DiveMode.ccr => domain.PlanMode.ccr,
    DiveMode.scr => domain.PlanMode.scr,
    DiveMode.oc || DiveMode.gauge => domain.PlanMode.oc,
  };
  var sacBottom = branch.sacLitersPerMin;
  double? sacDeco;
  String? forcedTankId;
  var ascentRate = settings.ascentRate;
  var lastStopDepth = settings.lastStopDepth;
  var gasSwitchStopSeconds = settings.gasSwitchStopSeconds;
  var extraLastStopSeconds = 0;

  for (final i in interventions) {
    switch (i) {
      case LoseTankIntervention(:final tankId):
        tanks = tanks.where((t) => t.id != tankId).toList();
      case SwitchGasIntervention(:final tank):
        switch (tank) {
          case ExistingTankRef(:final tankId):
            tanks = [
              for (final t in tanks)
                t.id == tankId
                    ? t.copyWith(decoSwitchDepth: branch.depthMeters)
                    : t,
            ];
            forcedTankId = tankId;
          case HypotheticalTankRef():
            tanks = [
              ...tanks,
              hypotheticalTank(
                tank,
              ).copyWith(decoSwitchDepth: branch.depthMeters),
            ];
            forcedTankId = tank.tankId;
        }
      case ShareGasIntervention(:final buddyFactor):
        final stressed =
            branch.sacLitersPerMin *
            2.5 *
            (buddyFactor ?? settings.buddyFactor);
        sacBottom = stressed;
        sacDeco = stressed;
      case BailOutIntervention():
        tanks = [for (final t in bailoutPool(i, request.tanks)) atBranch(t)];
        mode = domain.PlanMode.oc;
        final stressed = branch.sacLitersPerMin * 2.5;
        sacBottom = stressed;
        sacDeco = stressed;
        forcedTankId = bestTankForDepth(
          tanks,
          branch.depthMeters,
          maxPpO2: settings.ppO2Deco,
        )?.id;
      case AscentPolicyIntervention(
        ascentRate: final rate,
        lastStopDepth: final lastStop,
        extraLastStopSeconds: final extra,
        gasSwitchStopSeconds: final switchStop,
      ):
        if (rate != null && rate > 0) ascentRate = rate;
        if (lastStop != null && lastStop > 0) lastStopDepth = lastStop;
        if (switchStop != null && switchStop >= 0) {
          gasSwitchStopSeconds = switchStop;
        }
        if (extra != null && extra > 0) extraLastStopSeconds = extra;
      case ShiftAscentIntervention() ||
          AscendNowIntervention() ||
          ChangeGfIntervention():
        break; // applied elsewhere (segments / settings)
    }
  }

  final plan = domain.DivePlan(
    id: 'lab-${scenario.id}',
    name: scenario.name,
    createdAt: scenario.createdAt,
    updatedAt: scenario.createdAt,
    mode: mode,
    altitude: settings.altitudeMeters,
    waterType: settings.waterType,
    gfLow: settings.gfLowPercent,
    gfHigh: settings.gfHighPercent,
    descentRate: settings.descentRate,
    ascentRate: ascentRate,
    lastStopDepth: lastStopDepth,
    gasSwitchStopSeconds: gasSwitchStopSeconds,
    airBreaks: settings.airBreaks,
    sacBottom: sacBottom,
    sacDeco: sacDeco,
    reservePressure: settings.reservePressureBar,
    sourceDiveId: request.diveId,
    setpointLow: request.setpointLow,
    setpointHigh: request.setpointHigh,
    segments: remainingBottom,
    tanks: tanks,
  );
  return CompiledScenario(
    plan: plan,
    forcedTankId: forcedTankId,
    extraLastStopSeconds: extraLastStopSeconds,
  );
}
