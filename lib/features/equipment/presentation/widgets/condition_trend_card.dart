import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/condition_trend.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/condition_trend_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_finding.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_condition_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/statistics/presentation/widgets/dive_trend_chart.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The item's per-dive condition chart: cell gain per slot, transmitter
/// dropout share, scrubber minutes, or minimum temperature with the
/// issue dives marked. The finding selected in the findings card shades
/// its evidence window. Renders nothing for a type with no trend or an
/// item with no data, so the page adds no gap for it.
class ConditionTrendCard extends ConsumerWidget {
  final EquipmentItem equipment;

  /// Null draws the type's default trend; a rebreather page passes
  /// [ConditionTrendKind.scrubberMinutes] for its second card.
  final ConditionTrendKind? kind;

  const ConditionTrendCard({super.key, required this.equipment, this.kind});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trend = ref
        .watch(conditionTrendProvider((equipmentId: equipment.id, kind: kind)))
        .value;
    if (trend == null || trend.isEmpty) return const SizedBox.shrink();

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    // The selection is a snapshot. Shade the finding as it is now, and
    // only while the findings card still shows it: the master switch and
    // the rule toggles hide findings without clearing the selection.
    final selectedId = ref
        .watch(selectedConditionFindingProvider(equipment.id))
        ?.id;
    final selected = selectedId == null || !settings.conditionEngineEnabled
        ? null
        : (ref.watch(equipmentConditionProvider(equipment.id)).value ??
                  const <EquipmentFinding>[])
              .where(
                (f) =>
                    f.id == selectedId &&
                    !settings.conditionDisabledRules.contains(f.ruleId.dbValue),
              )
              .firstOrNull;
    final palette = _palette(theme.colorScheme);

    final series = <TrendSeries>[
      for (final (i, s) in trend.series.indexed)
        if (s.points.isNotEmpty)
          TrendSeries(
            // A series without a slot (legacy) is named and coloured by its
            // position, never as a "Cell 0".
            label: _seriesLabel(l10n, trend.kind, s, s.slot ?? i + 1),
            points: s.points,
            // A cell's colour follows its slot, so a lone slot-2 cell does
            // not borrow slot 1's and the legend holds as series come and go.
            color: s.key == 'issues'
                ? theme.colorScheme.error
                : palette[((s.slot ?? i + 1) - 1) % palette.length],
          ),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.show_chart, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _title(l10n, trend.kind),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const Divider(),
              DiveTrendChart(
                points: const [],
                secondarySeries: series,
                highlightRange: selected == null
                    ? null
                    : (
                        start: selected.evidence.windowStart,
                        end: selected.evidence.windowEnd,
                      ),
                yAxisLabel: _axisLabel(l10n, trend.kind, units),
                valueFormatter: (v) => _formatValue(trend.kind, units, v),
                height: 180,
                chartId: 'condition-${trend.kind.name}',
                dateFormat: settings.dateFormat,
                onDiveSelected: (diveId) => context.push('/dives/$diveId'),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  for (final s in series)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 10, color: s.color),
                        const SizedBox(width: 4),
                        Text(s.label, style: theme.textTheme.bodySmall),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Six slot colours from the theme so cell 1 reads the same on every
  /// rebreather page.
  List<Color> _palette(ColorScheme scheme) => [
    scheme.primary,
    scheme.tertiary,
    scheme.secondary,
    scheme.primaryContainer,
    scheme.tertiaryContainer,
    scheme.secondaryContainer,
  ];

  String _title(AppLocalizations l10n, ConditionTrendKind kind) =>
      switch (kind) {
        ConditionTrendKind.cellGain =>
          l10n.equipmentCondition_trend_title_cellGain,
        ConditionTrendKind.transmitterGapFraction =>
          l10n.equipmentCondition_trend_title_gap,
        ConditionTrendKind.scrubberMinutes =>
          l10n.equipmentCondition_trend_title_scrubber,
        ConditionTrendKind.minTemperature =>
          l10n.equipmentCondition_trend_title_temperature,
      };

  String _seriesLabel(
    AppLocalizations l10n,
    ConditionTrendKind kind,
    ConditionTrendSeries s,
    int slot,
  ) {
    if (s.key == 'issues') return l10n.equipmentCondition_trend_issues;
    return switch (kind) {
      ConditionTrendKind.cellGain => l10n.equipmentCondition_trend_cell(slot),
      ConditionTrendKind.transmitterGapFraction =>
        l10n.equipmentCondition_trend_gap,
      ConditionTrendKind.scrubberMinutes =>
        l10n.equipmentCondition_trend_scrubber,
      ConditionTrendKind.minTemperature =>
        l10n.equipmentCondition_trend_temperature,
    };
  }

  String _axisLabel(
    AppLocalizations l10n,
    ConditionTrendKind kind,
    UnitFormatter units,
  ) => switch (kind) {
    ConditionTrendKind.cellGain => 'mV/bar',
    ConditionTrendKind.transmitterGapFraction => '%',
    ConditionTrendKind.scrubberMinutes =>
      l10n.equipmentCondition_trend_axis_minutes,
    ConditionTrendKind.minTemperature => units.temperatureSymbol,
  };

  /// Temperatures are stored in Celsius and shown in the diver's unit;
  /// the gap fraction reads as a whole percentage.
  String _formatValue(ConditionTrendKind kind, UnitFormatter units, double v) =>
      switch (kind) {
        ConditionTrendKind.cellGain => v.toStringAsFixed(0),
        ConditionTrendKind.transmitterGapFraction =>
          (v * 100).round().toString(),
        ConditionTrendKind.scrubberMinutes => v.toStringAsFixed(0),
        ConditionTrendKind.minTemperature =>
          units.convertTemperature(v).toStringAsFixed(0),
      };
}
