import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_3d/domain/metric_palette.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/dive_readout_rows.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Live metric readout at the scrub instant. Listens to the frame-rate
/// ValueListenable directly (NOT via Riverpod) so playback never rebuilds
/// the page tree above it. Shares its rows with the hover tooltip.
///
/// [lookups] is injected rather than built here: its builder runs on every
/// playback tick, and rebuilding the tank-pressure lookups there would
/// allocate a copy of each tank series per frame.
class SceneReadoutPanel extends ConsumerWidget {
  final DiveReadoutLookups lookups;
  final ValueListenable<double> position;
  final SceneMetric? emphasize;

  const SceneReadoutPanel({
    super.key,
    required this.lookups,
    required this.position,
    this.emphasize,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = UnitFormatter(ref.watch(settingsProvider));
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme.bodySmall;
    return ValueListenableBuilder<double>(
      valueListenable: position,
      builder: (context, value, _) {
        final rows = diveReadoutRows(
          lookups: lookups,
          timestampSeconds: value * lookups.data.durationSeconds,
          units: units,
          l10n: l10n,
          emphasize: emphasize,
        );
        return DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                for (final row in rows)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${row.label} ',
                        style: text?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      Text(
                        row.value,
                        style: text?.copyWith(
                          fontWeight: row.emphasized
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: row.emphasized ? scheme.primary : null,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
