import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_lab/domain/entities/branch_state.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_consumption.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_delta.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_outcome.dart';
import 'package:submersion/features/dive_lab/presentation/lab_format.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_request_inputs_provider.dart';
import 'package:submersion/features/dive_lab/presentation/widgets/lab_runtime_table.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_color_schemes.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_heat_map.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_kit.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_results_sheet.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_status_chips.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Verdict, tiles, the actual | what-if | delta table, tissue strips, gas
/// rows, engine issues, the counterfactual runtime table and notes.
class LabDeltaPanel extends ConsumerWidget {
  const LabDeltaPanel({super.key, required this.inputs, required this.outcome});

  final LabRequestInputs inputs;
  final AsyncValue<ScenarioOutcome?> outcome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final colorFn = colorFnForScheme(ref.watch(tissueColorSchemeProvider));
    final value = outcome.valueOrNull;
    final loading = outcome.isLoading;
    String tankName(String id) => labTankName(inputs.tanks, id);

    if (value == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: loading
            ? Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(l10n.diveLab_panel_computing),
                ],
              )
            : const SizedBox.shrink(),
      );
    }

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Verdict(outcome: value, units: units, tankName: tankName),
        const SizedBox(height: 16),
        _Tiles(outcome: value, units: units, tankName: tankName),
        const SizedBox(height: 16),
        PlanSectionHeader(l10n.diveLab_panel_delta),
        _DeltaTable(outcome: value, units: units, tankName: tankName),
        const SizedBox(height: 16),
        PlanSectionHeader(l10n.diveLab_panel_tissues),
        _TissueStrips(outcome: value, colorFn: colorFn),
        const SizedBox(height: 16),
        PlanSectionHeader(l10n.diveLab_panel_gas),
        _GasRows(outcome: value, units: units, tankName: tankName),
        if (value.planOutcome != null) ...[
          const SizedBox(height: 16),
          PlanSectionHeader(l10n.diveLab_panel_issues),
          _Issues(planOutcome: value.planOutcome!, units: units),
          const SizedBox(height: 16),
          PlanSectionHeader(l10n.diveLab_panel_runtime),
          LabRuntimeTable(
            outcome: value.planOutcome!,
            units: units,
            runtimeOffsetSeconds: value.branch.runtimeSeconds,
          ),
        ],
        if (value.flags.isNotEmpty) ...[
          const SizedBox(height: 16),
          PlanSectionHeader(l10n.diveLab_panel_notes),
          for (final f in value.flags)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                labFlagText(l10n, f, tankName),
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 2,
          child: loading ? const LinearProgressIndicator(minHeight: 2) : null,
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Opacity(opacity: loading ? 0.6 : 1.0, child: body),
        ),
      ],
    );
  }
}

class _Verdict extends StatelessWidget {
  const _Verdict({
    required this.outcome,
    required this.units,
    required this.tankName,
  });
  final ScenarioOutcome outcome;
  final UnitFormatter units;
  final String Function(String) tankName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    if (outcome.verdictDeltas.isEmpty) {
      return Text(
        l10n.diveLab_panel_identity,
        style: theme.textTheme.titleSmall,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PlanSectionHeader(l10n.diveLab_panel_verdict),
        for (final d in outcome.verdictDeltas)
          Text(
            l10n.diveLab_verdict_item(
              labMetricLabel(l10n, d, tankName),
              labMetricValue(l10n, units, d.metric, d.actual),
              labMetricValue(l10n, units, d.metric, d.counterfactual),
              labDeltaValue(l10n, units, d),
            ),
            style: theme.textTheme.titleSmall,
          ),
      ],
    );
  }
}

class _Tiles extends StatelessWidget {
  const _Tiles({
    required this.outcome,
    required this.units,
    required this.tankName,
  });
  final ScenarioOutcome outcome;
  final UnitFormatter units;
  final String Function(String) tankName;

  ScenarioDelta? _find(DeltaMetric m, {String? tankId}) {
    for (final d in outcome.deltas) {
      if (d.metric == m && (tankId == null || d.tankId == tankId)) return d;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final back = outcome.consumption.counterfactual.isEmpty
        ? null
        : outcome.consumption.counterfactual.first.tankId;
    final entries = <(String, ScenarioDelta?)>[
      (l10n.diveLab_tile_tts, _find(DeltaMetric.ttsAtBranch)),
      (l10n.diveLab_tile_deco, _find(DeltaMetric.decoTimeAfterBranch)),
      (l10n.diveLab_tile_surfGf, _find(DeltaMetric.surfaceGf)),
      (l10n.diveLab_tile_cns, _find(DeltaMetric.cnsEnd)),
      if (back != null)
        (
          l10n.diveLab_tile_backGas,
          _find(DeltaMetric.tankEndPressure, tankId: back),
        ),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.2,
      children: [
        for (final (label, d) in entries)
          PlanStatTile(
            label: label,
            value: d == null
                ? l10n.diveLab_value_none
                : labMetricValue(l10n, units, d.metric, d.counterfactual),
            emphasisColor: d == null ? null : labDeltaColor(scheme, d),
          ),
      ],
    );
  }
}

class _DeltaTable extends StatelessWidget {
  const _DeltaTable({
    required this.outcome,
    required this.units,
    required this.tankName,
  });
  final ScenarioOutcome outcome;
  final UnitFormatter units;
  final String Function(String) tankName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final header = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.outline,
    );
    Widget cell(String text, {int flex = 1, TextStyle? style, Color? color}) =>
        Expanded(
          flex: flex,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Text(
              text,
              style: (style ?? theme.textTheme.bodySmall)?.copyWith(
                color: color,
              ),
            ),
          ),
        );
    return Column(
      children: [
        Row(
          children: [
            cell('', flex: 2, style: header),
            cell(l10n.diveLab_panel_actual, style: header),
            cell(l10n.diveLab_panel_whatIf, style: header),
            cell(l10n.diveLab_panel_delta, style: header),
          ],
        ),
        const Divider(height: 8),
        for (final d in outcome.deltas)
          Row(
            children: [
              cell(labMetricLabel(l10n, d, tankName), flex: 2),
              cell(labMetricValue(l10n, units, d.metric, d.actual)),
              cell(labMetricValue(l10n, units, d.metric, d.counterfactual)),
              cell(
                labDeltaValue(l10n, units, d),
                color: labDeltaColor(theme.colorScheme, d),
              ),
            ],
          ),
      ],
    );
  }
}

class _TissueStrips extends StatelessWidget {
  const _TissueStrips({required this.outcome, required this.colorFn});
  final ScenarioOutcome outcome;
  final TissueColorFn colorFn;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = Theme.of(context).textTheme.labelSmall;
    Widget strip(String label, List<dynamic> statuses) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: style),
        const SizedBox(height: 4),
        if (outcome.actual.decoStatuses.isNotEmpty)
          TissueHeatMapStrip(
            decoStatuses: statuses.cast(),
            height: 28,
            colorFn: colorFn,
          ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        strip(l10n.diveLab_panel_actual, outcome.actual.decoStatuses),
        const SizedBox(height: 8),
        strip(l10n.diveLab_panel_whatIf, outcome.counterfactual.decoStatuses),
      ],
    );
  }
}

class _GasRows extends StatelessWidget {
  const _GasRows({
    required this.outcome,
    required this.units,
    required this.tankName,
  });
  final ScenarioOutcome outcome;
  final UnitFormatter units;
  final String Function(String) tankName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final rows = outcome.consumption.counterfactual;
    if (rows.isEmpty) {
      return Text(l10n.diveLab_gas_unknown, style: theme.textTheme.bodySmall);
    }
    return Column(
      children: [for (final c in rows) _gasRow(context, c, theme, l10n)],
    );
  }

  Widget _gasRow(
    BuildContext context,
    TankConsumption c,
    ThemeData theme,
    dynamic l10n,
  ) {
    final actual = outcome.consumption.actualFor(c.tankId);
    final start = c.startPressureBar;
    final end = c.endPressureBar;
    final reserve = outcome.consumption.reservePressureBar;
    final warn = end != null && end < reserve;
    final sub = <String>[
      if (actual?.endPressureBar != null)
        '${l10n.diveLab_panel_actual}: '
            '${units.formatPressure(actual!.endPressureBar)}',
      if (c.reserveReachedAtSeconds != null)
        l10n.diveLab_gas_reserve(formatLabTime(c.reserveReachedAtSeconds!)),
      if (c.emptyAtSeconds != null)
        l10n.diveLab_gas_empty(formatLabTime(c.emptyAtSeconds!)),
      if (c.source != PressureSource.measured) l10n.diveLab_flag_sacEstimated,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tankName(c.tankId),
                  style: theme.textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${units.formatPressure(start)} → '
                  '${end == null ? l10n.diveLab_gas_unknown : units.formatPressure(end)}',
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: warn ? theme.colorScheme.error : null,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (sub.isNotEmpty)
            Text(
              sub.join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
        ],
      ),
    );
  }
}

class _Issues extends StatelessWidget {
  const _Issues({required this.planOutcome, required this.units});
  final PlanOutcome planOutcome;
  final UnitFormatter units;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    if (planOutcome.issues.isEmpty) {
      return Text(
        l10n.diveLab_panel_noIssues,
        style: theme.textTheme.bodySmall,
      );
    }
    IconData icon(PlanIssueSeverity s) => switch (s) {
      PlanIssueSeverity.critical => Icons.error,
      PlanIssueSeverity.alert => Icons.warning,
      PlanIssueSeverity.warning => Icons.warning_amber,
      PlanIssueSeverity.info => Icons.info_outline,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final issue in planOutcome.issues)
          PlanWarningRow(
            icon: icon(issue.severity),
            color: planIssueSeverityColor(theme.colorScheme, issue.severity),
            message: planIssueMessage(context, issue, units),
          ),
      ],
    );
  }
}
