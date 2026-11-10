import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/safety_review_section.dart';
import 'package:submersion/features/planner/presentation/info/plan_results_info.dart';
import 'package:submersion/features/planner/presentation/providers/plan_follow_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_logged_dive_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_overlay_provider.dart';
import 'package:submersion/features/planner/presentation/widgets/logged/logged_dive_carry_card.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_gas_row.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_kit.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_runtime_table.dart';
import 'package:submersion/features/planner/presentation/widgets/range_table_section.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/info_sheet/info_units.dart';
import 'package:submersion/shared/widgets/info_sheet/dive_terms.dart';

/// The results for a logged dive picked in the series bar (issue #3565), in
/// the results pane's place: what it carries into the next dive, two tiles
/// wide, then its runtime and how many warnings its safety review raised.
/// Below them, when the dive was dived from a plan, that plan's deco
/// schedule, gas and range table "as planned", and last the review's
/// findings, which the Warnings tile scrolls to.
class LoggedDiveResults extends ConsumerStatefulWidget {
  const LoggedDiveResults({
    super.key,
    required this.controller,
    this.shrinkWrap = false,
  });

  final ScrollController controller;

  /// As on the planned dive's results: lay out to the natural height inside
  /// an outer scrollable (the phone tab deck).
  final bool shrinkWrap;

  @override
  ConsumerState<LoggedDiveResults> createState() => _LoggedDiveResultsState();
}

class _LoggedDiveResultsState extends ConsumerState<LoggedDiveResults> {
  final _warningsKey = GlobalKey();

  void _showWarnings() {
    final target = _warningsKey.currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final logged = ref.watch(viewedLoggedDiveProvider);
    if (logged == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final dive = ref.watch(diveProvider(logged.id)).value;
    final findings = ref.watch(viewedLoggedDiveFindingsProvider);
    final plan = ref.watch(viewedLoggedDivePlanProvider);
    // The measured runtime, as the dive log reports it: never the bottom
    // time a dive with no runtime falls back to for time windows (#3304).
    final runtime = dive?.measuredRuntime;

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        children: [
          const LoggedDiveCarryCard(),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: PlanStatTile(
                  label: l10n.divePlanner_label_runtime,
                  value: runtime == null ? '--' : "${runtime.inMinutes}'",
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  key: const Key('loggedDiveWarningsTile'),
                  borderRadius: BorderRadius.circular(8),
                  onTap: findings.isEmpty ? null : _showWarnings,
                  child: PlanStatTile(
                    label: l10n.divePlanner_label_warnings,
                    value: '${findings.length}',
                    // The review's own tone: notable, not alarming.
                    emphasisColor: findings.isEmpty ? null : scheme.tertiary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final body = SingleChildScrollView(
      controller: widget.controller,
      physics: widget.shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (plan != null) _AsPlanned(diveId: logged.id, plan: plan),
          KeyedSubtree(
            key: _warningsKey,
            child: SafetyReviewSection(diveId: logged.id),
          ),
        ],
      ),
    );

    return Column(
      children: [
        header,
        if (widget.shrinkWrap) body else Expanded(child: body),
      ],
    );
  }
}

/// The plan a logged dive was dived from, as it was planned: its deco
/// schedule, gas consumption and range table, read-only.
class _AsPlanned extends ConsumerWidget {
  const _AsPlanned({required this.diveId, required this.plan});

  final String diveId;
  final LinkedPlanComparison plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = ref.watch(unitFormatterProvider);
    final outcome = plan.outcome;
    final tanks = plan.plan.tanks;
    final rangeTable = ref.watch(linkedPlanRangeTableProvider(diveId)).value;

    String tankLabel(String? tankId) {
      final tank = tanks.where((t) => t.id == tankId).firstOrNull;
      if (tank == null) return '--';
      return tank.name ?? tank.gasMix.name;
    }

    return Column(
      key: const Key('loggedDiveAsPlanned'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.plannerSeries_asPlanned,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        PlanSectionHeader(
          l10n.divePlanner_label_decoSchedule,
          info: (context) =>
              planDecoScheduleInfo(context.l10n, infoUnits(context)),
        ),
        PlanRuntimeTable(
          outcome: outcome,
          units: units,
          editable: false,
          stopMinimums: plan.plan.stopMinimums,
        ),
        const SizedBox(height: 20),
        PlanSectionHeader(
          l10n.divePlanner_label_gasConsumption,
          info: (context) => planGasInfo(context.l10n, infoUnits(context)),
        ),
        for (final usage in outcome.tankUsages)
          if (usage.litersUsed > 0)
            PlanGasRow(
              usage: usage,
              label: tankLabel(usage.tankId),
              units: units,
            ),
        if (rangeTable != null) ...[
          const SizedBox(height: 20),
          PlanSectionHeader(
            l10n.plannerCanvas_range_title,
            info: (context) => termsInfo(
              context.l10n,
              infoUnits(context),
              title: context.l10n.plannerCanvas_range_title,
              summary: context.l10n.info_planner_range_summary,
            ),
          ),
          RangeTableGrid(table: rangeTable, units: units),
        ],
        const SizedBox(height: 20),
      ],
    );
  }
}
