import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/surface_interval_tool/presentation/providers/surface_interval_providers.dart';

/// Display card showing the calculated minimum surface interval result.
/// Shows the minimum time needed between dives and current safety status.
class SurfaceIntervalResult extends ConsumerWidget {
  const SurfaceIntervalResult({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final minInterval = ref.watch(siMinimumIntervalProvider);
    final currentInterval = ref.watch(siSurfaceIntervalProvider);
    final isSafe = ref.watch(siSecondDiveIsSafeProvider);
    final ndl = ref.watch(siSecondDiveNdlProvider);

    // Format interval as hours:minutes
    final hours = minInterval ~/ 60;
    final minutes = minInterval % 60;
    final intervalText = hours > 0 ? '${hours}h ${minutes}m' : '$minutes min';

    // Format NDL for display
    String ndlText;
    if (ndl < 0) {
      ndlText = 'In deco';
    } else {
      final ndlMinutes = ndl ~/ 60;
      ndlText = '$ndlMinutes min NDL';
    }

    // Current interval display
    final currentHours = currentInterval ~/ 60;
    final currentMinutes = currentInterval % 60;
    final currentText = currentHours > 0
        ? '${currentHours}h ${currentMinutes}m'
        : '$currentMinutes min';

    return Semantics(
      label:
          'Minimum surface interval: $intervalText. '
          'Current interval: $currentText. '
          'NDL for second dive: $ndlText. '
          '${isSafe ? "Safe to dive" : "Not yet safe, increase surface interval"}',
      child: Card(
        color: isSafe
            ? colorScheme.primaryContainer
            : colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Status Icon
              ExcludeSemantics(
                child: Icon(
                  isSafe ? Icons.check_circle : Icons.warning,
                  size: 48,
                  color: isSafe
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onErrorContainer,
                ),
              ),
              const SizedBox(height: 12),

              // Main Result
              Text(
                'Minimum Surface Interval',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: isSafe
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onErrorContainer,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                intervalText,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isSafe
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onErrorContainer,
                ),
              ),
              const SizedBox(height: 16),

              // Divider
              Divider(
                color: isSafe
                    ? colorScheme.onPrimaryContainer.withValues(alpha: 0.2)
                    : colorScheme.onErrorContainer.withValues(alpha: 0.2),
              ),
              const SizedBox(height: 16),

              // Current interval vs minimum
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildInfoColumn(
                    context: context,
                    label: 'Current Interval',
                    value: currentText,
                    isSafe: isSafe,
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: isSafe
                        ? colorScheme.onPrimaryContainer.withValues(alpha: 0.2)
                        : colorScheme.onErrorContainer.withValues(alpha: 0.2),
                  ),
                  _buildInfoColumn(
                    context: context,
                    label: 'NDL for 2nd Dive',
                    value: ndlText,
                    isSafe: isSafe,
                  ),
                ],
              ),

              if (!isSafe) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Increase surface interval or reduce second dive depth/time',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoColumn({
    required BuildContext context,
    required String label,
    required String value,
    required bool isSafe,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textColor = isSafe
        ? colorScheme.onPrimaryContainer
        : colorScheme.onErrorContainer;

    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: textColor.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    );
  }
}
