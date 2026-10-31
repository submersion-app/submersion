import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/features/equipment/domain/reports/cost_of_ownership.dart';
import 'package:submersion/features/insights/presentation/providers/equipment_report_insights_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/equipment/gear_report_row.dart';
import 'package:submersion/features/insights/presentation/widgets/stat_charts.dart';
import 'package:submersion/features/insights/presentation/widgets/stat_section_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What the diver's gear has cost: totals, spending by year and a ranked
/// list, one currency at a time because amounts never add across currencies.
class CostOfOwnershipSection extends ConsumerStatefulWidget {
  const CostOfOwnershipSection({super.key});

  @override
  ConsumerState<CostOfOwnershipSection> createState() =>
      _CostOfOwnershipSectionState();
}

class _CostOfOwnershipSectionState
    extends ConsumerState<CostOfOwnershipSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final costAsync = ref.watch(costOfOwnershipProvider);
    final chosen = ref.watch(costCurrencyProvider);
    final report = costAsync.value;
    final currencies = report?.byCurrency ?? const <CurrencyCost>[];

    return StatSectionCard(
      title: l10n.insights_equipment_cost_title,
      subtitle: l10n.insights_equipment_cost_subtitle,
      trailing: currencies.length > 1
          ? DropdownButton<String>(
              key: const ValueKey('cost-currency'),
              value: _shown(currencies, chosen).currency,
              underline: const SizedBox.shrink(),
              items: [
                for (final c in currencies)
                  DropdownMenuItem(value: c.currency, child: Text(c.currency)),
              ],
              onChanged: (code) =>
                  ref.read(costCurrencyProvider.notifier).state = code,
            )
          : null,
      child: costAsync.when(
        data: (data) => data.byCurrency.isEmpty
            ? StatEmptyState(
                icon: Icons.payments_outlined,
                message: l10n.insights_equipment_cost_empty,
              )
            : _body(l10n, data, _shown(data.byCurrency, chosen)),
        loading: () => const SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
        // A failed load is not a diver with no costs recorded.
        error: (_, _) => StatEmptyState(
          icon: Icons.error_outline,
          message: l10n.insights_equipment_cost_error,
        ),
      ),
    );
  }

  /// The chosen currency, or the largest when nothing is chosen or the
  /// choice has gone (its last priced item was deleted).
  CurrencyCost _shown(List<CurrencyCost> currencies, String? chosen) =>
      currencies.firstWhere(
        (c) => c.currency == chosen,
        orElse: () => currencies.first,
      );

  Widget _body(
    AppLocalizations l10n,
    CostOfOwnership report,
    CurrencyCost cost,
  ) {
    final theme = Theme.of(context);
    final metric = ref.watch(costMetricProvider);
    final rows = sortCostRows(cost.rows, metric);
    final noteStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 24,
          runSpacing: 8,
          children: [
            _headline(
              formatMoney(cost.total, cost.currency),
              l10n.insights_equipment_cost_spentTotal,
            ),
            if (cost.perDive != null)
              _headline(
                formatMoney(cost.perDive!, cost.currency),
                l10n.insights_equipment_cost_perDive,
              ),
          ],
        ),
        if (cost.byYear.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(l10n.insights_equipment_cost_byYear, style: noteStyle),
          const SizedBox(height: 8),
          CategoryBarChart(
            height: 140,
            data: [
              for (final bar in cost.byYear)
                (label: '${bar.year}', count: bar.amount.round()),
            ],
            valueFormatter: (value) =>
                formatMoney(value.toDouble(), cost.currency),
            compactXLabelFormatter: (year) => "'${year.substring(2)}",
          ),
        ],
        if (cost.undatedPurchases > 0)
          Text(
            l10n.insights_equipment_cost_undated(cost.undatedPurchases),
            style: noteStyle,
          ),
        if (rows.isNotEmpty) ...[
          const SizedBox(height: 8),
          DropdownButton<CostMetric>(
            key: const ValueKey('cost-metric'),
            value: metric,
            underline: const SizedBox.shrink(),
            items: [
              for (final m in CostMetric.values)
                DropdownMenuItem(value: m, child: Text(_metricLabel(l10n, m))),
            ],
            onChanged: (m) {
              if (m != null) ref.read(costMetricProvider.notifier).state = m;
            },
          ),
          for (final row in showAllSlice(rows, expanded: _expanded))
            GearReportRow(
              title: row.item.name,
              trailing: _figure(l10n, row, metric, cost.currency),
              subtitle: _detail(l10n, row, metric, cost.currency),
              onTap: () => context.push('/equipment/${row.item.id}'),
            ),
          GearReportShowAll(
            itemCount: rows.length,
            expanded: _expanded,
            showAllLabel: l10n.insights_equipment_showAll,
            showLessLabel: l10n.insights_equipment_showLess,
            onChanged: (value) => setState(() => _expanded = value),
          ),
        ],
        if (report.leftOutCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.insights_equipment_cost_leftOut(report.leftOutCount),
              style: noteStyle,
            ),
          ),
      ],
    );
  }

  Widget _headline(String value, String label) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  String _metricLabel(AppLocalizations l10n, CostMetric metric) =>
      switch (metric) {
        CostMetric.perDive => l10n.insights_equipment_cost_metricPerDive,
        CostMetric.perHour => l10n.insights_equipment_cost_metricPerHour,
        CostMetric.total => l10n.insights_equipment_cost_metricTotal,
      };

  String _figure(
    AppLocalizations l10n,
    CostRow row,
    CostMetric metric,
    String currency,
  ) => switch (metric) {
    CostMetric.perDive => switch (row.perDive) {
      final rate? => l10n.insights_equipment_cost_rowPerDive(
        formatMoney(rate, currency),
      ),
      null => l10n.insights_equipment_cost_noDives,
    },
    CostMetric.perHour => switch (row.perHour) {
      final rate? => l10n.insights_equipment_cost_rowPerHour(
        formatMoney(rate, currency),
      ),
      null => l10n.insights_equipment_cost_noDives,
    },
    CostMetric.total => formatMoney(row.cost, currency),
  };

  String? _detail(
    AppLocalizations l10n,
    CostRow row,
    CostMetric metric,
    String currency,
  ) {
    final cost = formatMoney(row.cost, currency);
    return switch (metric) {
      CostMetric.perHour when row.perHour != null =>
        l10n.insights_equipment_cost_rowOverHours(
          cost,
          // A real rate never reads "over 0 hours".
          math.max(1, row.hours.round()),
        ),
      CostMetric.perHour => cost,
      _ when row.diveCount > 0 => l10n.insights_equipment_cost_rowOverDives(
        cost,
        row.diveCount,
      ),
      CostMetric.total => null,
      CostMetric.perDive => cost,
    };
  }
}
