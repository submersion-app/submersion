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
  });

  final String diveId;
  final LabRequestInputs inputs;
  final ScenarioOutcome? outcome;
  final int? branchSeconds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final o = outcome;
    final branch = branchSeconds ?? 0;
    ChartSourceOverlay? ghost;
    if (o != null) {
      final points = <DiveProfilePoint>[
        for (var i = 0; i < o.counterfactualTimestamps.length; i++)
          if (o.counterfactualTimestamps[i] >= branch)
            DiveProfilePoint(
              timestamp: o.counterfactualTimestamps[i],
              depth: o.counterfactualDepths[i],
            ),
      ];
      if (points.length >= 2) {
        ghost = ChartSourceOverlay(
          sourceId: 'lab:draft',
          name: l10n.diveLab_panel_whatIf,
          color: kLabGhostColor,
          computerId: null,
          points: points,
        );
      }
    }
    final replay = o?.mode == ScenarioMode.replay;
    return DiveProfileChart(
      profile: inputs.profile,
      diveDuration: Duration(seconds: inputs.durationSeconds),
      showTemperature: false,
      overlays: ghost == null ? null : [ghost],
      ceilingCurve: o == null
          ? null
          : (replay ? o.counterfactual.ceilingCurve : o.actual.ceilingCurve),
      decoStopCurve: o == null
          ? null
          : (replay ? o.counterfactual.decoStopCurve : o.actual.decoStopCurve),
      tanks: inputs.tanks,
      highlightedTimestamp: branchSeconds,
    );
  }
}
