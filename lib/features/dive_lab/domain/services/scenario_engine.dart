import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';
import 'package:submersion/core/deco/o2_toxicity_calculator.dart';
import 'package:submersion/features/dive_lab/domain/entities/branch_state.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_consumption.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_outcome.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_request.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_settings.dart';
import 'package:submersion/features/dive_lab/domain/services/branch_state_builder.dart';
import 'package:submersion/features/dive_lab/domain/services/consumption_pass.dart';
import 'package:submersion/features/dive_lab/domain/services/counterfactual_profile_synthesizer.dart';
import 'package:submersion/features/dive_lab/domain/services/remaining_bottom_compiler.dart';
import 'package:submersion/features/dive_lab/domain/services/replay_schedule_rewriter.dart';
import 'package:submersion/features/dive_lab/domain/services/scenario_delta_builder.dart';
import 'package:submersion/features/dive_lab/domain/services/scenario_plan_compiler.dart';
import 'package:submersion/features/dive_lab/domain/services/tank_schedule.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

/// Top-level entry for `compute()`: a plain function crosses the isolate
/// boundary where a method tear-off would not.
ScenarioOutcome runScenarioEngine(ScenarioRequest request) =>
    const ScenarioEngine().run(request);

/// Replay and re-plan pipelines from the spec, composed from
/// ProfileAnalysisService (both timelines) and PlanEngine (re-plan).
class ScenarioEngine {
  const ScenarioEngine();

  ScenarioOutcome run(ScenarioRequest request) {
    final scenario = request.scenario;
    final interventions = scenario.interventions;
    // The actual timeline is always the dive as logged under its effective
    // gradient factors; a changeGf intervention changes only the
    // counterfactual (and the branch state it starts from).
    final baseSettings = request.settings;
    var settings = baseSettings;
    for (final i in interventions) {
      if (i is ChangeGfIntervention) {
        settings = settings.withGf(low: i.gfLow, high: i.gfHigh);
      }
    }
    final actualService = baseSettings.buildAnalysisService();
    final service = settings == baseSettings
        ? actualService
        : settings.buildAnalysisService();
    final flags = <ScenarioFlag>[];
    final isOc = request.diveMode == DiveMode.oc;

    final schedule = TankSchedule.fromDive(
      tanks: request.tanks,
      switches: request.gasSwitches,
      originTimestamp: request.timestamps.first,
    );
    List<ProfileGasSegment> actualGas;
    if (isOc) {
      actualGas = schedule.toGasSegments();
    } else {
      final loop = request.loopGasSegments;
      if (loop == null || loop.isEmpty) {
        flags.add(const ScenarioFlag(ScenarioFlagKind.loopGasMissing));
        actualGas = schedule.toGasSegments();
      } else {
        actualGas = loop;
      }
    }
    final primary =
        schedule.tankAt(request.timestamps.first)?.gasMix ?? const GasMix();

    ProfileAnalysis analyze({
      required List<double> depths,
      required List<int> timestamps,
      required List<ProfileGasSegment> gas,
      required AscentGasPlan? ascent,
      List<double>? rebreatherPpO2Curve,
      ProfileAnalysisService? using,
    }) => (using ?? service).analyze(
      diveId: request.diveId,
      depths: depths,
      timestamps: timestamps,
      o2Fraction: primary.o2 / 100.0,
      heFraction: primary.he / 100.0,
      startCns: request.startCns,
      diveMode: request.diveMode,
      setpointHigh: request.setpointHigh,
      setpointLow: request.setpointLow,
      startCompartments: request.startCompartments,
      startOtu: request.startOtu,
      gasSegments: gas,
      ascentGasPlan: ascent,
      rebreatherPpO2Curve: rebreatherPpO2Curve,
    );

    final actual = analyze(
      depths: request.depths,
      timestamps: request.timestamps,
      gas: actualGas,
      ascent: isOc ? _ascentPlan(request.tanks, settings) : null,
      rebreatherPpO2Curve: request.rebreatherPpO2Curve,
      using: actualService,
    );
    // Under a changed GF the branch state (its GF-low anchor in particular)
    // is re-derived under the counterfactual settings; tissues are the same.
    final branchAnalysis = identical(service, actualService)
        ? actual
        : analyze(
            depths: request.depths,
            timestamps: request.timestamps,
            gas: actualGas,
            ascent: isOc ? _ascentPlan(request.tanks, settings) : null,
            rebreatherPpO2Curve: request.rebreatherPpO2Curve,
          );

    final branchIndex = branchIndexFor(
      request.timestamps,
      scenario.branchSeconds,
    );
    final branch = buildBranchState(
      request: request,
      actual: branchAnalysis,
      schedule: schedule,
      branchIndex: branchIndex,
    );
    if (branch.sacSource != SacSource.measured) {
      flags.add(const ScenarioFlag(ScenarioFlagKind.sacEstimated));
    }
    for (final p in branch.tankPressures) {
      if (p.source == PressureSource.estimated) {
        flags.add(
          ScenarioFlag(ScenarioFlagKind.pressureEstimated, tankId: p.tankId),
        );
      } else if (p.source == PressureSource.unknown) {
        flags.add(
          ScenarioFlag(ScenarioFlagKind.pressureUnknown, tankId: p.tankId),
        );
      }
    }
    for (final t in request.tanks) {
      if (t.volume == null) {
        flags.add(
          ScenarioFlag(ScenarioFlagKind.tankVolumeAssumed, tankId: t.id),
        );
      }
    }

    final actualConsumption = _actualConsumption(
      request,
      schedule,
      branch,
      settings,
    );
    final mode = scenario.effectiveMode;
    final branchT = branch.runtimeSeconds;
    final branchPressures = {
      for (final p in branch.tankPressures) p.tankId: p.pressureBar,
    };

    if (mode == ScenarioMode.replay) {
      final cfSchedule = rewriteScheduleForReplay(
        actual: schedule,
        interventions: interventions,
        branchTimestamp: branchT,
        timestamps: request.timestamps,
        depths: request.depths,
        maxPpO2: settings.ppO2Deco,
      );
      final cfGas = isOc ? cfSchedule.toGasSegments() : actualGas;
      final counterfactual = analyze(
        depths: request.depths,
        timestamps: request.timestamps,
        gas: cfGas,
        ascent: isOc ? _ascentPlan(cfSchedule.tanks, settings) : null,
        rebreatherPpO2Curve: request.rebreatherPpO2Curve,
      );
      final multiplier = _replayMultiplier(interventions, settings);
      final cfStart = {
        for (final t in cfSchedule.tanks)
          t.id: branchPressures.containsKey(t.id)
              ? branchPressures[t.id]
              : t.startPressure,
      };
      // An unchanged schedule at the recorded SAC is the actual timeline:
      // report the measured figures rather than a re-simulation of them.
      final cfConsumption = identical(cfSchedule, schedule) && multiplier == 1.0
          ? actualConsumption
          : simulateConsumption(
              timestamps: request.timestamps,
              depths: request.depths,
              schedule: cfSchedule,
              startPressures: cfStart,
              sacLpmAt: (_) => branch.sacLitersPerMin * multiplier,
              environment: settings.environment,
              gasModel: settings.gasModel,
              reservePressureBar: settings.reservePressureBar,
              fromIndex: branchIndex,
            );
      final consumption = ScenarioConsumption(
        actual: actualConsumption,
        counterfactual: cfConsumption,
        reservePressureBar: settings.reservePressureBar,
      );
      final deltas = buildDeltas(
        actual: actual,
        counterfactual: counterfactual,
        actualDepths: request.depths,
        counterfactualDepths: request.depths,
        actualTimestamps: request.timestamps,
        counterfactualTimestamps: request.timestamps,
        branchIndex: branchIndex,
        consumption: consumption,
      );
      return ScenarioOutcome(
        branch: branch,
        mode: mode,
        actual: actual,
        counterfactual: counterfactual,
        counterfactualDepths: request.depths,
        counterfactualTimestamps: request.timestamps,
        counterfactualGasSegments: cfGas,
        planOutcome: null,
        compiledPlan: null,
        consumption: consumption,
        deltas: deltas,
        verdictDeltas: selectVerdictDeltas(deltas),
        flags: flags,
      );
    }

    // Re-plan.
    final bottomEnd = finalAscentStartIndex(
      depths: request.depths,
      timestamps: request.timestamps,
      ndlCurve: actual.ndlCurve,
      decoStopCurve: actual.decoStopCurve,
    );
    if (bottomEnd == null || bottomEnd <= branchIndex) {
      flags.add(const ScenarioFlag(ScenarioFlagKind.noBottomRemaining));
    }
    final forcedTankId = forcedTankIdFor(
      interventions: interventions,
      tanks: request.tanks,
      branchDepth: branch.depthMeters,
      maxPpO2: settings.ppO2Deco,
    );
    var shift = 0;
    var ascendNow = scenario.abortsAtBranch;
    for (final i in interventions) {
      if (i is ShiftAscentIntervention) shift = i.deltaSeconds;
      if (i is AscendNowIntervention) ascendNow = true;
    }
    // A forced hypothetical tank must be known to the schedule the segments
    // are compiled against.
    var segmentSchedule = schedule;
    for (final i in interventions) {
      final ref = switch (i) {
        SwitchGasIntervention(:final tank) => tank,
        BailOutIntervention(:final tank) => tank,
        _ => null,
      };
      if (ref is HypotheticalTankRef) {
        segmentSchedule = segmentSchedule.withTanks([
          ...segmentSchedule.tanks,
          hypotheticalTank(ref),
        ]);
      }
    }
    final remaining = compileRemainingBottom(
      depths: request.depths,
      timestamps: request.timestamps,
      branchIndex: branchIndex,
      bottomEndIndex: bottomEnd,
      schedule: segmentSchedule,
      forcedTankId: forcedTankId,
      shiftSeconds: shift,
      ascendNow: ascendNow,
    );
    final compiled = compileScenarioPlan(
      request: request,
      branch: branch,
      settings: settings,
      interventions: interventions,
      remainingBottom: remaining,
    );
    final plan = compiled.plan;
    final engine = PlanEngine(config: settings.engineConfig);
    final planOutcome = engine.compute(plan, startState: branch.tissueState);
    if (!planOutcome.isDiveable) {
      flags.add(const ScenarioFlag(ScenarioFlagKind.replanNotCompletable));
    }
    final isLoop =
        plan.mode == domain.PlanMode.ccr || plan.mode == domain.PlanMode.scr;
    final remainder = synthesizeRemainder(
      plan: plan,
      outcome: planOutcome,
      startTimestamp: branchT,
      startDepth: branch.depthMeters,
      ascentPlan: engine.ascentPlanFor(plan.tanks),
      loop: isLoop
          ? LoopSetpoints(
              low: plan.effectiveSetpointLow,
              high: plan.effectiveSetpointHigh,
              switchDepth: plan.effectiveSetpointSwitchDepth,
              diluent: plan.segments.isEmpty
                  ? const GasMix()
                  : plan.segments.last.gasMix,
            )
          : null,
      extraLastStopSeconds: compiled.extraLastStopSeconds,
    );
    final spliced = spliceCounterfactual(
      actualTimestamps: request.timestamps,
      actualDepths: request.depths,
      actualGasSegments: actualGas,
      branchIndex: branchIndex,
      remainder: remainder,
    );
    List<double>? cfPpO2;
    final measured = request.rebreatherPpO2Curve;
    if (!isOc && measured != null) {
      cfPpO2 = [
        for (var i = 0; i < spliced.depths.length; i++)
          if (i <= branchIndex && i < measured.length)
            measured[i]
          else if (isLoop)
            (spliced.depths[i] > plan.effectiveSetpointSwitchDepth
                ? plan.effectiveSetpointHigh
                : plan.effectiveSetpointLow)
          else
            _ocPpO2(spliced, i, settings),
      ];
    }
    final counterfactual = analyze(
      depths: spliced.depths,
      timestamps: spliced.timestamps,
      gas: spliced.gasSegments,
      ascent: plan.mode == domain.PlanMode.oc
          ? engine.ascentPlanFor(plan.tanks)
          : null,
      rebreatherPpO2Curve: cfPpO2,
    );

    final cfSchedule = TankSchedule(
      intervals: TankSchedule.collapseIntervals([
        ...schedule.intervals.where((i) => i.startTimestamp < branchT),
        for (final s in remainder.tankSwitches)
          TankInterval(startTimestamp: s.timestamp, tankId: s.tankId),
      ]),
      tanks: plan.tanks,
    );
    final cfStart = {
      for (final t in plan.tanks)
        t.id: branchPressures.containsKey(t.id)
            ? branchPressures[t.id]
            : t.startPressure,
    };
    final cfConsumption = simulateConsumption(
      timestamps: spliced.timestamps,
      depths: spliced.depths,
      schedule: cfSchedule,
      startPressures: cfStart,
      sacLpmAt: (i) => spliced.timestamps[i] <= remainder.bottomEndTimestamp
          ? plan.sacBottom
          : plan.sacDecoEffective,
      environment: settings.environment,
      gasModel: settings.gasModel,
      reservePressureBar: settings.reservePressureBar,
      fromIndex: branchIndex,
    );
    final consumption = ScenarioConsumption(
      actual: actualConsumption,
      counterfactual: cfConsumption,
      reservePressureBar: settings.reservePressureBar,
    );
    String? backId;
    for (final t in request.tanks) {
      if (t.role == TankRole.backGas) {
        backId = t.id;
        break;
      }
    }
    final deltas = buildDeltas(
      actual: actual,
      counterfactual: counterfactual,
      actualDepths: request.depths,
      counterfactualDepths: spliced.depths,
      actualTimestamps: request.timestamps,
      counterfactualTimestamps: spliced.timestamps,
      branchIndex: branchIndex,
      consumption: consumption,
      planOutcome: planOutcome,
      branchBackGasPressureBar: backId == null
          ? null
          : branch.pressureFor(backId),
    );
    return ScenarioOutcome(
      branch: branch,
      mode: mode,
      actual: actual,
      counterfactual: counterfactual,
      counterfactualDepths: spliced.depths,
      counterfactualTimestamps: spliced.timestamps,
      counterfactualGasSegments: spliced.gasSegments,
      planOutcome: planOutcome,
      compiledPlan: plan,
      consumption: consumption,
      deltas: deltas,
      verdictDeltas: selectVerdictDeltas(deltas),
      flags: flags,
    );
  }

  double _ocPpO2(SplicedProfile spliced, int i, ScenarioSettings settings) {
    var fN2 = spliced.gasSegments.first.fN2;
    var fHe = spliced.gasSegments.first.fHe;
    for (final g in spliced.gasSegments) {
      if (g.startTimestamp <= spliced.timestamps[i]) {
        fN2 = g.fN2;
        fHe = g.fHe;
      }
    }
    return settings.environment.pressureAtDepth(spliced.depths[i]) *
        (1.0 - fN2 - fHe);
  }

  double _replayMultiplier(
    List<ScenarioIntervention> interventions,
    ScenarioSettings settings,
  ) {
    var m = 1.0;
    for (final i in interventions) {
      if (i is ShareGasIntervention) {
        m = 2.5 * (i.buddyFactor ?? settings.buddyFactor);
      }
      if (i is BailOutIntervention && m == 1.0) m = 2.5;
    }
    return m;
  }

  AscentGasPlan _ascentPlan(List<DiveTank> tanks, ScenarioSettings settings) {
    if (tanks.isEmpty) return FixedAscentGas(fN2: 0.7902);
    final seen = <String>{};
    final gases = <AvailableGas>[];
    for (final t in tanks) {
      final fO2 = t.gasMix.o2 / 100.0;
      final fHe = t.gasMix.he / 100.0;
      final key = '${fO2.toStringAsFixed(4)}_${fHe.toStringAsFixed(4)}';
      if (!seen.add(key)) continue;
      gases.add(
        AvailableGas(
          fN2: (1.0 - fO2 - fHe).clamp(0.0, 1.0),
          fHe: fHe,
          maxPpO2Mod: O2ToxicityCalculator.calculateMod(
            fO2,
            maxPpO2: settings.ppO2Deco,
          ),
        ),
      );
    }
    return OptimalOcAscentGas(gases: gases, maxPpO2: settings.ppO2Deco);
  }

  /// Actual-timeline consumption: simulated from the start on the recorded
  /// schedule at the branch SAC; a tank with a recorded end pressure reports
  /// it (measured) instead of the simulated value.
  List<TankConsumption> _actualConsumption(
    ScenarioRequest request,
    TankSchedule schedule,
    BranchState branch,
    ScenarioSettings settings,
  ) {
    final simulated = simulateConsumption(
      timestamps: request.timestamps,
      depths: request.depths,
      schedule: schedule,
      startPressures: {for (final t in request.tanks) t.id: t.startPressure},
      sacLpmAt: (_) => branch.sacLitersPerMin,
      environment: settings.environment,
      gasModel: settings.gasModel,
      reservePressureBar: settings.reservePressureBar,
    );
    return [
      for (final s in simulated)
        () {
          final tank = schedule.tankById(s.tankId);
          final series = request.tankPressures[s.tankId];
          final measuredEnd = series != null && series.isNotEmpty
              ? series.last.pressureBar
              : tank?.endPressure;
          return measuredEnd == null
              ? s
              : TankConsumption(
                  tankId: s.tankId,
                  startPressureBar: s.startPressureBar,
                  endPressureBar: measuredEnd,
                  litersUsed: s.litersUsed,
                  reserveReachedAtSeconds: s.reserveReachedAtSeconds,
                  emptyAtSeconds: s.emptyAtSeconds,
                  source: PressureSource.measured,
                );
        }(),
    ];
  }
}
