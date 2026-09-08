import 'package:flutter/material.dart';

import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One total per currency for a set of archived invoices, in descending
/// order of amount - grouped rather than added together, so a mix of
/// currencies never collapses into a single misleading figure.
///
/// Shared by [BlenderInvoiceArchivePage]'s full list and
/// [BlenderInvoiceArchiveSection]'s inline glance, so the two totals never
/// drift apart on how they are computed or shown (issue #44).
class BlenderArchiveTotalsSummary extends StatelessWidget {
  const BlenderArchiveTotalsSummary({super.key, required this.totals});

  /// Currency code to summed amount, already filtered to positive totals.
  final List<MapEntry<String, double>> totals;

  @override
  Widget build(BuildContext context) {
    if (totals.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    return Container(
      key: const Key('blender-archive-totals-summary'),
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          for (final entry in totals)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.gasCalculators_blender_billedTotal,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  formatMoney(entry.value, entry.key),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
