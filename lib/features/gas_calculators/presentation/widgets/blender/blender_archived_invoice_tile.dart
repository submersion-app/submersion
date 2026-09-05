import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gas_calculators/domain/blending/billed_fill.dart';
import 'package:submersion/features/gas_calculators/presentation/gas_calculator_tools.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One archived bill's summary row: date, who it was billed to, fill count
/// and total, opening onto its read-only detail on tap.
///
/// Shared by [BlenderInvoiceArchivePage]'s full list and
/// [BlenderInvoiceArchiveSection]'s inline glance, so the two views never
/// drift apart on what a row shows (issue #44).
class BlenderArchivedInvoiceTile extends StatelessWidget {
  const BlenderArchivedInvoiceTile({
    super.key,
    required this.invoice,
    required this.units,
    required this.fallbackCurrency,
  });

  final ArchivedInvoice invoice;
  final UnitFormatter units;
  final String fallbackCurrency;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final total = invoice.total;
    return ListTile(
      leading: const Icon(Icons.receipt_long_outlined),
      title: Text(
        invoice.billedTo.isEmpty
            ? l10n.gasCalculators_blender_invoiceArchiveUntitled
            : invoice.billedTo,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${units.formatDate(invoice.date)} - '
        '${l10n.gasCalculators_blender_invoiceArchiveFillCount(invoice.fills.length)}',
      ),
      trailing: Text(
        total == null
            ? l10n.gasCalculators_blender_invoiceArchiveIncomplete
            : formatMoney(total, invoice.currencyCode ?? fallbackCurrency),
        style: Theme.of(context).textTheme.titleSmall,
      ),
      onTap: () => context.push('$kBlenderInvoiceArchiveRoute/${invoice.id}'),
    );
  }
}
