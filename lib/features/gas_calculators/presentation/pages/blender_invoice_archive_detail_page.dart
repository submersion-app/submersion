import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gas_calculators/domain/blending/billed_fill.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_blender_providers.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_billed_line_row.dart';
import 'package:submersion/features/gas_calculators/presentation/widgets/blender/blender_formatting.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One archived bill, read only: every fill it was paid for, itemised the
/// same way the running bill is.
///
/// Looks the invoice up in the full, unfiltered
/// [blenderArchivedInvoicesProvider] rather than the filtered list the diver
/// tapped from, so a deep link (or a filter changed after navigating) still
/// resolves it.
class BlenderInvoiceArchiveDetailPage extends ConsumerWidget {
  const BlenderInvoiceArchiveDetailPage({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Without this the deep link promised above resolves against an archive
    // that is still empty, and every id reads as "not found" (PR #1359
    // review). See BlenderInvoiceArchivePage for the same reasoning.
    ref.watch(blenderPreferencesLoaderProvider);
    final l10n = context.l10n;
    final invoices = ref.watch(blenderArchivedInvoicesProvider);
    ArchivedInvoice? invoice;
    for (final candidate in invoices) {
      if (candidate.id == invoiceId) {
        invoice = candidate;
        break;
      }
    }

    if (invoice == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.gasCalculators_blender_invoiceArchive)),
        body: Center(
          child: Text(l10n.gasCalculators_blender_invoiceArchiveNotFound),
        ),
      );
    }

    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final decimals = pressureDecimalsFor(settings.pressureUnit);
    final fallbackCurrency = ref.watch(blenderCurrencyProvider);
    final currency = invoice.currencyCode ?? fallbackCurrency;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.gasCalculators_blender_billedDate(
            units.formatDate(invoice.date),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (invoice.billedTo.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '${l10n.gasCalculators_blender_billedTo}: ${invoice.billedTo}',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          for (final fill in invoice.fills)
            _fillSection(theme, fill, currency, units, decimals),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.gasCalculators_blender_billedTotal,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                invoice.total == null
                    ? l10n.gasCalculators_blender_invoiceArchiveIncomplete
                    : formatMoney(invoice.total!, currency),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fillSection(
    ThemeData theme,
    BilledFill fill,
    String currency,
    UnitFormatter units,
    int decimals,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  fill.label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                fill.total == null ? '' : formatMoney(fill.total!, currency),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          for (final line in fill.lines)
            BlenderBilledLineRow(
              line: line,
              currency: currency,
              units: units,
              decimals: decimals,
            ),
        ],
      ),
    );
  }
}
