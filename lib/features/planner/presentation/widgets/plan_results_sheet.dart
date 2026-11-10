import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/presentation/info/plan_results_info.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_kit.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    show PlanMode;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/bailout_solver.dart';
import 'package:submersion/features/planner/domain/services/contingency_service.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/domain/services/schedule_lines.dart';
import 'package:submersion/features/planner/domain/services/tank_role_resolver.dart';
import 'package:submersion/features/planner/presentation/mission/mission_results_section.dart';
import 'package:submersion/features/planner/presentation/providers/plan_background_results.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_results_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_gas_row.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_issue_text.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_result_status.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_runtime_table.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_status_chips.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_warnings_section.dart';
import 'package:submersion/features/planner/presentation/widgets/range_table_section.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/info_sheet/dive_terms.dart';
import 'package:submersion/shared/widgets/info_sheet/info_button.dart';
import 'package:submersion/shared/widgets/info_sheet/info_units.dart';

/// The results content: runtime table, per-tank gas plan, and the
/// severity-sorted issue list. The page owns the sheet chrome and passes the
/// [controller] so the sheet scrolls as one.
class PlanResultsSheet extends ConsumerWidget {
  const PlanResultsSheet({
    super.key,
    required this.controller,
    this.shrinkWrap = false,
  });

  final ScrollController controller;

  /// When true, lays out to natural height with scrolling disabled so an
  /// outer scrollable (the phone tab deck) owns the scroll gesture instead.
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outcome = ref.watch(activePlanOutcomeProvider);
    final state = ref.watch(divePlanNotifierProvider);
    final units = ref.watch(unitFormatterProvider);
    final theme = Theme.of(context);

    String tankLabel(String? tankId) {
      final tank = state.tanks.where((t) => t.id == tankId).firstOrNull;
      if (tank == null) return '--';
      return tank.name ?? tank.gasMix.name;
    }

    // Each of these holds its section's place from a check that takes no
    // calculating, so the sheet does not jump as results land.
    final bailout = ref.watch(planMayHaveBailoutProvider)
        ? planResultView(ref.watch(planBailoutProvider), state.id)
        : null;
    final rangeTable = state.segments.isEmpty
        ? null
        : planResultView(ref.watch(planRangeTableProvider), state.id);
    final resolvedRoles = const TankRoleResolver().rolesFor(
      divePlanFromState(state),
    );
    // On a loop plan this list is what the plan consumes: the diluent(s) and
    // the oxygen supply, the plan's two mandatory slots (#3220), plus any
    // bailout cylinder an authored off-loop segment actually breathes
    // (#3898). The bailout cylinders otherwise carry no consumption and live
    // in the bailout section's own picture instead (#3137 follow-up). Open
    // circuit has no such distinction, so every tank it resolves to still
    // shows.
    final loopTankUsages = outcome.tankUsages.where((u) {
      final role = resolvedRoles[u.tankId];
      return state.mode == PlanMode.oc ||
          role == TankRole.diluent ||
          role == TankRole.oxygenSupply ||
          u.litersUsed > 0;
    });

    // Laid out in full rather than lazily, so the warnings list can be
    // measured and scrolled to while it is out of view (#3738).
    return SingleChildScrollView(
      controller: controller,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _grip(theme),
          PlanSectionHeader(
            context.l10n.divePlanner_label_decoSchedule,
            info: (context) =>
                planDecoScheduleInfo(context.l10n, infoUnits(context)),
          ),
          PlanRuntimeTable(
            outcome: outcome,
            units: units,
            // A dived dive's plan is the record of what was planned.
            editable: !ref.watch(planLockedProvider),
          ),
          const SizedBox(height: 20),
          PlanSectionHeader(
            context.l10n.divePlanner_label_gasConsumption,
            info: (context) => planGasInfo(context.l10n, infoUnits(context)),
          ),
          for (final usage in loopTankUsages)
            PlanGasRow(
              usage: usage,
              label: tankLabel(usage.tankId),
              units: units,
            ),
          if (ref.watch(
            divePlanNotifierProvider.select((s) => s.mission != null),
          )) ...[
            const SizedBox(height: 20),
            PlanSectionHeader(
              context.l10n.plannerMission_results_title,
              info: (context) => planSectionInfo(
                context.l10n,
                infoUnits(context),
                title: context.l10n.plannerMission_results_title,
                summary: context.l10n.info_planner_mission_summary,
                terms: const [DiveTerm.dpv],
              ),
            ),
            const MissionResultsSection(),
          ],
          if (bailout != null && !bailout.isFinishedEmpty) ...[
            const SizedBox(height: 20),
            PlanSectionHeader(
              context.l10n.plannerCanvas_bailout_title,
              info: (context) => planSectionInfo(
                context.l10n,
                infoUnits(context),
                title: context.l10n.plannerCanvas_bailout_title,
                summary: context.l10n.info_planner_bailout_summary,
                terms: const [DiveTerm.bailout],
              ),
            ),
            PlanResultSection<BailoutOutcome>(
              view: bailout,
              builder: (outcome) =>
                  _BailoutSection(outcome: outcome, units: units),
            ),
          ],
          ...?_contingencySections(context, ref, units),
          if (rangeTable != null && !rangeTable.isFinishedEmpty) ...[
            const SizedBox(height: 20),
            PlanSectionHeader(
              context.l10n.plannerCanvas_range_title,
              info: (context) => planSectionInfo(
                context.l10n,
                infoUnits(context),
                title: context.l10n.plannerCanvas_range_title,
                summary: context.l10n.info_planner_range_summary,
              ),
            ),
            const RangeTableSection(),
          ],
          const SizedBox(height: 20),
          PlanWarningsSection(
            key: const Key('planWarningsSection'),
            issues: outcome.issues,
            units: units,
          ),
        ],
      ),
    );
  }

  /// Every deviation and lost-gas mini table, each independently collapsible;
  /// null when the plan has no segments to vary. The section itself starts
  /// collapsed so the expensive per-variant engine runs happen only once the
  /// diver opens it (the providers return empty while
  /// [contingenciesExpandedProvider] is false); each row then starts expanded
  /// and can be collapsed individually to cut clutter once there are several.
  List<Widget>? _contingencySections(
    BuildContext context,
    WidgetRef ref,
    UnitFormatter units,
  ) {
    final state = ref.watch(divePlanNotifierProvider);
    if (state.segments.isEmpty) return null;
    final expanded = ref.watch(contingenciesExpandedProvider);
    final deviations = planResultView(
      ref.watch(planDeviationsProvider),
      state.id,
    );
    final lostGas = planResultView(ref.watch(planLostGasProvider), state.id);
    final selectedDeviation = ref.watch(selectedDeviationProvider);
    final selectedLostGasTankId = ref.watch(selectedLostGasTankIdProvider);
    final collapsedKeys = ref.watch(collapsedContingencyKeysProvider);
    final theme = Theme.of(context);

    void toggleCollapsed(String key) {
      final next = Set<String>.from(collapsedKeys);
      if (!next.add(key)) next.remove(key);
      ref.read(collapsedContingencyKeysProvider.notifier).state = next;
    }

    void toggleDeviation(String key) {
      final isSelected = selectedDeviation == key;
      ref.read(selectedDeviationProvider.notifier).state = isSelected
          ? null
          : key;
      // Only one contingency ghost/preview can be active at a time.
      if (!isSelected) {
        ref.read(selectedLostGasTankIdProvider.notifier).state = null;
      }
    }

    void toggleLostGas(String tankId) {
      final isSelected = selectedLostGasTankId == tankId;
      ref.read(selectedLostGasTankIdProvider.notifier).state = isSelected
          ? null
          : tankId;
      // Only one contingency ghost/preview can be active at a time.
      if (!isSelected) {
        ref.read(selectedDeviationProvider.notifier).state = null;
      }
    }

    String deviationLabel(String key) {
      // The plan's own deviation, else the diver's Settings default (#3552).
      final resolved = ref.watch(resolvedPlanEngineConfigProvider);
      final depth =
          '+${units.formatDepth(resolved.deviationDepthDelta, decimals: 0)}';
      final time = '+${resolved.deviationTimeMinutes}\u2032';
      return switch (key) {
        'deeper' => depth,
        'longer' => time,
        _ => '$depth $time',
      };
    }

    Widget row({
      required String key,
      required String label,
      required bool selected,
      required VoidCallback onSelect,
      required PlanOutcome outcome,
    }) {
      final collapsed = collapsedKeys.contains(key);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            // The chevron carries its own vertical slack (see below), so the
            // row only needs padding under it.
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // An IconButton rather than a bare InkWell so the 20px glyph
                // gets an accessible box around it: tapTargetSize is left at
                // the theme default (padded, kMinInteractiveDimension = 48)
                // and compact density trims it to 40x40, the same treatment
                // the rest of the app's small icon controls use.
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 20,
                  color: theme.colorScheme.outline,
                  onPressed: () => toggleCollapsed(key),
                  icon: Icon(
                    collapsed ? Icons.chevron_right : Icons.expand_more,
                  ),
                ),
                PlanChip(label: label, emphasized: selected, onTap: onSelect),
              ],
            ),
          ),
          if (!collapsed) PlanRuntimeTable(outcome: outcome, units: units),
        ],
      );
    }

    final rows = [
      for (final deviation in deviations.value ?? const <DeviationOutcome>[])
        row(
          key: deviation.key,
          label: deviationLabel(deviation.key),
          selected: selectedDeviation == deviation.key,
          onSelect: () => toggleDeviation(deviation.key),
          outcome: deviation.outcome,
        ),
      for (final lost in lostGas.value ?? const <LostGasOutcome>[])
        row(
          key: lost.tank.id,
          label: context.l10n.plannerCanvas_contingency_lostGas(
            lost.tank.gasMix.name,
          ),
          selected: selectedLostGasTankId == lost.tank.id,
          onSelect: () => toggleLostGas(lost.tank.id),
          outcome: lost.outcome,
        ),
    ];
    final status = combinePlanResultStatus(deviations.status, lostGas.status);

    return [
      const SizedBox(height: 20),
      InkWell(
        onTap: () =>
            ref.read(contingenciesExpandedProvider.notifier).state = !expanded,
        child: Row(
          children: [
            PlanSectionHeader(context.l10n.plannerCanvas_contingency_title),
            const Spacer(),
            HeaderInfoButton(
              title: context.l10n.plannerCanvas_contingency_title,
              content: (context) => planSectionInfo(
                context.l10n,
                infoUnits(context),
                title: context.l10n.plannerCanvas_contingency_title,
                summary: context.l10n.info_planner_contingencies_summary,
                terms: const [DiveTerm.turnPressure, DiveTerm.thirds],
              ),
            ),
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              size: 20,
              color: theme.colorScheme.outline,
            ),
          ],
        ),
      ),
      if (expanded)
        PlanResultSection<List<Widget>>(
          // Opening the section reloads from the collapsed empty list, which
          // is a first result for the diver, not an update to one.
          view: PlanResultView(
            value: rows.isEmpty ? null : rows,
            status: rows.isEmpty && status == PlanResultStatus.updating
                ? PlanResultStatus.calculating
                : status,
          ),
          builder: (rows) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: rows,
          ),
        ),
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

class _BailoutSection extends StatelessWidget {
  const _BailoutSection({required this.outcome, required this.units});

  final BailoutOutcome outcome;
  final UnitFormatter units;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Every figure below was sized on a gas past its MOD, so none of them is
    // shown: the error is the whole answer (#3961).
    if (outcome.gasGap case final gap?) {
      return PlanWarningRow(
        icon: Icons.error,
        color: theme.colorScheme.error,
        message: bailoutGasGapMessage(
          context.l10n,
          units,
          depthMeters: gap.depthMeters,
          deepestModMeters: gap.deepestModMeters,
        ),
      );
    }
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
          PlanWarningRow(
            icon: Icons.error,
            color: theme.colorScheme.error,
            message: context.l10n.plannerCanvas_bailout_insufficient,
          ),
        if (outcome.bailoutTankUsages.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final usage in outcome.bailoutTankUsages)
            PlanGasRow(
              usage: usage,
              label: () {
                final tank = outcome.bailoutTanks
                    .where((t) => t.id == usage.tankId)
                    .firstOrNull;
                return tank == null ? '--' : (tank.name ?? tank.gasMix.name);
              }(),
              units: units,
            ),
        ],
        if (outcome.worstCaseRows.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            context.l10n.plannerCanvas_bailout_schedule,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 4),
          _BailoutScheduleTable(rows: outcome.worstCaseRows, units: units),
        ],
      ],
    );
  }
}

/// The worst-case bailout point's schedule: depth/duration/RT/gas, read the
/// same way as the main decompression table (#3137).
class _BailoutScheduleTable extends StatelessWidget {
  const _BailoutScheduleTable({required this.rows, required this.units});

  final List<PlanScheduleRow> rows;
  final UnitFormatter units;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final lines = scheduleLines(rows);
    final headerStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.outline,
    );
    final switchStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w600,
    );

    Widget cell(String text, {TextStyle? style, int flex = 1}) => Expanded(
      flex: flex,
      child: Text(text, style: style ?? theme.textTheme.bodySmall),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(width: 16),
            cell(l10n.plannerCanvas_table_depth, style: headerStyle),
            cell(l10n.plannerCanvas_table_duration, style: headerStyle),
            cell(l10n.plannerCanvas_table_runtime, style: headerStyle),
            cell(l10n.plannerCanvas_table_gas, style: headerStyle, flex: 2),
            cell(l10n.plannerCanvas_table_ppO2, style: headerStyle),
            cell(l10n.plannerCanvas_table_end, style: headerStyle),
          ],
        ),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  child: Text(
                    scheduleRowGlyph(line.row.kind),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                cell(units.formatDepth(line.row.depthMeters, decimals: 0)),
                cell(line.durationLabel('′')),
                cell('${line.runtimeMinutes}′'),
                cell(
                  GasMix(
                    o2: line.row.gasFO2 * 100,
                    he: line.row.gasFHe * 100,
                  ).name,
                  style: line.row.gasSwitch ? switchStyle : null,
                  flex: 2,
                ),
                cell(line.row.ppO2.toStringAsFixed(2)),
                cell(units.formatDepth(line.row.endMeters, decimals: 0)),
              ],
            ),
          ),
      ],
    );
  }
}
