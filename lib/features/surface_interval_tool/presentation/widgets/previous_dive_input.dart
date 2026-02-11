import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/surface_interval_tool/presentation/providers/surface_interval_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Input card for the first (previous) dive parameters.
/// Allows setting depth, time, and gas mix (O2/He percentages).
class PreviousDiveInput extends ConsumerWidget {
  const PreviousDiveInput({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    final depth = ref.watch(siFirstDiveDepthProvider);
    final time = ref.watch(siFirstDiveTimeProvider);
    final o2 = ref.watch(siFirstDiveO2Provider);
    final he = ref.watch(siFirstDiveHeProvider);

    // Convert depth for display
    final displayDepth = units.convertDepth(depth);
    final maxDisplayDepth = units.convertDepth(60.0);
    final depthSymbol = units.depthSymbol;

    // Determine gas mix name
    String gasName;
    if (he > 0) {
      gasName = context.l10n.surfaceInterval_gasMix_trimix(
        o2.toInt(),
        he.toInt(),
      );
    } else if (o2 > 21.5) {
      gasName = context.l10n.surfaceInterval_gasMix_ean(o2.toInt());
    } else {
      gasName = context.l10n.surfaceInterval_gasMix_air;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.looks_one,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  context.l10n.surfaceInterval_firstDive_title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Depth Slider
            _buildSliderRow(
              context: context,
              label: context.l10n.surfaceInterval_field_depth,
              icon: Icons.arrow_downward,
              value: '${displayDepth.toStringAsFixed(0)} $depthSymbol',
              slider: Semantics(
                label: context.l10n.surfaceInterval_firstDive_depthSemantics(
                  displayDepth.toStringAsFixed(0),
                  depthSymbol,
                ),
                child: Slider(
                  value: depth,
                  min: 6,
                  max: 60,
                  divisions: 54,
                  onChanged: (value) {
                    ref.read(siFirstDiveDepthProvider.notifier).state = value;
                  },
                ),
              ),
              minLabel:
                  '${units.convertDepth(6).toStringAsFixed(0)} $depthSymbol',
              maxLabel: '${maxDisplayDepth.toStringAsFixed(0)} $depthSymbol',
            ),
            const SizedBox(height: 16),

            // Time Slider
            _buildSliderRow(
              context: context,
              label: context.l10n.surfaceInterval_field_time,
              icon: Icons.timer,
              value: context.l10n.surfaceInterval_format_minutes(time),
              slider: Semantics(
                label: context.l10n.surfaceInterval_firstDive_timeSemantics(
                  time,
                ),
                child: Slider(
                  value: time.toDouble(),
                  min: 5,
                  max: 120,
                  divisions: 23,
                  onChanged: (value) {
                    ref.read(siFirstDiveTimeProvider.notifier).state = value
                        .round();
                  },
                ),
              ),
              minLabel: context.l10n.surfaceInterval_format_minutes(5),
              maxLabel: context.l10n.surfaceInterval_format_minutes(120),
            ),
            const SizedBox(height: 16),

            // Gas Mix Section
            Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.science,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.surfaceInterval_field_gasMix,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    gasName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // O2 Slider
            _buildSliderRow(
              context: context,
              label: context.l10n.surfaceInterval_field_o2,
              icon: Icons.bubble_chart,
              value: '${o2.toStringAsFixed(0)}%',
              slider: Semantics(
                label: context.l10n.surfaceInterval_o2Semantics(
                  o2.toStringAsFixed(0),
                ),
                child: Slider(
                  value: o2,
                  min: 21,
                  max: 100,
                  divisions: 79,
                  onChanged: (value) {
                    ref.read(siFirstDiveO2Provider.notifier).state = value;
                    // Ensure O2 + He doesn't exceed 100%
                    if (value + he > 100) {
                      ref.read(siFirstDiveHeProvider.notifier).state =
                          100 - value;
                    }
                  },
                ),
              ),
              minLabel: '21%',
              maxLabel: '100%',
            ),

            // He Slider (only show if technical diving)
            const SizedBox(height: 12),
            _buildSliderRow(
              context: context,
              label: context.l10n.surfaceInterval_field_he,
              icon: Icons.air,
              value: '${he.toStringAsFixed(0)}%',
              slider: Semantics(
                label: context.l10n.surfaceInterval_heSemantics(
                  he.toStringAsFixed(0),
                ),
                child: Slider(
                  value: he,
                  min: 0,
                  max: 79,
                  divisions: 79,
                  onChanged: (value) {
                    ref.read(siFirstDiveHeProvider.notifier).state = value;
                    // Ensure O2 + He doesn't exceed 100%
                    if (o2 + value > 100) {
                      ref.read(siFirstDiveO2Provider.notifier).state =
                          100 - value;
                    }
                  },
                ),
              ),
              minLabel: '0%',
              maxLabel: '79%',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderRow({
    required BuildContext context,
    required String label,
    required IconData icon,
    required String value,
    required Widget slider,
    required String minLabel,
    required String maxLabel,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    icon,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Text(label, style: theme.textTheme.bodyMedium),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        slider,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(minLabel, style: theme.textTheme.bodySmall),
              Text(maxLabel, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
