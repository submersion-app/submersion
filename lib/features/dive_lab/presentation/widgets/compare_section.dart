import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/log_failure.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_lab/domain/dive_lab_eligibility.dart';
import 'package:submersion/features/dive_lab/domain/entities/compare_column.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_lab/presentation/pages/dive_lab_page.dart';
import 'package:submersion/features/dive_lab/presentation/providers/compare_providers.dart';
import 'package:submersion/features/dive_lab/presentation/providers/dive_scenario_providers.dart';
import 'package:submersion/features/dive_lab/presentation/widgets/compare_chart.dart';
import 'package:submersion/features/dive_lab/presentation/widgets/compare_chips.dart';
import 'package:submersion/features/dive_lab/presentation/widgets/compare_table.dart';
import 'package:submersion/features/dive_lab/presentation/widgets/lab_chart.dart';
import 'package:submersion/features/dive_lab/presentation/widgets/link_plan_sheet.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/planner/presentation/providers/plan_overlay_provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Width at or above which the table sits beside the chart.
const double kCompareSectionWideBreakpoint = 720;

/// Compare on dive detail: the plan, the dive and its saved what-ifs on one
/// chart and in one table, and the way into the Compare page.
class CompareSection extends ConsumerWidget {
  const CompareSection({super.key, required this.diveId});

  final String diveId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dive = ref.watch(diveProvider(diveId)).value;
    if (dive == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final linked = ref.watch(hasLinkedPlanProvider(diveId));
    final scenarios =
        ref.watch(diveScenariosForDiveProvider(diveId)).valueOrNull ??
        const <DiveScenario>[];
    final eligible = isDiveLabEligible(dive);

    final Widget body;
    if (dive.isPlanned) {
      body = _Message(
        text: l10n.diveLab_compare_waiting,
        actions: [if (!linked) _LinkPlanButton(diveId: diveId)],
      );
    } else if (!linked && scenarios.isEmpty) {
      body = _Message(
        text: l10n.diveLab_compare_empty,
        actions: [
          if (eligible)
            FilledButton.tonalIcon(
              onPressed: () => showDiveLab(context, diveId),
              icon: const Icon(Icons.add),
              label: Text(l10n.diveLab_compare_askWhatIf),
            ),
          _LinkPlanButton(diveId: diveId),
        ],
      );
    } else {
      body = _Comparison(
        dive: dive,
        scenarios: eligible ? scenarios : const [],
        eligible: eligible,
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => showDiveLab(context, diveId),
              child: Row(
                children: [
                  Icon(
                    Icons.science_outlined,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.diveDetailSection_diveLab_name,
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            body,
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.actions});

  final String text;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      ],
    );
  }
}

class _LinkPlanButton extends ConsumerWidget {
  const _LinkPlanButton({required this.diveId});

  final String diveId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => OutlinedButton.icon(
    onPressed: () => logFailure(
      pickPlanAndLink(context, ref, diveId: diveId),
      _LinkPlanButton,
      'link plan to dive',
    ),
    icon: const Icon(Icons.link),
    label: Text(context.l10n.diveLab_compare_linkPlan),
  );
}

class _Comparison extends ConsumerWidget {
  const _Comparison({
    required this.dive,
    required this.scenarios,
    required this.eligible,
  });

  final Dive dive;
  final List<DiveScenario> scenarios;

  /// Whether the dive can branch; a linked dive that cannot has no what-ifs.
  final bool eligible;

  String get diveId => dive.id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = ref.watch(unitFormatterProvider);
    final overrides = ref.watch(compareLinesProvider(diveId));
    final comparison = ref.watch(linkedPlanComparisonProvider(diveId)).value;
    final planned = ref.watch(plannedColumnProvider(diveId));
    final dived = ref.watch(divedColumnProvider(diveId)).value;
    // The entity's own profile may be lean-hydrated.
    final profile =
        ref.watch(diveProfileProvider(diveId)).value ?? dive.profile;
    final newest = scenarios.firstOrNull?.id;

    bool isOn(String id) =>
        compareLineOn(overrides, id, newestWhatIfId: newest);
    void toggle(String id, bool on) {
      ref.read(compareLinesProvider(diveId).notifier).state = {
        ...overrides,
        id: on,
      };
    }

    final columns = <CompareColumn>[];
    final overlays = <ChartSourceOverlay>[];
    final chips = <CompareChipData>[];
    var duration = profile.isEmpty ? 0 : profile.last.timestamp;

    if (comparison != null) {
      final on = isOn('planned');
      chips.add(
        CompareChipData(
          id: 'planned',
          label: l10n.diveLab_compare_line_planned,
          color: comparison.overlay.color,
          selected: on,
          onToggle: (value) => toggle('planned', value),
        ),
      );
      if (on) {
        if (planned != null) columns.add(planned);
        overlays.add(comparison.overlay);
        duration = math.max(duration, comparison.outcome.runtimeSeconds);
      }
    }
    chips.add(
      CompareChipData(
        id: 'dived',
        label: l10n.diveLab_compare_line_asDived,
        color: theme.colorScheme.primary,
        selected: true,
        dashed: false,
      ),
    );
    if (dived != null) columns.add(dived);

    for (var i = 0; i < scenarios.length; i++) {
      final scenario = scenarios[i];
      final color = kCompareWhatIfColors[i % kCompareWhatIfColors.length];
      final on = isOn(scenario.id);
      chips.add(
        CompareChipData(
          id: scenario.id,
          label: scenario.name,
          color: color,
          selected: on,
          onToggle: (value) => toggle(scenario.id, value),
        ),
      );
      if (!on) continue;
      final line = ref
          .watch(whatIfLineProvider((diveId: diveId, scenarioId: scenario.id)))
          .value;
      if (line == null) continue;
      columns.add(line.column);
      final overlay = labWhatIfOverlay(
        line.outcome,
        branchSeconds: scenario.branchSeconds,
        sourceId: 'lab:${scenario.id}',
        name: scenario.name,
        color: color,
        tintByMetric: false,
      );
      if (overlay != null) overlays.add(overlay);
      if (line.outcome.counterfactualTimestamps.isNotEmpty) {
        duration = math.max(
          duration,
          line.outcome.counterfactualTimestamps.last,
        );
      }
    }

    final chart = profile.length < 2
        ? null
        : GestureDetector(
            key: const ValueKey('compareChart'),
            behavior: HitTestBehavior.opaque,
            onTap: () => showDiveLab(context, diveId),
            child: CompareChart(
              profile: profile,
              overlays: overlays,
              durationSeconds: duration,
              decoStartSeconds: dived?.decoStartSeconds,
            ),
          );
    final table = CompareTable(
      columns: columns,
      units: units,
      onOpenColumn: (column) =>
          showDiveLab(context, diveId, scenarioId: column.id),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CompareChips(
          chips: chips,
          actions: [
            if (eligible)
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: Text(l10n.diveLab_compare_addWhatIf),
                onPressed: () => showDiveLab(context, diveId),
              ),
            if (comparison == null) _LinkPlanButton(diveId: diveId),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            if (chart == null) return table;
            if (constraints.maxWidth >= kCompareSectionWideBreakpoint) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: chart),
                  const SizedBox(width: 16),
                  Expanded(child: table),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [chart, const SizedBox(height: 8), table],
            );
          },
        ),
      ],
    );
  }
}
