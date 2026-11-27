import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_exposure_totals.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_usage_history.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/presentation/info/equipment_info.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_exposure_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/exposure_usage_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/info_sheet/info_button.dart';
import 'package:submersion/shared/widgets/info_sheet/info_units.dart';

/// What the item has been through: when it was last dived, its dives and
/// hours as numbers, a usage chart (issue #5074), one chip per other
/// exposure unit with a non-zero total, and the dive count and date range
/// they cover. Derived on read with the diver's current thresholds
/// (condition phase 4a).
class ExposureCard extends ConsumerWidget {
  final String equipmentId;

  const ExposureCard({super.key, required this.equipmentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = ref.watch(unitFormatterProvider);
    final totalsAsync = ref.watch(equipmentExposureTotalsProvider(equipmentId));
    // A failed or pending history leaves the totals standing: the tiles
    // show "--" for last dived and the chart is left out.
    final usage = ref.watch(equipmentUsageHistoryProvider(equipmentId)).value;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.waves, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.equipmentCondition_exposure_title,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                HeaderInfoButton(
                  title: l10n.equipmentCondition_exposure_title,
                  // The units the card shows when tapped: the dives and
                  // hours tiles and the other units' chips.
                  content: (context) => equipmentExposureInfo(
                    context.l10n,
                    infoUnits(context),
                    shown: totalsAsync.value?.byUnit.keys.toSet() ?? const {},
                  ),
                ),
              ],
            ),
            const Divider(),
            totalsAsync.when(
              loading: () => const SizedBox(height: 32),
              // A localized retry line: the raw exception is neither
              // translated nor something a diver can act on.
              error: (_, _) => Padding(
                padding: const EdgeInsets.all(8),
                child: Text(l10n.common_error_tryAgain),
              ),
              data: (totals) => _body(context, l10n, units, totals, usage),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations l10n,
    UnitFormatter units,
    EquipmentExposureTotals totals,
    EquipmentUsageHistory? usage,
  ) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    if (totals.diveCount == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(l10n.equipmentCondition_exposure_empty, style: muted),
      );
    }
    final chips = [
      for (final unit in ExposureUnit.values)
        if (totals.byUnit[unit] case final total?)
          if (_chipText(l10n, unit, total) case final text?)
            Chip(label: Text(text)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        ExposureHeadline(totals: totals, usage: usage, units: units),
        if (usage != null && !usage.isEmpty) ...[
          const SizedBox(height: 16),
          // Keyed by the item: the detail pane swaps items in place, and
          // each item opens on 12 months, never on the last one's range.
          ExposureUsageChart(
            key: ValueKey(equipmentId),
            history: usage,
            units: units,
          ),
        ],
        if (chips.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 4, children: chips),
        ],
        const SizedBox(height: 8),
        Text(
          l10n.equipmentCondition_exposure_footer(
            totals.diveCount,
            units.formatDateRange(
              totals.firstDive,
              totals.lastDive,
              l10n: l10n,
            ),
          ),
          style: muted,
        ),
      ],
    );
  }

  /// Hours keep one decimal; counts are whole. Null for days, which a date
  /// trigger owns and which has no usage total, and for dives and hours,
  /// which the headline tiles carry, so no chip is drawn.
  String? _chipText(AppLocalizations l10n, ExposureUnit unit, double total) {
    final hours = formatFixedForDisplay(total, 1);
    final count = total.round();
    return switch (unit) {
      ExposureUnit.days || ExposureUnit.dives || ExposureUnit.hours => null,
      ExposureUnit.saltHours => l10n.equipmentCondition_exposure_saltHours(
        hours,
      ),
      ExposureUnit.coldDives => l10n.equipmentCondition_exposure_coldDives(
        count,
      ),
      ExposureUnit.o2Hours => l10n.equipmentCondition_exposure_o2Hours(hours),
      ExposureUnit.deepCycles => l10n.equipmentCondition_exposure_deepCycles(
        count,
      ),
      ExposureUnit.cycles => l10n.equipmentCondition_exposure_cycles(count),
    };
  }
}
