import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_palette.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The runtime, depth and time left at the scrub cursor.
class PlanScrubReadout extends ConsumerWidget {
  const PlanScrubReadout({
    super.key,
    required this.runtimeSeconds,
    required this.depthMeters,
    required this.units,
    required this.palette,
  });

  final double runtimeSeconds;
  final double depthMeters;
  final UnitFormatter units;
  final PlanChartPalette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final minutes = (runtimeSeconds / 60).round();
    final outcome = ref.watch(planOutcomeProvider);
    var text = context.l10n.plannerCanvas_scrub_readout(
      minutes.toString(),
      units.formatDepth(depthMeters, decimals: 0),
    );
    // The plan's own remaining time, not a bailout TTS: the schedule the
    // diver is actually following is already fully computed, so the time
    // left is just the plan's total runtime minus how far the scrub point
    // already is into it.
    final remainingSeconds = (outcome.runtimeSeconds - runtimeSeconds).clamp(
      0,
      outcome.runtimeSeconds,
    );
    text +=
        ' · '
        '${context.l10n.plannerCanvas_scrub_tts('${(remainingSeconds / 60).ceil()}')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.readoutBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.readoutBorder),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: palette.readoutText,
        ),
      ),
    );
  }
}
