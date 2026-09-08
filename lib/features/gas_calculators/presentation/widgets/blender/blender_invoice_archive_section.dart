import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gas_calculators/domain/blending/billed_fill.dart';
import 'package:submersion/features/gas_calculators/domain/blending/invoice_archive_period.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_blender_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_archive_totals_summary.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_archived_invoice_tile.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A collapsible read of [blenderArchivedInvoicesProvider], shown right below
/// the running bill so a fill station can glance at past receipts without
/// leaving the calculator for the full archive page (issue #44).
///
/// That page - `BlenderInvoiceArchivePage`, and its history-icon entry point
/// in `BlenderInvoiceCard._dateHeader` - stays untouched: this section has no
/// date-range picker of its own, only the year/month filter below and the
/// total for whatever it currently narrows the list down to. Hidden entirely
/// once nothing has been paid yet, same as the card sections above it that
/// have nothing to show.
class BlenderInvoiceArchiveSection extends ConsumerStatefulWidget {
  const BlenderInvoiceArchiveSection({super.key});

  @override
  ConsumerState<BlenderInvoiceArchiveSection> createState() =>
      _BlenderInvoiceArchiveSectionState();
}

class _BlenderInvoiceArchiveSectionState
    extends ConsumerState<BlenderInvoiceArchiveSection> {
  /// Local rather than a provider, matching ServiceHistorySection: a view of
  /// this card, not state that needs to outlive it.
  bool _expanded = false;

  /// Null means "not chosen yet" - resolved to the newest year/month on file
  /// below, distinct from the user explicitly picking the "all" option
  /// (which is a real, non-null filter value with a null year/month).
  BlenderInvoiceArchiveYearFilter? _selectedYear;
  BlenderInvoiceArchiveMonthFilter? _selectedMonth;

  void _onYearChanged(BlenderInvoiceArchiveYearFilter year) {
    setState(() {
      _selectedYear = year;
      // The month options depend on the year, so a month picked under the
      // previous year no longer applies - re-derive the default below.
      _selectedMonth = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final invoices = ref.watch(blenderArchivedInvoicesProvider);
    if (invoices.isEmpty) return const SizedBox.shrink();

    final yearFilters = blenderInvoiceArchiveYearFilters(invoices);
    final effectiveYear =
        _selectedYear != null && yearFilters.contains(_selectedYear)
        ? _selectedYear!
        // The newest actual year, not "all years" - matches the previous
        // single-stage filter's default of narrowing to the latest bucket.
        : yearFilters.firstWhere((f) => !f.isAll);

    final monthFilters = blenderInvoiceArchiveMonthFilters(
      invoices,
      effectiveYear,
    );
    final effectiveMonth =
        _selectedMonth != null && monthFilters.contains(_selectedMonth)
        ? _selectedMonth!
        // "All years" mixes every year's invoices together, so the highest
        // month number on file is not necessarily the most recent invoice -
        // default to "all months" there instead of a misleading pick.
        : effectiveYear.isAll
        ? const BlenderInvoiceArchiveMonthFilter.all()
        : monthFilters.firstWhere(
            (f) => !f.isAll,
            // Only "all months" is on offer if a year has invoices in just
            // one month - still a real option, so fall back to it here.
            orElse: () => monthFilters.first,
          );

    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final fallbackCurrency = ref.watch(blenderCurrencyProvider);
    final visible =
        invoices
            .where(
              (invoice) =>
                  effectiveYear.matches(invoice.date) &&
                  effectiveMonth.matches(invoice.date),
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    final totals = sumByCurrency<ArchivedInvoice>(
      visible,
      amountOf: (i) => i.total,
      currencyOf: (i) => i.currencyCode ?? fallbackCurrency,
      fallbackCode: fallbackCurrency,
    ).where((e) => e.value > 0).toList();

    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              key: const Key('blender-invoice-archive-section-toggle'),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.gasCalculators_blender_invoiceArchive,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
            if (_expanded) ...[
              const Divider(),
              _YearMonthFilterRow(
                yearFilters: yearFilters,
                selectedYear: effectiveYear,
                onYearChanged: _onYearChanged,
                monthFilters: monthFilters,
                selectedMonth: effectiveMonth,
                onMonthChanged: (month) =>
                    setState(() => _selectedMonth = month),
              ),
              const SizedBox(height: 4),
              for (final invoice in visible)
                BlenderArchivedInvoiceTile(
                  key: ValueKey(
                    'blender-invoice-archive-section-${invoice.id}',
                  ),
                  invoice: invoice,
                  units: units,
                  fallbackCurrency: fallbackCurrency,
                ),
              BlenderArchiveTotalsSummary(totals: totals),
            ],
          ],
        ),
      ),
    );
  }
}

/// The year and month filter dropdowns, side by side. The month dropdown's
/// options are re-derived by the parent for every [selectedYear], so picking
/// a year narrows what the month dropdown can offer next.
class _YearMonthFilterRow extends StatelessWidget {
  const _YearMonthFilterRow({
    required this.yearFilters,
    required this.selectedYear,
    required this.onYearChanged,
    required this.monthFilters,
    required this.selectedMonth,
    required this.onMonthChanged,
  });

  final List<BlenderInvoiceArchiveYearFilter> yearFilters;
  final BlenderInvoiceArchiveYearFilter selectedYear;
  final ValueChanged<BlenderInvoiceArchiveYearFilter> onYearChanged;
  final List<BlenderInvoiceArchiveMonthFilter> monthFilters;
  final BlenderInvoiceArchiveMonthFilter selectedMonth;
  final ValueChanged<BlenderInvoiceArchiveMonthFilter> onMonthChanged;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: _FilterDropdown<BlenderInvoiceArchiveYearFilter>(
            filterKey: 'blender-invoice-archive-section-year',
            value: selectedYear,
            items: yearFilters,
            onChanged: onYearChanged,
            label: (filter) => filter.isAll
                ? l10n.gasCalculators_blender_invoiceArchiveAllYears
                : DateFormat.y(locale).format(DateTime(filter.year!)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _FilterDropdown<BlenderInvoiceArchiveMonthFilter>(
            filterKey: 'blender-invoice-archive-section-month',
            value: selectedMonth,
            items: monthFilters,
            onChanged: onMonthChanged,
            label: (filter) => filter.isAll
                ? l10n.gasCalculators_blender_invoiceArchiveAllMonths
                // The year only has to be valid, not meaningful - DateFormat
                // "MMMM" reads the month alone.
                : DateFormat.MMMM(locale).format(DateTime(2000, filter.month!)),
          ),
        ),
      ],
    );
  }
}

/// Bordered container with the underline suppressed, matching
/// ServiceHistorySection's filter dropdowns.
class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.filterKey,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.label,
  });

  final String filterKey;
  final T value;
  final List<T> items;
  final ValueChanged<T> onChanged;
  final String Function(T item) label;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key(filterKey),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<T>(
        value: value,
        underline: const SizedBox(),
        isDense: true,
        isExpanded: true,
        items: [
          for (final item in items)
            DropdownMenuItem(value: item, child: Text(label(item))),
        ],
        onChanged: (item) {
          if (item != null) onChanged(item);
        },
      ),
    );
  }
}
