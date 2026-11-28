import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/utils/locale_number_symbols.dart';
import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_exposure_totals.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_usage_history.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/insights/presentation/widgets/category_bar_chart.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The exposure card's headline: when the item was last dived, its dives and
/// its hours, as numbers rather than chips (issue #5074). Last dived reads
/// "--" until the usage history has loaded.
class ExposureHeadline extends StatelessWidget {
  final EquipmentExposureTotals totals;
  final EquipmentUsageHistory? usage;
  final UnitFormatter units;

  const ExposureHeadline({
    super.key,
    required this.totals,
    required this.usage,
    required this.units,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ago = usage?.lastDivedAgo;
    final lastDive = usage?.lastDive;
    final agoText = ago == null ? '--' : lastDivedText(l10n, ago);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _StatTile(
            label: l10n.equipmentCondition_exposure_lastDivedLabel,
            value: agoText,
            semanticsLabel: ago == null || lastDive == null
                ? null
                : l10n.equipmentCondition_exposure_lastDivedSemantic(
                    agoText,
                    units.formatDate(lastDive),
                  ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            label: l10n.equipmentCondition_exposure_divesLabel,
            value: localeNumberFormat().format(totals.diveCount),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatTile(
            label: l10n.equipmentCondition_exposure_hoursLabel,
            // Grouped like the dives beside it, one decimal as on the chips.
            value: NumberFormat.decimalPatternDigits(
              locale: Intl.getCurrentLocale(),
              decimalDigits: 1,
            ).format(totals.byUnit[ExposureUnit.hours] ?? 0),
          ),
        ),
      ],
    );
  }
}

/// "Today", "3 days ago", "5 months ago" or "2 years ago".
String lastDivedText(
  AppLocalizations l10n,
  LastDivedAgo ago,
) => switch (ago.unit) {
  LastDivedUnit.today => l10n.equipmentCondition_exposure_today,
  LastDivedUnit.days => l10n.equipmentCondition_exposure_daysAgo(ago.count),
  LastDivedUnit.months => l10n.equipmentCondition_exposure_monthsAgo(ago.count),
  LastDivedUnit.years => l10n.equipmentCondition_exposure_yearsAgo(ago.count),
};

class _StatTile extends StatelessWidget {
  final String label;
  final String value;

  /// Replaces what a screen reader hears for the tile, when the value alone
  /// leaves something out (the exact date behind "5 months ago").
  final String? semanticsLabel;

  const _StatTile({
    required this.label,
    required this.value,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tile = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              maxLines: 1,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    final semantics = semanticsLabel;
    if (semantics == null) return tile;
    return Semantics(label: semantics, excludeSemantics: true, child: tile);
  }
}

enum _UsageRange { months, years }

/// Dives per month over the last twelve months, ending this month, or per
/// year over the item's life: empty bars at the right show idle time
/// (issue #5074). The range is not saved; every page opens on months.
class ExposureUsageChart extends StatefulWidget {
  final EquipmentUsageHistory history;
  final UnitFormatter units;

  const ExposureUsageChart({
    super.key,
    required this.history,
    required this.units,
  });

  @override
  State<ExposureUsageChart> createState() => _ExposureUsageChartState();
}

class _ExposureUsageChartState extends State<ExposureUsageChart> {
  var _range = _UsageRange.months;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = widget.units;
    final months = _range == _UsageRange.months;
    final buckets = months ? widget.history.monthly : widget.history.yearly;
    String period(UsageBucket b) =>
        months ? units.formatMonthYear(b.start) : '${b.start.year}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<_UsageRange>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: [
            ButtonSegment(
              value: _UsageRange.months,
              label: Text(l10n.equipmentCondition_exposure_range12Months),
            ),
            ButtonSegment(
              value: _UsageRange.years,
              label: Text(l10n.equipmentCondition_exposure_rangeAllYears),
            ),
          ],
          selected: {_range},
          onSelectionChanged: (s) => setState(() => _range = s.single),
        ),
        const SizedBox(height: 12),
        CategoryBarChart(
          height: 160,
          barColor: theme.colorScheme.primary,
          data: [
            for (final b in buckets)
              (
                label: months
                    ? units.formatMonthOnly(b.start)
                    : '${b.start.year}',
                count: b.dives,
              ),
          ],
          // Years shorten to "'24" when crowded; months are already short.
          // Whatever still collides is thinned, keeping the latest label.
          compactXLabelFormatter: months
              ? null
              : (label) => "'${label.substring(label.length - 2)}",
          compactXLabelsToFit: true,
          thinXLabelsToFit: true,
          tooltipText: (i) => l10n.equipmentCondition_exposure_barTooltip(
            period(buckets[i]),
            l10n.equipmentCondition_exposure_dives(buckets[i].dives),
            l10n.equipmentCondition_exposure_hours(
              formatFixedForDisplay(buckets[i].hours, 1),
            ),
          ),
        ),
        if (months) ...[
          const SizedBox(height: 4),
          Text(
            l10n.equipmentCondition_exposure_last12Months(
              widget.history.divesLast12Months,
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
