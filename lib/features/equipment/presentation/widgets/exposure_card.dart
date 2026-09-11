import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_exposure_totals.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_exposure_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What the item has been through: one chip per exposure unit with a
/// non-zero total, and the dive count and date range they cover. Derived
/// on read with the diver's current thresholds (condition phase 4a).
class ExposureCard extends ConsumerWidget {
  final String equipmentId;

  const ExposureCard({super.key, required this.equipmentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final totalsAsync = ref.watch(equipmentExposureTotalsProvider(equipmentId));

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
                Text(
                  l10n.equipmentCondition_exposure_title,
                  style: theme.textTheme.titleMedium,
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
              data: (totals) => _body(context, l10n, units, totals),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final unit in ExposureUnit.values)
              if (totals.byUnit[unit] case final total?)
                if (_chipText(l10n, unit, total) case final text?)
                  Chip(label: Text(text)),
          ],
        ),
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
  /// trigger owns and which has no usage total, so no chip is drawn.
  String? _chipText(AppLocalizations l10n, ExposureUnit unit, double total) {
    final hours = formatFixedForDisplay(total, 1);
    final count = total.round();
    return switch (unit) {
      ExposureUnit.days => null,
      ExposureUnit.dives => l10n.equipmentCondition_exposure_dives(count),
      ExposureUnit.hours => l10n.equipmentCondition_exposure_hours(hours),
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
