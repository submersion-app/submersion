import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
import 'package:submersion/core/constants/gas_consumption_display.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/domain/role_consumption.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/segment_chain.dart';
import 'package:submersion/features/planner/domain/services/bailout_solver.dart';
import 'package:submersion/features/planner/domain/services/contingency_service.dart';
import 'package:submersion/features/planner/domain/services/diluent_switch_time.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/domain/services/plan_best_mix.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/domain/services/plan_gas_switches.dart';
import 'package:submersion/features/planner/domain/services/plan_state_outcome.dart';
import 'package:submersion/features/planner/domain/services/segment_rate_split.dart';
import 'package:submersion/features/planner/domain/services/tank_role_resolver.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// PlanEngine thresholds sourced from the diver's deco settings.
final planEngineConfigProvider = Provider<PlanEngineConfig>((ref) {
  return PlanEngineConfig(
    ppO2Working: ref.watch(ppO2MaxWorkingProvider),
    ppO2Deco: ref.watch(ppO2MaxDecoProvider),
    ppO2DecoBandsEnabled: ref.watch(ppO2DecoBandsEnabledProvider),
    ppO2DecoBand1: ref.watch(ppO2DecoBand1Provider),
    ppO2DecoBand2: ref.watch(ppO2DecoBand2Provider),
    ppO2DecoBand3: ref.watch(ppO2DecoBand3Provider),
    maxO2DepthEnabled: ref.watch(maxO2DepthEnabledProvider),
    maxO2DepthMeters: ref.watch(maxO2DepthMetersProvider),
    hypercapniaEnabled: ref.watch(plannerHypercapniaEnabledProvider),
    hypercapniaFactor: ref.watch(plannerHypercapniaFactorProvider),
    hypercapniaMinutes: ref.watch(plannerHypercapniaMinutesProvider),
    ccrDiluentModPpO2: ref.watch(ccrDiluentModPpO2Provider),
    ccrSetpointLow: ref.watch(ccrSetpointLowProvider),
    ccrSetpointHigh: ref.watch(ccrSetpointHighProvider),
    cnsWarningThreshold: ref.watch(cnsWarningThresholdProvider),
    o2Narcotic: ref.watch(settingsProvider.select((s) => s.o2Narcotic)),
    endLimitMeters: ref.watch(settingsProvider.select((s) => s.endLimit)),
    pscrRatio: ref.watch(pscrRatioProvider),
    cnsMethod: ref.watch(cnsCalculationMethodProvider),
    gasModel: ref.watch(gasModelProvider),
    descentRate: ref.watch(plannerDescentRateProvider),
    ascentRate: ref.watch(plannerAscentRateProvider),
    intermediateAscentRate: ref.watch(plannerIntermediateAscentRateProvider),
    shallowAscentRate: ref.watch(plannerShallowAscentRateProvider),
    finalAscentRate: ref.watch(plannerFinalAscentRateProvider),
    lastStopDepth: ref.watch(lastStopDepthProvider),
    gasSwitchStopSeconds: ref.watch(plannerGasSwitchStopSecondsProvider),
    sacBottom: ref.watch(plannerSacBottomProvider),
    sacDeco: ref.watch(plannerSacDecoProvider),
    sacStressedFactor: ref.watch(plannerSacStressedFactorProvider),
    problemSolvingMinutes: ref.watch(plannerProblemSolvingMinutesProvider),
    buddyFactor: ref.watch(plannerBuddyFactorProvider),
    bestMixEndMeters: ref.watch(plannerBestMixEndMetersProvider),
    deviationDepthDelta: ref.watch(plannerDeviationDepthDeltaProvider),
    deviationTimeMinutes: ref.watch(plannerDeviationTimeMinutesProvider),
    turnPressureRule: ref.watch(plannerTurnPressureRuleProvider),
    turnPressureFraction: ref.watch(plannerTurnPressureFractionProvider),
    airBreakPolicy: ref.watch(plannerAirBreakPolicyProvider),
    gfLow: ref.watch(gfLowProvider),
    gfHigh: ref.watch(gfHighProvider),
    reservePressure: ref.watch(plannerReservePressureProvider),
    batteryReserveFraction: ref.watch(plannerBatteryReserveFractionProvider),
    walkSpeedMps: ref.watch(plannerWalkSpeedMpsProvider),
  );
});

/// [planEngineConfigProvider] resolved against the plan being edited: each
/// Setup field's own value where the plan sets one, else the diver's
/// Settings default (issue #3552). The one place a widget reads a resolved
/// Setup value for display, so a label always shows what the engine used.
final resolvedPlanEngineConfigProvider = Provider<PlanEngineConfig>((ref) {
  return ref
      .watch(planEngineConfigProvider)
      .resolvedFor(divePlanFromState(ref.watch(divePlanNotifierProvider)));
});

/// The best bottom mix for the plan's deepest point, judged against the
/// plan's Gas options (best-mix END, O2 narcotic, bottom ppO2) over the
/// diver's Settings. The tank dialog offers it as a one-tap fill, which is
/// the only place the best-mix END takes effect (issue #3093).
///
/// A CCR plan also carries the best diluent, gated on the diver's diluent
/// MOD ppO2 instead of the bottom ceiling: the same split the PlanEngine
/// makes when it checks a CCR diluent against that limit. Other modes leave
/// [diluent] null.
///
/// Null while the plan has no depth to suggest a mix for. Auto-dispose: it
/// is only read when the dialog opens, so nothing should keep it recomputing
/// on every later plan edit.
final planBestMixProvider =
    Provider.autoDispose<
      ({double depthMeters, GasMix bottom, GasMix? diluent})?
    >((ref) {
      final state = ref.watch(divePlanNotifierProvider);
      final depth = state.maxDepth;
      if (depth <= 0) return null;
      final plan = divePlanFromState(state);
      final config = ref.watch(planEngineConfigProvider);
      GasMix mixFor({bool forDiluent = false}) => suggestBestMixForPlan(
        plan,
        config,
        depthMeters: depth,
        forDiluent: forDiluent,
      ).recommended.mix;
      return (
        depthMeters: depth,
        bottom: mixFor(),
        diluent: state.mode == domain.PlanMode.ccr
            ? mixFor(forDiluent: true)
            : null,
      );
    });

/// The canvas's single source of computed truth: the current editing state
/// run through the PlanEngine on every change (live recalc, no button).
final planOutcomeProvider = Provider<PlanOutcome>((ref) {
  final state = ref.watch(divePlanNotifierProvider);
  return computeOutcomeForState(
    state,
    config: ref.watch(planEngineConfigProvider),
  );
});

/// The current diver's logged average bottom gas RMV in L/min ("from your
/// log"): the bottom gas line of the consumption by cylinder role card, each
/// dive's rate over the time that gas was breathed (issue #771), averaged
/// over dives. Back gas, twin set and sidemount count as one (issue #3374).
/// Null when no logged dive has a bottom gas rate; a stage or deco rate is
/// not a bottom-gas rate.
final loggedAverageSacProvider = FutureProvider<double?>((ref) async {
  final repository = ref.watch(insightsRepositoryProvider);
  final diverId = ref.watch(currentDiverIdProvider);
  // Not autoDispose, so without this the logged SAC was computed once and
  // cached for the whole process lifetime (issue #974).
  ref.invalidateSelfWhen(repository.watchInsightsChanges());
  final trend = await repository.getRoleConsumptionPerDive(diverId: diverId);
  return trend.average(GasConsumptionLane.rmv, ConsumptionRoleGroup.bottomGas);
});

/// Scrub cursor position along the plan, in seconds (null = not scrubbing).
final scrubTimeProvider = StateProvider<double?>((_) => null);

/// One vertex of a canvas polyline (raw metric values; widgets convert).
class CanvasPoint {
  final double timeSeconds;
  final double depth;

  const CanvasPoint(this.timeSeconds, this.depth);
}

/// A labeled marker on the canvas (gas switch, stop annotation).
class CanvasMarker {
  final double timeSeconds;
  final double depth;
  final String label;
  final int durationSeconds;

  const CanvasMarker(
    this.timeSeconds,
    this.depth,
    this.label, {
    this.durationSeconds = 0,
  });
}

/// Everything the chart draws, precomputed from state + outcome.
class PlanCanvasSeries {
  final List<CanvasPoint> profile;
  final List<CanvasPoint> ceiling;
  final List<CanvasMarker> gasSwitches;
  final List<CanvasMarker> stopLabels;
  final double maxTimeSeconds;
  final double maxDepth;

  const PlanCanvasSeries({
    required this.profile,
    required this.ceiling,
    required this.gasSwitches,
    required this.stopLabels,
    required this.maxTimeSeconds,
    required this.maxDepth,
  });

  bool get isEmpty => profile.length < 2;

  /// Depth on the profile at [timeSeconds], linearly interpolated.
  double depthAt(double timeSeconds) {
    if (profile.isEmpty) return 0;
    if (timeSeconds <= profile.first.timeSeconds) return profile.first.depth;
    for (var i = 1; i < profile.length; i++) {
      final a = profile[i - 1];
      final b = profile[i];
      if (timeSeconds <= b.timeSeconds) {
        final span = b.timeSeconds - a.timeSeconds;
        if (span <= 0) return b.depth;
        final t = (timeSeconds - a.timeSeconds) / span;
        return a.depth + (b.depth - a.depth) * t;
      }
    }
    return profile.last.depth;
  }
}

enum ChartDisplayMode { ccr, bailout }

/// Which picture the chart draws: the live CCR plan, or -- toggled by the
/// chart's Bailout/CCR button -- the worst-case bailout picture (CCR up to
/// the worst-case instant, then the OC ascent it was sized from).
///
/// The selection belongs to the plan it was made on: watching the plan's id
/// and mode rebuilds this provider, back to [ChartDisplayMode.ccr], whenever
/// either changes. That holds with no chart mounted too, so a diver who
/// leaves the canvas, opens another CCR plan with bailout and comes back
/// never lands on a Bailout view they did not choose for it. Ordinary edits
/// to the same plan keep the selection.
final chartDisplayModeProvider = StateProvider<ChartDisplayMode>((ref) {
  ref.watch(divePlanNotifierProvider.select((s) => (s.id, s.mode)));
  return ChartDisplayMode.ccr;
});

/// Chart series for the live plan whatever the chart is showing: user
/// segments plus the computed ascent tail (travel legs + stops), ceiling
/// approximation, and markers. Converting to a dive logs this, because the
/// dive is the plan, never the bailout picture beside it.
final planLiveCanvasSeriesProvider = Provider<PlanCanvasSeries>((ref) {
  final state = ref.watch(divePlanNotifierProvider);
  final outcome = ref.watch(planOutcomeProvider);
  return buildCanvasSeries(
    plan: divePlanFromState(state),
    outcome: outcome,
    config: ref.watch(planEngineConfigProvider),
  );
});

/// The worst-case bailout picture as chart series: CCR up to the worst-case
/// instant ([BailoutOutcome.ccrRows]), then the OC ascent it was sized from
/// ([BailoutOutcome.worstCase].schedule.stops) -- built from the same two
/// unfolded sources [BailoutOutcome.ceilingTrace] continues from, not from
/// [BailoutOutcome.worstCaseRows]: a stop after the first folds its own
/// travel time into one table line (#3138's printing convention for the
/// text table), which has no separate arrival point to draw and would
/// render as a smooth diagonal between stops instead of the flat-hold-
/// then-climb steps the CCR profile itself shows for every stop.
PlanCanvasSeries buildBailoutCanvasSeries(BailoutOutcome bailout) {
  final profile = <CanvasPoint>[const CanvasPoint(0, 0)];
  final stopLabels = <CanvasMarker>[];
  var maxDepth = 0.0;
  // Each stretch of the picture on one gas, from where it starts, for the
  // switch markers (issue #4078).
  final stretches = <PlanBreathingStretch>[];
  PlanBreathingStretch stretchOf(PlanScheduleRow row, double startDepth) => (
    startSeconds: row.startRuntimeSeconds,
    startDepthMeters: startDepth,
    tankId: row.tankId,
    fO2: row.gasFO2,
    fHe: row.gasFHe,
  );

  final ccrRows = bailout.ccrRows;
  var legStartDepth = 0.0;
  for (final row in ccrRows) {
    profile.add(CanvasPoint(row.runtimeSeconds.toDouble(), row.depthMeters));
    if (row.depthMeters > maxDepth) maxDepth = row.depthMeters;
    // From the row's own START (time and depth): depthMeters is its END
    // depth, which for a depth-changing leg (a descent or ascent, not a flat
    // hold) is not where the leg, and so the switch into its gas, begins.
    // Marking it there would land the flag off the drawn line entirely.
    stretches.add(stretchOf(row, legStartDepth));
    legStartDepth = row.depthMeters;
  }

  // The OC ascent's printed travel lines (the leg up to the first stop and
  // the leg to the surface, split wherever the gas changes) carry a bailout
  // gas picked up between stops. The stops carry the rest: travel between
  // them has no line (#3138), and is still on the gas it left.
  var ocDepth = legStartDepth;
  for (final row in bailout.worstCaseRows.skip(ccrRows.length)) {
    if (row.kind != PlanScheduleRowKind.stop) {
      stretches.add(stretchOf(row, ocDepth));
    }
    ocDepth = row.depthMeters;
  }

  for (final stop in bailout.ocStops) {
    profile.add(
      CanvasPoint(stop.arrivalRuntimeSeconds.toDouble(), stop.depthMeters),
    );
    profile.add(
      CanvasPoint(
        (stop.arrivalRuntimeSeconds + stop.durationSeconds).toDouble(),
        stop.depthMeters,
      ),
    );
    if (stop.depthMeters > maxDepth) maxDepth = stop.depthMeters;
    stopLabels.add(
      CanvasMarker(
        stop.arrivalRuntimeSeconds.toDouble(),
        stop.depthMeters,
        '',
        durationSeconds: stop.durationSeconds,
      ),
    );
    stretches.add((
      startSeconds: stop.arrivalRuntimeSeconds,
      startDepthMeters: stop.depthMeters,
      tankId: stop.tankId,
      fO2: stop.gasFO2,
      fHe: stop.gasFHe,
    ));
  }

  // In dive order, the deeper first where two start together. The first
  // stretch's gas is the one the dive starts on, not a switch into it.
  stretches.sort(
    (a, b) => a.startSeconds != b.startSeconds
        ? a.startSeconds.compareTo(b.startSeconds)
        : b.startDepthMeters.compareTo(a.startDepthMeters),
  );
  final gasSwitches = <CanvasMarker>[
    for (final change in planGasChanges(stretches))
      CanvasMarker(
        change.startSeconds.toDouble(),
        change.startDepthMeters,
        GasMix(o2: change.fO2 * 100.0, he: change.fHe * 100.0).name,
      ),
  ];
  if (profile.isNotEmpty && profile.last.depth > 0) {
    // ttsSeconds is relative to the worst-case instant, not an absolute
    // runtime -- it is [BailoutPoint.ttsSeconds]'s own definition, the
    // time to surface FROM that point, so it has to be added onto where
    // that point already sits on the timeline.
    profile.add(
      CanvasPoint(
        (bailout.worstCase.runtimeSeconds +
                bailout.worstCase.schedule.ttsSeconds)
            .toDouble(),
        0,
      ),
    );
  }

  return PlanCanvasSeries(
    profile: profile,
    ceiling: [
      for (final point in bailout.ceilingTrace)
        CanvasPoint(point.$1.toDouble(), point.$2),
    ],
    gasSwitches: gasSwitches,
    stopLabels: stopLabels,
    maxTimeSeconds: profile.isEmpty ? 0.0 : profile.last.timeSeconds,
    maxDepth: maxDepth,
  );
}

/// Builds the chart series for any (plan, outcome) pair — the live plan or a
/// contingency variant (ghost overlay). [outcome] is [plan]'s own computed
/// schedule -- the same instance a caller like [PlanEngine.compute] already
/// has at hand -- recomputing it here would be redundant.
PlanCanvasSeries buildCanvasSeries({
  required domain.DivePlan plan,
  required PlanOutcome outcome,
  required PlanEngineConfig config,
}) {
  // Cylinder roles feed [withDiluentSwitchTime]'s diluent-switch detection,
  // same as PlanEngine.compute and BailoutSolver.solve; a caller passing a
  // plan with raw, unresolved roles must not read a different authored
  // profile here than the engine computed [outcome] from.
  final resolvedPlan = const TankRoleResolver().apply(plan);
  // Resolved against this plan (issue #3552), the same as PlanEngine.compute
  // and BailoutSolver.solve, so an unset Deco/Rates field expands the same
  // segments here as it did for [outcome].
  final resolvedConfig = config.resolvedFor(resolvedPlan);
  final sorted = withDiluentSwitchTime(
    expandRateSplitSegments(
      List<PlanSegment>.from(resolvedPlan.segments)
        ..sort((a, b) => a.order.compareTo(b.order)),
      resolvedPlan,
      descentRate: resolvedConfig.descentRate,
      ascentRate: resolvedConfig.ascentRate,
    ),
    resolvedPlan,
    gasSwitchStopSeconds: resolvedConfig.gasSwitchStopSeconds,
  );

  final profile = <CanvasPoint>[];
  var t = 0.0;
  // Legs are contiguous by construction now, so the old guard against a
  // depth discontinuity (which used to emit an extra point for a jump the
  // engine integrated as an instant depth change) has nothing to catch: only
  // the very first leg needs its start boundary.
  for (final leg in const SegmentChain().resolve(sorted)) {
    if (profile.isEmpty) profile.add(CanvasPoint(t, leg.startDepth));
    t += leg.durationSeconds;
    profile.add(CanvasPoint(t, leg.endDepth));
  }

  // Computed ascent tail: travel to each stop, hold, then surface.
  final stopLabels = <CanvasMarker>[];
  for (final stop in outcome.stops) {
    profile.add(
      CanvasPoint(stop.arrivalRuntimeSeconds.toDouble(), stop.depthMeters),
    );
    profile.add(
      CanvasPoint(
        (stop.arrivalRuntimeSeconds + stop.durationSeconds).toDouble(),
        stop.depthMeters,
      ),
    );
    stopLabels.add(
      CanvasMarker(
        stop.arrivalRuntimeSeconds.toDouble(),
        stop.depthMeters,
        '',
        durationSeconds: stop.durationSeconds,
      ),
    );
  }
  if (profile.isNotEmpty && profile.last.depth > 0) {
    profile.add(CanvasPoint(outcome.runtimeSeconds.toDouble(), 0));
  }

  // Every switch the table lists, where it happens (issue #4078): in the
  // authored legs, on the leg up to the first stop, partway up travel folded
  // into a stop, and at a stop. Read from the schedule the log's switches
  // are written from, rather than from the stops, which miss a gas breathed
  // only on the way between them.
  //
  // A loop's computed ascent reads its supply gas on every line, never the
  // fraction drifting with depth that the deco engine keeps (#3131), so it
  // shows no switch the diver does not make.
  final gasSwitches = <CanvasMarker>[
    for (final change in planGasChanges(
      planBreathingStretches(outcome.schedule, planTanks: resolvedPlan.tanks),
    ))
      CanvasMarker(
        change.startSeconds.toDouble(),
        change.startDepthMeters,
        GasMix(o2: change.fO2 * 100.0, he: change.fHe * 100.0).name,
      ),
  ];

  // The finely-sampled ceiling curve (see PlanEngine._ceilingTrace): a
  // continuous rise as tissues load and fall as each stop clears, rather
  // than a staircase pinned to the stops' own depths.
  final ceiling = <CanvasPoint>[
    for (final point in outcome.ceilingTrace)
      CanvasPoint(point.$1.toDouble(), point.$2),
  ];

  return PlanCanvasSeries(
    profile: profile,
    ceiling: ceiling,
    gasSwitches: gasSwitches,
    stopLabels: stopLabels,
    maxTimeSeconds: outcome.runtimeSeconds.toDouble(),
    maxDepth: outcome.maxDepth,
  );
}

/// Whether the results sheet's contingency section is expanded. The full
/// deviation + lost-gas tables (3 engine runs + one per deco/stage tank) are
/// only computed while this is true, so a collapsed sheet costs nothing.
final contingenciesExpandedProvider = StateProvider<bool>((_) => false);

/// Which per-contingency mini tables (keyed by deviation key or tank id) are
/// collapsed within the Contingencies section; everything starts expanded.
final collapsedContingencyKeysProvider = StateProvider<Set<String>>(
  (_) => const {},
);

/// Which deviation is ghosted on the chart ('deeper'|'longer'|'both'; null =
/// none). Mutually exclusive with [selectedLostGasTankIdProvider] -- only one
/// contingency can be previewed at a time.
final selectedDeviationProvider = StateProvider<String?>((_) => null);

/// Which carried cylinder is being marked lost and previewed; null = none.
/// Mutually exclusive with [selectedDeviationProvider].
final selectedLostGasTankIdProvider = StateProvider<String?>((_) => null);

/// The variant plan + outcome for whichever contingency is currently
/// selected (a deviation or a lost-gas tank); null when neither is selected,
/// meaning every consumer should fall back to the live [planOutcomeProvider].
/// Losing a deco/stage/travel gas changes the whole deco schedule -- not just
/// the chart ghost -- so this is the single source both the ghost series and
/// the headline stats read from, keeping them in sync and to a single engine
/// run per selection.
///
/// It is also null when a selection has gone stale -- the tank was removed,
/// stopped being losable (its role changed, or its travel-gas flag was
/// cleared), or the deviation cannot be applied -- so consumers must gate on
/// this rather than on the raw selection providers, which still hold the id.
/// [lostTank] is the cylinder being dropped, non-null only for a lost-gas
/// selection, so a label can name it without re-deriving whether the
/// selection is still valid.
final selectedContingencyProvider =
    Provider<
      ({domain.DivePlan plan, PlanOutcome outcome, DiveTank? lostTank})?
    >((ref) {
      final deviationKey = ref.watch(selectedDeviationProvider);
      final lostGasTankId = ref.watch(selectedLostGasTankIdProvider);
      if (deviationKey == null && lostGasTankId == null) return null;

      final state = ref.watch(divePlanNotifierProvider);
      final config = ref.watch(planEngineConfigProvider);
      final service = ContingencyService(config: config);
      final plan = divePlanFromState(state);
      final startState = startStateForPlan(state, config: config);

      if (deviationKey != null) {
        final deviation = service.deviationFor(
          plan,
          deviationKey,
          startState: startState,
        );
        if (deviation == null) return null;
        return (
          plan: deviation.plan,
          outcome: deviation.outcome,
          lostTank: null,
        );
      }
      final lost = service.lostGasFor(
        plan,
        lostGasTankId!,
        startState: startState,
      );
      if (lost == null) return null;
      return (plan: lost.plan, outcome: lost.outcome, lostTank: lost.tank);
    });

/// Chart series for the selected contingency, drawn as a ghost overlay.
final contingencyGhostSeriesProvider = Provider<PlanCanvasSeries?>((ref) {
  final preview = ref.watch(selectedContingencyProvider);
  if (preview == null) return null;
  return buildCanvasSeries(
    plan: preview.plan,
    outcome: preview.outcome,
    config: ref.watch(planEngineConfigProvider),
  );
});

/// The outcome to display everywhere the headline stats (runtime, TTS/NDL,
/// deco time, CNS, issues) are shown: the selected contingency's outcome when
/// one is being previewed, else the live plan's outcome.
final activePlanOutcomeProvider = Provider<PlanOutcome>((ref) {
  // What the series raises about the dive (its interval, the tissues it
  // starts with) holds for a previewed contingency of it too.
  final seriesIssues = ref.watch(selectedSeriesIssuesProvider);
  final preview = ref.watch(selectedContingencyProvider)?.outcome;
  final outcome = preview ?? ref.watch<PlanOutcome>(planOutcomeProvider);
  return outcome.withIssues(seriesIssues);
});

/// The logged dive a "What if..." plan was converted from, plus its profile:
/// what the "vs. original dive" compare strip and chart overlay need. Null
/// when the plan has no `sourceDiveId` (an ordinary plan, not opened from a
/// dive) or the dive could not be loaded.
final sourceDiveForPlanProvider = FutureProvider<Dive?>((ref) async {
  final sourceDiveId = ref.watch(
    divePlanNotifierProvider.select((s) => s.sourceDiveId),
  );
  if (sourceDiveId == null) return null;
  return ref.watch(diveProvider(sourceDiveId).future);
});

/// Profile samples for [sourceDiveForPlanProvider]'s dive, for the chart
/// overlay. Empty when there is no source dive.
final sourceDiveProfileForPlanProvider = FutureProvider<List<DiveProfilePoint>>(
  (ref) async {
    final dive = await ref.watch(sourceDiveForPlanProvider.future);
    if (dive == null) return const [];
    return ref.watch(diveProfileProvider(dive.id).future);
  },
);

/// Whether the source dive's actual profile is drawn over the plan chart.
/// Only meaningful while the plan has a `sourceDiveId`.
final showSourceDiveOverlayProvider = StateProvider<bool>((ref) => true);

/// The source dive's logged profile as a chart series, for the dashed
/// "actual" overlay on the plan chart. Null when there is no source dive,
/// the profile has not loaded yet, or the diver hid the overlay.
final sourceDiveOverlaySeriesProvider = Provider<PlanCanvasSeries?>((ref) {
  if (!ref.watch(showSourceDiveOverlayProvider)) return null;
  final points = ref.watch(sourceDiveProfileForPlanProvider).valueOrNull;
  if (points == null || points.length < 2) return null;
  final sorted = [...points]
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  var maxDepth = 0.0;
  for (final p in sorted) {
    if (p.depth > maxDepth) maxDepth = p.depth;
  }
  return PlanCanvasSeries(
    profile: [
      for (final p in sorted) CanvasPoint(p.timestamp.toDouble(), p.depth),
    ],
    ceiling: const [],
    gasSwitches: const [],
    stopLabels: const [],
    maxTimeSeconds: sorted.last.timestamp.toDouble(),
    maxDepth: maxDepth,
  );
});
