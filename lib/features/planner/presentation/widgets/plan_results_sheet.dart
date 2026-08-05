import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_kit.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/bailout_solver.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_status_chips.dart';
import 'package:submersion/features/planner/presentation/widgets/range_table_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Localized, unit-aware message for a plan issue. Reuses the existing
/// `divePlanner_warning_*` strings where a type overlaps, so only genuinely
/// new issue types need new keys.
String planIssueMessage(
  BuildContext context,
  PlanIssue issue,
  UnitFormatter units,
) {
  final l10n = context.l10n;
  switch (issue.type) {
    case PlanIssueType.ppO2High:
      return l10n.divePlanner_warning_ppO2High(
        issue.value?.toStringAsFixed(2) ?? '--',
      );
    case PlanIssueType.ppO2Critical:
      return l10n.divePlanner_warning_ppO2Critical(
        issue.value?.toStringAsFixed(2) ?? '--',
      );
    case PlanIssueType.hypoxicGas:
      return l10n.plannerCanvas_issue_hypoxic(
        units.formatDepth(issue.atDepth ?? 0, decimals: 0),
        issue.value?.toStringAsFixed(2) ?? '--',
      );
    case PlanIssueType.endExceeded:
      return l10n.divePlanner_warning_endHighWithDepth(
        units.formatDepth(issue.value ?? 0, decimals: 0),
      );
    case PlanIssueType.gasDensityHigh:
      return l10n.plannerCanvas_issue_gasDensityHigh(
        issue.value?.toStringAsFixed(1) ?? '--',
      );
    case PlanIssueType.gasDensityCritical:
      return l10n.plannerCanvas_issue_gasDensityCritical(
        issue.value?.toStringAsFixed(1) ?? '--',
      );
    case PlanIssueType.cnsWarning:
      return l10n.divePlanner_warning_cnsWarning(
        issue.value?.toStringAsFixed(0) ?? '--',
      );
    case PlanIssueType.cnsCritical:
      return l10n.divePlanner_warning_cnsCritical;
    case PlanIssueType.otuHigh:
      return l10n.divePlanner_warning_otuWarning;
    case PlanIssueType.gasReserveViolation:
      return l10n.divePlanner_warning_gasLow(
        units.formatPressure(issue.threshold ?? 0),
      );
    case PlanIssueType.gasOut:
      return l10n.divePlanner_warning_gasOut;
    case PlanIssueType.ndlExceededNoDecoGas:
      return l10n.plannerCanvas_issue_noDecoGas;
    case PlanIssueType.noBailoutCarried:
      return l10n.plannerCanvas_issue_noBailout;
    case PlanIssueType.minGasViolation:
      return l10n.plannerCanvas_issue_minGas(
        units.formatPressure(issue.threshold ?? 0),
      );
  }
}

IconData _issueIcon(PlanIssueSeverity severity) {
  switch (severity) {
    case PlanIssueSeverity.critical:
      return Icons.error;
    case PlanIssueSeverity.alert:
      return Icons.warning;
    case PlanIssueSeverity.warning:
      return Icons.warning_amber;
    case PlanIssueSeverity.info:
      return Icons.info_outline;
  }
}

/// The results content: runtime table, per-tank gas plan, and the
/// severity-sorted issue list. The page owns the sheet chrome and passes the
/// [controller] so the sheet scrolls as one.
class PlanResultsSheet extends ConsumerWidget {
  const PlanResultsSheet({super.key, required this.controller});

  final ScrollController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outcome = ref.watch(planOutcomeProvider);
    final state = ref.watch(divePlanNotifierProvider);
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final theme = Theme.of(context);

    String tankLabel(String? tankId) {
      final tank = state.tanks.where((t) => t.id == tankId).firstOrNull;
      if (tank == null) return '--';
      return tank.name ?? tank.gasMix.name;
    }

    final bailout = ref.watch(planBailoutProvider);

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _grip(theme),
        PlanSectionHeader(context.l10n.divePlanner_label_decoSchedule),
        _RuntimeTable(outcome: outcome, units: units),
        const SizedBox(height: 20),
        PlanSectionHeader(context.l10n.divePlanner_label_gasConsumption),
        for (final usage in outcome.tankUsages)
          _GasRow(usage: usage, label: tankLabel(usage.tankId), units: units),
        if (bailout != null) ...[
          const SizedBox(height: 20),
          PlanSectionHeader(context.l10n.plannerCanvas_bailout_title),
          _BailoutSection(outcome: bailout, units: units),
        ],
        ...?_contingencySections(context, ref, units),
        if (ref.watch(planRangeTableProvider) != null) ...[
          const SizedBox(height: 20),
          PlanSectionHeader(context.l10n.plannerCanvas_range_title),
          const RangeTableSection(),
        ],
        const SizedBox(height: 20),
        PlanSectionHeader(context.l10n.divePlanner_label_warnings),
        if (outcome.issues.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              context.l10n.divePlanner_label_empty,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          )
        else
          for (final issue in outcome.issues)
            _IssueRow(issue: issue, units: units),
      ],
    );
  }

  /// Collapsible deviation and lost-gas mini tables; null when the plan has no
  /// segments to vary. Collapsed by default so the expensive per-variant engine
  /// runs happen only when the diver opens the section (the providers return
  /// empty while [contingenciesExpandedProvider] is false).
  List<Widget>? _contingencySections(
    BuildContext context,
    WidgetRef ref,
    UnitFormatter units,
  ) {
    final state = ref.watch(divePlanNotifierProvider);
    if (state.segments.isEmpty) return null;
    final expanded = ref.watch(contingenciesExpandedProvider);
    final deviations = ref.watch(planDeviationsProvider);
    final lostGas = ref.watch(planLostGasProvider);
    final theme = Theme.of(context);

    String deviationLabel(String key) {
      final depth =
          '+${units.formatDepth(state.deviationDepthDelta, decimals: 0)}';
      final time = '+${state.deviationTimeMinutes}\u2032';
      return switch (key) {
        'deeper' => depth,
        'longer' => time,
        _ => '$depth $time',
      };
    }

    Widget subHeader(String text) => Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    return [
      const SizedBox(height: 20),
      InkWell(
        onTap: () =>
            ref.read(contingenciesExpandedProvider.notifier).state = !expanded,
        child: Row(
          children: [
            PlanSectionHeader(context.l10n.plannerCanvas_contingency_title),
            const Spacer(),
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              size: 20,
              color: theme.colorScheme.outline,
            ),
          ],
        ),
      ),
      if (expanded) ...[
        for (final deviation in deviations) ...[
          subHeader(deviationLabel(deviation.key)),
          _RuntimeTable(outcome: deviation.outcome, units: units),
        ],
        for (final lost in lostGas) ...[
          subHeader(
            context.l10n.plannerCanvas_contingency_lostGas(
              lost.tank.gasMix.name,
            ),
          ),
          _RuntimeTable(outcome: lost.outcome, units: units),
        ],
      ],
    ];
  }

  Widget _grip(ThemeData theme) => Center(
    child: Container(
      width: 32,
      height: 4,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.outline.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

class _RuntimeTable extends StatelessWidget {
  const _RuntimeTable({required this.outcome, required this.units});

  final PlanOutcome outcome;
  final UnitFormatter units;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    if (outcome.stops.isEmpty) {
      return Text(
        l10n.plannerCanvas_results_noDeco,
        style: theme.textTheme.bodyMedium,
      );
    }

    Widget cell(String text, {bool header = false, int flex = 1}) => Expanded(
      flex: flex,
      child: Text(
        text,
        style: header
            ? theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              )
            : theme.textTheme.bodyMedium,
      ),
    );

    return Column(
      children: [
        Row(
          children: [
            cell(l10n.plannerCanvas_table_depth, header: true),
            cell(l10n.plannerCanvas_table_stop, header: true),
            cell(l10n.plannerCanvas_table_runtime, header: true),
            cell(l10n.plannerCanvas_table_gas, header: true, flex: 2),
          ],
        ),
        const Divider(height: 12),
        for (final stop in outcome.stops)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                cell(units.formatDepth(stop.depthMeters, decimals: 0)),
                cell(_stopText(stop)),
                cell(
                  '${((stop.arrivalRuntimeSeconds + stop.durationSeconds) / 60).ceil()}′',
                ),
                cell(
                  GasMix(o2: stop.gasFO2 * 100, he: stop.gasFHe * 100).name,
                  flex: 2,
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _stopText(PlanStop stop) {
    final minutes = (stop.durationSeconds / 60).ceil();
    if (stop.airBreakSeconds > 0) {
      return "$minutes′ (+${(stop.airBreakSeconds / 60).ceil()}′)";
    }
    return '$minutes′';
  }
}

class _GasRow extends StatelessWidget {
  const _GasRow({
    required this.usage,
    required this.label,
    required this.units,
  });

  final PlanTankUsage usage;
  final String label;
  final UnitFormatter units;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = usage.remainingPressure;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
              Text(
                units.formatVolume(usage.litersUsed),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(width: 12),
              Text(
                remaining != null ? units.formatPressure(remaining) : '--',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: usage.reserveViolation
                      ? theme.colorScheme.error
                      : null,
                ),
              ),
            ],
          ),
          if (usage.turnPressureBar != null || usage.minGasBar != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                [
                  if (usage.turnPressureBar != null)
                    context.l10n.plannerCanvas_gas_turnAt(
                      units.formatPressure(usage.turnPressureBar),
                    ),
                  if (usage.minGasBar != null)
                    context.l10n.plannerCanvas_gas_minGas(
                      units.formatPressure(usage.minGasBar),
                    ),
                ].join(' \u00b7 '),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (usage.percentUsed / 100).clamp(0.0, 1.0),
              minHeight: 4,
              color: usage.reserveViolation
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}

class _IssueRow extends StatelessWidget {
  const _IssueRow({required this.issue, required this.units});

  final PlanIssue issue;
  final UnitFormatter units;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = planIssueSeverityColor(theme.colorScheme, issue.severity);
    return PlanWarningRow(
      icon: _issueIcon(issue.severity),
      color: color,
      message: planIssueMessage(context, issue, units),
    );
  }
}

class _BailoutSection extends StatelessWidget {
  const _BailoutSection({required this.outcome, required this.units});

  final BailoutOutcome outcome;
  final UnitFormatter units;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final worst = outcome.worstCase;
    final shortfallColor = outcome.sufficient
        ? theme.colorScheme.onSurface
        : theme.colorScheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.plannerCanvas_bailout_worstCase(
            '${(worst.runtimeSeconds / 60).round()}',
            units.formatDepth(worst.depthMeters, decimals: 0),
          ),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(
          context.l10n.plannerCanvas_bailout_tts(
            '${(worst.ttsSeconds / 60).ceil()}',
          ),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              context.l10n.plannerCanvas_bailout_required(
                units.formatVolume(worst.litersRequired),
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: shortfallColor,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              context.l10n.plannerCanvas_bailout_available(
                units.formatVolume(outcome.availableLiters),
              ),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
        if (!outcome.sufficient)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Icon(Icons.error, size: 18, color: theme.colorScheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.plannerCanvas_bailout_insufficient,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
