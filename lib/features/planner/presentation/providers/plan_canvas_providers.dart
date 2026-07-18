import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/bailout_solver.dart';
import 'package:submersion/features/planner/domain/services/contingency_service.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/domain/services/range_table_service.dart';
import 'package:submersion/features/planner/domain/services/tissue_seed.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';

/// PlanEngine thresholds sourced from the diver's deco settings.
final planEngineConfigProvider = Provider<PlanEngineConfig>((ref) {
  return PlanEngineConfig(
    ppO2Working: ref.watch(ppO2MaxWorkingProvider),
    ppO2Deco: ref.watch(ppO2MaxDecoProvider),
    cnsWarningThreshold: ref.watch(cnsWarningThresholdProvider),
    o2Narcotic: ref.watch(settingsProvider).o2Narcotic,
    cnsMethod: ref.watch(cnsCalculationMethodProvider),
  );
});

/// The canvas's single source of computed truth: the current editing state
/// run through the PlanEngine on every change (live recalc, no button).
final planOutcomeProvider = Provider<PlanOutcome>((ref) {
  final state = ref.watch(divePlanNotifierProvider);
  final engine = PlanEngine(config: ref.watch(planEngineConfigProvider));
  final startState = seededTissueState(
    compartments: state.initialTissueState,
    surfaceInterval: state.surfaceInterval,
    gfLow: state.gfLow / 100.0,
    gfHigh: state.gfHigh / 100.0,
    // Match the engine: altitude <= 0 is unset (legacy 1.0 bar), so the seed
    // is off-gassed at the same surface pressure the plan is computed at.
    environment: DiveEnvironment.forConditions(
      altitudeMeters: (state.altitude ?? 0) > 0 ? state.altitude : null,
    ),
  );
  return engine.compute(divePlanFromState(state), startState: startState);
});

/// The diver's logged average back-gas SAC in L/min ("from your log");
/// null when no logged dive carries enough tank data to compute one.
final loggedAverageSacProvider = FutureProvider<double?>((ref) async {
  final repository = ref.watch(statisticsRepositoryProvider);
  final sacByRole = await repository.getSacVolumeByTankRole();
  return sacByRole['backGas'] ??
      (sacByRole.isEmpty ? null : sacByRole.values.first);
});

/// Scrub cursor position along the plan, in seconds (null = not scrubbing).
final scrubTimeProvider = StateProvider<double?>((_) => null);

/// Which results-sheet section the last chip tap targeted (0 = top).
final planResultsSheetSectionProvider = StateProvider<int>((_) => 0);

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

/// Chart series for the current plan: user segments plus the computed
/// ascent tail (travel legs + stops), ceiling approximation, and markers.
final planCanvasSeriesProvider = Provider<PlanCanvasSeries>((ref) {
  final state = ref.watch(divePlanNotifierProvider);
  final outcome = ref.watch(planOutcomeProvider);
  return buildCanvasSeries(segments: state.segments, outcome: outcome);
});

/// Builds the chart series for any (segments, outcome) pair — the live plan
/// or a contingency variant (ghost overlay).
PlanCanvasSeries buildCanvasSeries({
  required List<PlanSegment> segments,
  required PlanOutcome outcome,
}) {
  final sorted = List<PlanSegment>.from(segments)
    ..sort((a, b) => a.order.compareTo(b.order));

  final profile = <CanvasPoint>[];
  var t = 0.0;
  for (final segment in sorted) {
    if (profile.isEmpty || profile.last.depth != segment.startDepth) {
      profile.add(CanvasPoint(t, segment.startDepth));
    }
    t += segment.durationSeconds;
    profile.add(CanvasPoint(t, segment.endDepth));
  }

  // Computed ascent tail: travel to each stop, hold, then surface.
  final gasSwitches = <CanvasMarker>[];
  final stopLabels = <CanvasMarker>[];
  double? previousFO2;
  double? previousFHe;
  if (sorted.isNotEmpty) {
    previousFO2 = sorted.last.gasMix.o2 / 100.0;
    previousFHe = sorted.last.gasMix.he / 100.0;
  }
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
    final switched =
        previousFO2 == null ||
        (stop.gasFO2 - previousFO2).abs() > 0.005 ||
        (stop.gasFHe - (previousFHe ?? 0)).abs() > 0.005;
    if (switched && previousFO2 != null) {
      gasSwitches.add(
        CanvasMarker(
          stop.arrivalRuntimeSeconds.toDouble(),
          stop.depthMeters,
          GasMix(o2: stop.gasFO2 * 100.0, he: stop.gasFHe * 100.0).name,
        ),
      );
    }
    previousFO2 = stop.gasFO2;
    previousFHe = stop.gasFHe;
  }
  if (profile.isNotEmpty && profile.last.depth > 0) {
    profile.add(CanvasPoint(outcome.runtimeSeconds.toDouble(), 0));
  }

  // Ceiling approximation: segment-end ceilings plus the stop staircase.
  final ceiling = <CanvasPoint>[];
  for (final segmentOutcome in outcome.segmentOutcomes) {
    if (segmentOutcome.ceilingAtEnd > 0) {
      ceiling.add(
        CanvasPoint(
          segmentOutcome.endRuntime.toDouble(),
          segmentOutcome.ceilingAtEnd,
        ),
      );
    }
  }
  for (final stop in outcome.stops) {
    ceiling.add(
      CanvasPoint(stop.arrivalRuntimeSeconds.toDouble(), stop.depthMeters),
    );
    ceiling.add(
      CanvasPoint(
        (stop.arrivalRuntimeSeconds + stop.durationSeconds).toDouble(),
        stop.depthMeters,
      ),
    );
  }

  return PlanCanvasSeries(
    profile: profile,
    ceiling: ceiling,
    gasSwitches: gasSwitches,
    stopLabels: stopLabels,
    maxTimeSeconds: outcome.runtimeSeconds.toDouble(),
    maxDepth: outcome.maxDepth,
  );
}

/// Worst-case bailout for the current CCR plan; null for OC plans or when
/// no bailout-role tank is carried. Recomputed live with the plan.
final planBailoutProvider = Provider<BailoutOutcome?>((ref) {
  final state = ref.watch(divePlanNotifierProvider);
  final solver = BailoutSolver(config: ref.watch(planEngineConfigProvider));
  return solver.solve(divePlanFromState(state));
});

/// Deviation (deeper/longer/both) outcomes for the current plan.
/// Whether the results sheet's contingency section is expanded. The full
/// deviation + lost-gas tables (3 engine runs + one per deco/stage tank) are
/// only computed while this is true, so a collapsed sheet costs nothing.
final contingenciesExpandedProvider = StateProvider<bool>((_) => false);

final planDeviationsProvider = Provider<List<DeviationOutcome>>((ref) {
  if (!ref.watch(contingenciesExpandedProvider)) return const [];
  final state = ref.watch(divePlanNotifierProvider);
  final service = ContingencyService(
    config: ref.watch(planEngineConfigProvider),
  );
  return service.deviations(divePlanFromState(state));
});

/// Lost-gas outcomes for the current OC plan.
final planLostGasProvider = Provider<List<LostGasOutcome>>((ref) {
  if (!ref.watch(contingenciesExpandedProvider)) return const [];
  final state = ref.watch(divePlanNotifierProvider);
  final service = ContingencyService(
    config: ref.watch(planEngineConfigProvider),
  );
  return service.lostGas(divePlanFromState(state));
});

/// The classic slate range table (depth x time variants) for the current
/// plan; null when there is nothing to vary.
final planRangeTableProvider = Provider<RangeTable?>((ref) {
  final state = ref.watch(divePlanNotifierProvider);
  if (state.segments.isEmpty) return null;
  final service = RangeTableService(
    config: ref.watch(planEngineConfigProvider),
  );
  final table = service.compute(divePlanFromState(state));
  return table.isEmpty ? null : table;
});

/// Which deviation is ghosted on the chart ('deeper'|'longer'|'both'; null =
/// none).
final selectedDeviationProvider = StateProvider<String?>((_) => null);

/// Chart series for the selected deviation, drawn as a ghost overlay. Runs
/// ONLY the one selected variant (not the full deviation set), so ghosting a
/// contingency from the chips costs a single engine run.
final deviationGhostSeriesProvider = Provider<PlanCanvasSeries?>((ref) {
  final key = ref.watch(selectedDeviationProvider);
  if (key == null) return null;
  final state = ref.watch(divePlanNotifierProvider);
  final service = ContingencyService(
    config: ref.watch(planEngineConfigProvider),
  );
  final deviation = service.deviationFor(divePlanFromState(state), key);
  if (deviation == null) return null;
  return buildCanvasSeries(
    segments: deviation.plan.segments,
    outcome: deviation.outcome,
  );
});
