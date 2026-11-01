import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_outcome.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_request_inputs_provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The counterfactual ghost colour: distinct from the planned-profile
/// overlay (purple) so plan-vs-actual and what-if never collide.
const Color kLabGhostColor = Colors.teal;

/// [outcome]'s counterfactual from the branch on, as a chart overlay; null
/// when too little of it remains to draw.
ChartSourceOverlay? labWhatIfOverlay(
  ScenarioOutcome outcome, {
  required int branchSeconds,
  required String sourceId,
  required String name,
  required Color color,
  bool tintByMetric = true,
}) {
  final points = <DiveProfilePoint>[
    for (var i = 0; i < outcome.counterfactualTimestamps.length; i++)
      if (outcome.counterfactualTimestamps[i] >= branchSeconds)
        DiveProfilePoint(
          timestamp: outcome.counterfactualTimestamps[i],
          depth: outcome.counterfactualDepths[i],
        ),
  ];
  if (points.length < 2) return null;
  return ChartSourceOverlay(
    sourceId: sourceId,
    name: name,
    color: color,
    computerId: null,
    points: points,
    tintByMetric: tintByMetric,
  );
}

/// The dive's profile with the counterfactual drawn as a dashed ghost from
/// the branch point and the branch marked by a vertical line. In replay
/// mode the chart's ceiling band is the what-if's (same sample count); in
/// re-plan mode the spliced what-if has its own sample grid, so the band
/// stays the actual one and only the ghost path shows the alternative.
class LabChart extends ConsumerWidget {
  const LabChart({
    super.key,
    required this.diveId,
    required this.inputs,
    required this.outcome,
    required this.branchSeconds,
    this.exportKey,
    this.planOverlay,
  });

  final String diveId;
  final LabRequestInputs inputs;
  final ScenarioOutcome? outcome;
  final int? branchSeconds;

  /// Wraps the chart in a RepaintBoundary for PNG capture (PDF, image share).
  final GlobalKey? exportKey;

  /// The linked plan's line, when it is showing.
  final ChartSourceOverlay? planOverlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final o = outcome;
    final ghost = o == null
        ? null
        : labWhatIfOverlay(
            o,
            branchSeconds: branchSeconds ?? 0,
            sourceId: 'lab:draft',
            name: l10n.diveLab_panel_whatIf,
            color: kLabGhostColor,
          );
    final replay = o?.mode == ScenarioMode.replay;
    final plan = planOverlay;
    final overlays = [?plan, ?ghost];
    // A plan can run past the dive; the axis has to reach its end.
    final planEnd = plan == null || plan.points.isEmpty
        ? 0
        : plan.points.last.timestamp;
    return DiveProfileChart(
      profile: inputs.profile,
      diveDuration: Duration(
        seconds: math.max(inputs.durationSeconds, planEnd),
      ),
      showTemperature: false,
      overlays: overlays.isEmpty ? null : overlays,
      ceilingCurve: o == null
          ? null
          : (replay ? o.counterfactual.ceilingCurve : o.actual.ceilingCurve),
      decoStopCurve: o == null
          ? null
          : (replay ? o.counterfactual.decoStopCurve : o.actual.decoStopCurve),
      tanks: inputs.tanks,
      highlightedTimestamp: branchSeconds,
      exportKey: exportKey,
    );
  }
}
