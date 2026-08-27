import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/surface_interval_tool/presentation/providers/surface_interval_providers.dart';
import 'package:submersion/features/surface_interval_tool/presentation/widgets/gas_mix_input.dart';
import 'package:submersion/features/surface_interval_tool/presentation/widgets/si_slider_row.dart';
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

    // Convert depth for display
    final displayDepth = units.convertDepth(depth);
    final maxDisplayDepth = units.convertDepth(60.0);
    final depthSymbol = units.depthSymbol;

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
            SiSliderRow(
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
            SiSliderRow(
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
            GasMixInput(
              o2Provider: siFirstDiveO2Provider,
              heProvider: siFirstDiveHeProvider,
              gasSafetyProvider: siFirstDiveGasSafetyProvider,
              o2SemanticsBuilder: (percent) =>
                  context.l10n.surfaceInterval_o2Semantics(percent),
              heSemanticsBuilder: (percent) =>
                  context.l10n.surfaceInterval_heSemantics(percent),
            ),
          ],
        ),
      ),
    );
  }
}
