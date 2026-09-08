import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gas_calculators/domain/blending/billed_fill.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_blender_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_archive_totals_summary.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_archived_invoice_tile.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_date_picker.dart';

/// Every bill the blender has marked paid: filterable by date, totalled by
/// currency, each row opening onto its own itemisation.
///
/// See issue #22 - this is deliberately the smallest useful reader over
/// [BlenderPreferences.archivedInvoices]; deeper history features (search,
/// export of the archive itself) build on top of it rather than in it.
class BlenderInvoiceArchivePage extends ConsumerWidget {
  const BlenderInvoiceArchivePage({super.key});

  Future<void> _pickRange(BuildContext context, WidgetRef ref) async {
    final settings = ref.read(settingsProvider);
    final picked = await showAppDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: ref.read(blenderInvoiceArchiveFilterProvider),
      dateFormat: settings.dateFormat,
    );
    if (picked == null) return;
    ref.read(blenderInvoiceArchiveFilterProvider.notifier).state = picked;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // This route stands on its own: a deep link, a route restored on
    // relaunch, or the history icon tapped from a calculator that was never
    // opened this session all reach it without GasBlenderCalculator ever
    // mounting, and the archive lives in a provider that stays at its empty
    // default until this load runs (PR #1359 review). Watching it here is the
    // same contract BlenderSettingsPage keeps for its own fields.
    ref.watch(blenderPreferencesLoaderProvider);
    final l10n = context.l10n;
    final invoices = ref.watch(filteredBlenderArchivedInvoicesProvider);
    final allInvoices = ref.watch(blenderArchivedInvoicesProvider);
    final range = ref.watch(blenderInvoiceArchiveFilterProvider);
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final fallbackCurrency = ref.watch(blenderCurrencyProvider);

    // Summed from the already-filtered rows so the total on screen matches
    // what is actually listed below it, the same reasoning as
    // ServiceHistorySection's total (#1236). A row archived before the
    // currency snapshot existed falls back to the currency configured today,
    // the best guess available for it.
    final totals = sumByCurrency<ArchivedInvoice>(
      invoices,
      amountOf: (i) => i.total,
      currencyOf: (i) => i.currencyCode ?? fallbackCurrency,
      fallbackCode: fallbackCurrency,
    ).where((e) => e.value > 0).toList();

    final hiddenByFilter = range != null && allInvoices.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.gasCalculators_blender_invoiceArchive),
        actions: [
          IconButton(
            key: const Key('blender-invoice-archive-filter'),
            icon: Badge(
              isLabelVisible: range != null,
              child: const Icon(Icons.filter_list),
            ),
            tooltip: l10n.gasCalculators_blender_invoiceArchiveFilter,
            onPressed: () => _pickRange(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          if (range != null) _ActiveFilterBar(range: range, units: units),
          if (totals.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: BlenderArchiveTotalsSummary(totals: totals),
            ),
          Expanded(
            child: invoices.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        hiddenByFilter
                            ? l10n.gasCalculators_blender_invoiceArchiveEmptyFiltered
                            : l10n.gasCalculators_blender_invoiceArchiveEmpty,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: invoices.length,
                    itemBuilder: (context, index) => BlenderArchivedInvoiceTile(
                      invoice: invoices[index],
                      units: units,
                      fallbackCurrency: fallbackCurrency,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ActiveFilterBar extends ConsumerWidget {
  const _ActiveFilterBar({required this.range, required this.units});

  final DateTimeRange range;
  final UnitFormatter units;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: Chip(
              label: Text(
                '${units.formatDate(range.start)} - '
                '${units.formatDate(range.end)}',
              ),
              visualDensity: VisualDensity.compact,
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: () =>
                  ref.read(blenderInvoiceArchiveFilterProvider.notifier).state =
                      null,
            ),
          ),
        ],
      ),
    );
  }
}
