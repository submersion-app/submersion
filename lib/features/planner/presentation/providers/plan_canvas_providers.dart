import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// PlanEngine thresholds sourced from the diver's deco settings.
final planEngineConfigProvider = Provider<PlanEngineConfig>((ref) {
  return PlanEngineConfig(
    ppO2Working: ref.watch(ppO2MaxWorkingProvider),
    ppO2Deco: ref.watch(ppO2MaxDecoProvider),
    cnsWarningThreshold: ref.watch(cnsWarningThresholdProvider),
    o2Narcotic: ref.watch(settingsProvider).o2Narcotic,
  );
});

/// The canvas's single source of computed truth: the current editing state
/// run through the PlanEngine on every change (live recalc, no button).
final planOutcomeProvider = Provider<PlanOutcome>((ref) {
  final state = ref.watch(divePlanNotifierProvider);
  final engine = PlanEngine(config: ref.watch(planEngineConfigProvider));
  return engine.compute(divePlanFromState(state));
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

  final segments = List<PlanSegment>.from(state.segments)
    ..sort((a, b) => a.order.compareTo(b.order));

  final profile = <CanvasPoint>[];
  var t = 0.0;
  for (final segment in segments) {
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
  if (segments.isNotEmpty) {
    previousFO2 = segments.last.gasMix.o2 / 100.0;
    previousFHe = segments.last.gasMix.he / 100.0;
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
});
