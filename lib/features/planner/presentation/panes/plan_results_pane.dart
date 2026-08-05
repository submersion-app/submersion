import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_kit.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_results_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The always-visible results column of Mission Control: headline stat tiles
/// over the full results content.
class PlanResultsPane extends ConsumerWidget {
  const PlanResultsPane({super.key, required this.controller});

  final ScrollController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outcome = ref.watch(planOutcomeProvider);
    final scheme = Theme.of(context).colorScheme;
    final inDeco = outcome.stops.isNotEmpty;

    String minutes(int seconds) => "${(seconds / 60).round()}'";

    final tiles = [
      PlanStatTile(
        label: context.l10n.divePlanner_label_runtime,
        value: minutes(outcome.runtimeSeconds),
      ),
      if (inDeco)
        PlanStatTile(
          label: context.l10n.divePlanner_label_tts,
          value: minutes(outcome.ttsAtBottom),
        )
      else
        PlanStatTile(
          label: context.l10n.divePlanner_label_ndl,
          value: minutes(outcome.ndlAtBottom),
        ),
      // CNS is an untranslatable acronym (same precedent as CCR).
      PlanStatTile(label: 'CNS', value: '${outcome.cnsEnd.round()}%'),
      PlanStatTile(
        label: context.l10n.divePlanner_label_warnings,
        value: '${outcome.issues.length}',
        emphasisColor: outcome.issues.isEmpty ? null : scheme.error,
      ),
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.2,
            children: tiles,
          ),
        ),
        Expanded(child: PlanResultsSheet(controller: controller)),
      ],
    );
  }
}
