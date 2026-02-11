import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/surface_interval_tool/presentation/providers/surface_interval_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/surface_interval_tool/presentation/widgets/next_dive_input.dart';
import 'package:submersion/features/surface_interval_tool/presentation/widgets/previous_dive_input.dart';
import 'package:submersion/features/surface_interval_tool/presentation/widgets/surface_interval_result.dart';
import 'package:submersion/features/surface_interval_tool/presentation/widgets/tissue_recovery_chart.dart';

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
        title: Text(context.l10n.surfaceInterval_title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: context.l10n.surfaceInterval_action_resetDefaults,
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
                      ExcludeSemantics(
                        child: Icon(
                          Icons.info_outline,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        context.l10n.surfaceInterval_aboutTissueLoading_title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.surfaceInterval_aboutTissueLoading_body,
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
                        ExcludeSemantics(
                          child: Icon(
                            Icons.warning_amber,
                            size: 20,
                            color: colorScheme.error,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.l10n.surfaceInterval_disclaimer,
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
