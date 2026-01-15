import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';

/// Panel displaying gas consumption projections for all tanks.
///
/// Shows per-tank:
/// - Gas used (liters and bar)
/// - Remaining pressure projection
/// - Percentage used visualization
/// - Reserve violation warnings
class GasResultsPanel extends ConsumerWidget {
  const GasResultsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(planResultsProvider);
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.propane_tank, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Gas Consumption',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (results.gasConsumptions.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Add segments to see gas projections',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
              )
            else
              ...results.gasConsumptions.map(
                (consumption) =>
                    _GasConsumptionCard(consumption: consumption, units: units),
              ),
          ],
        ),
      ),
    );
  }
}

class _GasConsumptionCard extends StatelessWidget {
  final GasConsumption consumption;
  final UnitFormatter units;

  const _GasConsumptionCard({required this.consumption, required this.units});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasWarning = consumption.reserveViolation;
    final percentUsed = consumption.percentUsed.clamp(0.0, 100.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasWarning
            ? theme.colorScheme.errorContainer.withValues(alpha: 0.3)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: hasWarning
            ? Border.all(color: theme.colorScheme.error, width: 1)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tank header
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: _getGasColor(consumption.gasMix.o2),
                child: Text(
                  consumption.gasMix.name.substring(0, 1),
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                consumption.tankName ?? consumption.gasMix.name,
                style: theme.textTheme.titleSmall,
              ),
              const Spacer(),
              if (hasWarning)
                Icon(
                  Icons.warning_amber,
                  color: theme.colorScheme.error,
                  size: 20,
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentUsed / 100,
              backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation(
                _getProgressColor(percentUsed),
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),

          // Stats row
          Row(
            children: [
              // Used
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Used',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    Text(
                      units.formatPressure(consumption.gasUsedBar),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Remaining
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Remaining',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    Text(
                      _formatRemainingPressure(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: hasWarning ? theme.colorScheme.error : null,
                      ),
                    ),
                  ],
                ),
              ),
              // Percentage
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Consumption',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    Text(
                      consumption.percentFormatted,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Reserve warning
          if (hasWarning) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 16,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 4),
                Text(
                  'Below minimum reserve (${units.formatPressure(consumption.minGasReserve?.toDouble())})',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Format remaining pressure with proper unit settings.
  String _formatRemainingPressure() {
    final remaining = consumption.remainingPressure;
    if (remaining == null) return '--';
    if (remaining <= 0) return 'EMPTY';
    return units.formatPressure(remaining.toDouble());
  }

  Color _getGasColor(double o2Percent) {
    if (o2Percent <= 21) return Colors.grey;
    if (o2Percent <= 40) return Colors.green;
    if (o2Percent <= 80) return Colors.orange;
    return Colors.red;
  }

  Color _getProgressColor(double percent) {
    if (percent < 50) return Colors.green;
    if (percent < 75) return Colors.orange;
    return Colors.red;
  }
}
