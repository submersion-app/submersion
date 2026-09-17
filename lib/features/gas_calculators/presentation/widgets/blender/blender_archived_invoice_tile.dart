import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gas_calculators/domain/blending/billed_fill.dart';
import 'package:submersion/features/gas_calculators/presentation/gas_calculator_tools.dart';
import 'package:submersion/features/gas_calculators/presentation/providers/gas_blender_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One archived bill's summary row: date, who it was billed to, fill count
/// and total, opening onto its read-only detail on tap.
///
/// Shared by [BlenderInvoiceArchivePage]'s full list and
/// [BlenderInvoiceArchiveSection]'s inline glance, so the two views never
/// drift apart on what a row shows (issue #44).
class BlenderArchivedInvoiceTile extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            total == null
                ? l10n.gasCalculators_blender_invoiceArchiveIncomplete
                : formatMoney(total, invoice.currencyCode ?? fallbackCurrency),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          IconButton(
            key: Key('blender-archived-invoice-delete-${invoice.id}'),
            icon: const Icon(Icons.delete_outline, size: 20),
            visualDensity: VisualDensity.compact,
            tooltip: l10n.gasCalculators_blender_invoiceArchiveDelete,
            onPressed: () => deleteArchivedInvoice(context, ref, invoice.id),
          ),
        ],
      ),
      onTap: () => context.push('$kBlenderInvoiceArchiveRoute/${invoice.id}'),
    );
  }
}

/// Removes [invoiceId] from the archive after confirmation, shared by the
/// list tile and the detail page's app bar action so both delete the same
/// way (issue #1876).
Future<void> deleteArchivedInvoice(
  BuildContext context,
  WidgetRef ref,
  String invoiceId,
) async {
  final l10n = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.gasCalculators_blender_invoiceArchiveDeleteTitle),
      content: Text(l10n.gasCalculators_blender_invoiceArchiveDeleteBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.common_action_close),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.common_action_delete),
        ),
      ],
    ),
  );
  if (ok != true) return;

  ref.read(blenderArchivedInvoicesProvider.notifier).state = [
    ...ref
        .read(blenderArchivedInvoicesProvider)
        .where((i) => i.id != invoiceId),
  ];
  await saveBlenderPreferences(ref);
}
