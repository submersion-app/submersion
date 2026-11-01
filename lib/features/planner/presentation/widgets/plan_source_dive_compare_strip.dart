import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/providers/source_dive_deco_provider.dart';
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
    // .value keeps the last readings through a reload of the source dive.
    final actualTtsSeconds = ref.watch(sourceDiveTtsSecondsProvider).value;
    final actualDecoSeconds = ref.watch(sourceDiveDecoSecondsProvider).value;
    final actualCnsEnd = ref.watch(sourceDiveCnsEndProvider).value;
    final units = ref.watch(unitFormatterProvider);
    final theme = Theme.of(context);

    final rows = planVersusActualRows(
      context,
      dive: dive,
      outcome: outcome,
      units: units,
      actualTtsSeconds: actualTtsSeconds,
      actualDecoSeconds: actualDecoSeconds,
      actualCnsEnd: actualCnsEnd,
    );

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
            PlanVersusActualTable(rows: rows),
          ],
        ),
      ),
    );
  }
}

/// The figures a plan and the dive it became are compared on.
List<PlanCompareRow> planVersusActualRows(
  BuildContext context, {
  required Dive dive,
  required PlanOutcome outcome,
  required UnitFormatter units,
  required int? actualTtsSeconds,
  required int? actualDecoSeconds,
  required double? actualCnsEnd,
  List<DiveTank>? planTanks,
}) {
  /// A logged dive's tanks have their own ids, so a dive of a series matches
  /// its plan's by position; a replan's tanks share theirs with the dive.
  String plannedGas(int index, DiveTank tank) {
    final id = planTanks == null
        ? tank.id
        : index < planTanks.length
        ? planTanks[index].id
        : null;
    final usage = outcome.tankUsages.where((u) => u.tankId == id);
    if (usage.isEmpty) return '--';
    return units.formatVolume(usage.first.litersUsed);
  }

  return [
    PlanCompareRow(
      label: context.l10n.plannerCanvas_compare_runtime,
      planned: '${(outcome.runtimeSeconds / 60).round()}′',
      actual: dive.effectiveRuntime == null
          ? '--'
          : '${dive.effectiveRuntime!.inMinutes}′',
    ),
    PlanCompareRow(
      label: context.l10n.plannerCanvas_compare_maxDepth,
      planned: units.formatDepth(outcome.maxDepth),
      actual: dive.maxDepth == null ? '--' : units.formatDepth(dive.maxDepth),
    ),
    PlanCompareRow(
      label: context.l10n.divePlanner_label_tts,
      planned: '${(outcome.ttsAtBottom / 60).round()}′',
      actual: actualTtsSeconds == null
          ? '--'
          : '${(actualTtsSeconds / 60).round()}′',
    ),
    // The hanging inside that TTS. TTS also carries the ascent travel, which
    // the diver's ascent rates set rather than the gas or depth they came
    // here to vary, so the deco figure is the one that isolates the change.
    PlanCompareRow(
      label: context.l10n.plannerCanvas_compare_deco,
      planned: '${(outcome.totalDecoSeconds / 60).round()}′',
      actual: actualDecoSeconds == null
          ? '--'
          : '${(actualDecoSeconds / 60).round()}′',
    ),
    for (final (index, tank) in dive.tanks.indexed)
      if (tank.pressureUsed != null && tank.volume != null)
        PlanCompareRow(
          label: context.l10n.plannerCanvas_compare_gas(
            tank.name ?? tank.gasMix.name,
          ),
          planned: plannedGas(index, tank),
          actual: units.formatVolume(tank.pressureUsed! * tank.volume!),
        ),
    if (actualCnsEnd != null)
      PlanCompareRow(
        label: context.l10n.plannerCanvas_compare_cns,
        planned: '${outcome.cnsEnd.round()}%',
        actual: '${actualCnsEnd.round()}%',
      ),
  ];
}

/// [rows] under Planned and Actual headings.
class PlanVersusActualTable extends StatelessWidget {
  const PlanVersusActualTable({super.key, required this.rows});

  final List<PlanCompareRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                Expanded(child: Text(row.planned, textAlign: TextAlign.end)),
                Expanded(child: Text(row.actual, textAlign: TextAlign.end)),
              ],
            ),
          ),
      ],
    );
  }
}

class PlanCompareRow {
  const PlanCompareRow({
    required this.label,
    required this.planned,
    required this.actual,
  });
  final String label;
  final String planned;
  final String actual;
}
