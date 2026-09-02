import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_3d/domain/metric_palette.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/dive_readout_rows.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Compact readout for a hovered or tapped path sample: every metric the
/// dive carries at that instant, with the Z-axis metric emphasized.
class DiveHoverTooltip extends ConsumerWidget {
  /// Shared with the readout panel: the tooltip rebuilds on every hover
  /// move, so it must not rebuild the tank-pressure lookups either.
  final DiveReadoutLookups lookups;
  final double timestampSeconds;
  final SceneMetric? emphasize;

  const DiveHoverTooltip({
    super.key,
    required this.lookups,
    required this.timestampSeconds,
    this.emphasize,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = UnitFormatter(ref.watch(settingsProvider));
    final rows = diveReadoutRows(
      lookups: lookups,
      timestampSeconds: timestampSeconds,
      units: units,
      l10n: context.l10n,
      emphasize: emphasize,
    );
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme.labelSmall;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          children: [
            for (final row in rows)
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Text(
                      row.label,
                      style: text?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                  Text(
                    row.value,
                    style: text?.copyWith(
                      fontWeight: row.emphasized
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: row.emphasized ? scheme.primary : null,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
