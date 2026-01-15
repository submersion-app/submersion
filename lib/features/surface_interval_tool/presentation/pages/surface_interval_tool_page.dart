import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/surface_interval_providers.dart';
import '../widgets/next_dive_input.dart';
import '../widgets/previous_dive_input.dart';
import '../widgets/surface_interval_result.dart';
import '../widgets/tissue_recovery_chart.dart';

/// Surface Interval Tool page for planning repetitive dives.
///
/// Allows divers to:
/// 1. Input first dive parameters (depth, time, gas mix)
/// 2. Input desired second dive parameters (depth, time)
/// 3. Calculate the minimum surface interval needed
/// 4. Visualize tissue off-gassing over time
class SurfaceIntervalToolPage extends ConsumerWidget {
  const SurfaceIntervalToolPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Surface Interval'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset to defaults',
            onPressed: () => resetSurfaceIntervalInputs(ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // First Dive Input
          const PreviousDiveInput(),
          const SizedBox(height: 16),

          // Second Dive Input
          const NextDiveInput(),
          const SizedBox(height: 16),

          // Result Card
          const SurfaceIntervalResult(),
          const SizedBox(height: 16),

          // Tissue Recovery Chart
          const TissueRecoveryChart(),
          const SizedBox(height: 16),

          // Info Card
          Card(
            color: colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'About Tissue Loading',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your body has 16 tissue compartments that absorb and release '
                    'nitrogen at different rates. Fast tissues (like blood) saturate '
                    'quickly but also off-gas quickly. Slow tissues (like bone and fat) '
                    'take longer to both load and unload.\n\n'
                    'The "leading compartment" is whichever tissue is most saturated '
                    'and typically controls your no-decompression limit (NDL). '
                    'During a surface interval, all tissues off-gas toward surface '
                    'saturation levels (~40% loading).',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber,
                          size: 20,
                          color: colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This tool is for planning purposes only. Always use a '
                            'dive computer and follow your training. Results are based '
                            'on the Bühlmann ZH-L16C algorithm and may differ from '
                            'your computer.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
