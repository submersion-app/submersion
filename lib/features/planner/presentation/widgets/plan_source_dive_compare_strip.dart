import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/providers/source_dive_deco_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Compact "vs. original dive" strip: shown in the results pane whenever the
/// active plan was opened via "What if..." (has a `sourceDiveId`). Compares
/// the live plan outcome against what the diver actually logged.
class PlanSourceDiveCompareStrip extends ConsumerWidget {
  const PlanSourceDiveCompareStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diveAsync = ref.watch(sourceDiveForPlanProvider);
    final dive = diveAsync.valueOrNull;
    if (dive == null) return const SizedBox.shrink();

    final outcome = ref.watch(activePlanOutcomeProvider);
    final actualTtsSeconds = ref
        .watch(sourceDiveTtsSecondsProvider)
        .valueOrNull;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final theme = Theme.of(context);

    final rows = <_CompareRow>[
      _CompareRow(
        label: context.l10n.plannerCanvas_compare_runtime,
        planned: '${(outcome.runtimeSeconds / 60).round()}′',
        actual: dive.effectiveRuntime == null
            ? '--'
            : '${dive.effectiveRuntime!.inMinutes}′',
      ),
      _CompareRow(
        label: context.l10n.plannerCanvas_compare_maxDepth,
        planned: units.formatDepth(outcome.maxDepth),
        actual: dive.maxDepth == null ? '--' : units.formatDepth(dive.maxDepth),
      ),
      _CompareRow(
        label: context.l10n.divePlanner_label_tts,
        planned: '${(outcome.ttsAtBottom / 60).round()}′',
        actual: actualTtsSeconds == null
            ? '--'
            : '${(actualTtsSeconds / 60).round()}′',
      ),
      for (final tank in dive.tanks)
        if (tank.pressureUsed != null && tank.volume != null)
          _CompareRow(
            label: context.l10n.plannerCanvas_compare_gas(
              tank.name ?? tank.gasMix.name,
            ),
            planned: _plannedGasFor(outcome, tank.id, units),
            actual: units.formatVolume(tank.pressureUsed! * tank.volume!),
          ),
      if (dive.profile.isNotEmpty && dive.profile.last.cns != null)
        _CompareRow(
          label: context.l10n.plannerCanvas_compare_cns,
          planned: '${outcome.cnsEnd.round()}%',
          actual: '${dive.profile.last.cns!.round()}%',
        ),
    ];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.plannerCanvas_sourceCompare_title,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                Text(
                  context.l10n.plannerCanvas_compare_showOnChart,
                  style: theme.textTheme.labelSmall,
                ),
                Switch(
                  key: const Key('sourceDiveOverlayToggle'),
                  value: ref.watch(showSourceDiveOverlayProvider),
                  onChanged: (v) =>
                      ref.read(showSourceDiveOverlayProvider.notifier).state =
                          v,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Expanded(flex: 2, child: SizedBox.shrink()),
                Expanded(
                  child: Text(
                    context.l10n.plannerCanvas_compare_planned,
                    style: theme.textTheme.labelSmall,
                    textAlign: TextAlign.end,
                  ),
                ),
                Expanded(
                  child: Text(
                    context.l10n.plannerCanvas_compare_actual,
                    style: theme.textTheme.labelSmall,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: Text(row.label)),
                    Expanded(
                      child: Text(row.planned, textAlign: TextAlign.end),
                    ),
                    Expanded(child: Text(row.actual, textAlign: TextAlign.end)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _plannedGasFor(
    PlanOutcome outcome,
    String tankId,
    UnitFormatter units,
  ) {
    final usage = outcome.tankUsages.where((u) => u.tankId == tankId);
    if (usage.isEmpty) return '--';
    return units.formatVolume(usage.first.litersUsed);
  }
}

class _CompareRow {
  const _CompareRow({
    required this.label,
    required this.planned,
    required this.actual,
  });
  final String label;
  final String planned;
  final String actual;
}
