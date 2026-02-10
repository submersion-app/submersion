import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import 'package:submersion/features/deco_calculator/presentation/providers/deco_calculator_providers.dart';

/// Displays gas-related warnings (ppO2, MOD, END).
class GasWarningsDisplay extends ConsumerWidget {
  const GasWarningsDisplay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final depth = ref.watch(calcDepthProvider);
    final ppO2 = ref.watch(calcPpO2Provider);
    final mod = ref.watch(calcMODProvider);
    final end = ref.watch(calcENDProvider);
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Determine warning states
    final ppO2Status = _getPpO2Status(ppO2);
    final modStatus = depth > mod ? WarningStatus.danger : WarningStatus.ok;
    final endStatus = _getEndStatus(end);

    // Only show card if there are any warnings
    final hasWarnings =
        ppO2Status != WarningStatus.ok ||
        modStatus != WarningStatus.ok ||
        endStatus != WarningStatus.ok;

    return Card(
      color: hasWarnings
          ? colorScheme.errorContainer.withValues(alpha: 0.3)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasWarnings ? Icons.warning_amber : Icons.verified_user,
                  size: 20,
                  color: hasWarnings ? Colors.orange : Colors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  'Gas Safety',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // ppO2
                Expanded(
                  child: _buildMetric(
                    context,
                    label: 'ppO₂',
                    value: units.formatPressure(ppO2),
                    status: ppO2Status,
                    tooltip: _getPpO2Tooltip(ppO2),
                  ),
                ),
                const SizedBox(width: 12),

                // MOD
                Expanded(
                  child: _buildMetric(
                    context,
                    label: 'MOD',
                    value: units.formatDepth(mod),
                    status: modStatus,
                    tooltip: modStatus == WarningStatus.ok
                        ? 'Within safe operating depth'
                        : 'Current depth exceeds MOD!',
                  ),
                ),
                const SizedBox(width: 12),

                // END
                Expanded(
                  child: _buildMetric(
                    context,
                    label: 'END',
                    value: units.formatDepth(end),
                    status: endStatus,
                    tooltip: _getEndTooltip(end),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(
    BuildContext context, {
    required String label,
    required String value,
    required WarningStatus status,
    required String tooltip,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final color = _getStatusColor(status);

    return Semantics(
      label: '$label: $value. $tooltip',
      liveRegion: status != WarningStatus.ok,
      child: Tooltip(
        message: tooltip,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(
                    child: Icon(_getStatusIcon(status), size: 14, color: color),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      value,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  WarningStatus _getPpO2Status(double ppO2) {
    if (ppO2 > 1.6) return WarningStatus.danger;
    if (ppO2 > 1.4) return WarningStatus.warning;
    if (ppO2 < 0.16) return WarningStatus.danger; // Hypoxic
    return WarningStatus.ok;
  }

  WarningStatus _getEndStatus(double end) {
    if (end > 40) return WarningStatus.danger;
    if (end > 30) return WarningStatus.warning;
    return WarningStatus.ok;
  }

  String _getPpO2Tooltip(double ppO2) {
    if (ppO2 > 1.6) return 'DANGER: High oxygen toxicity risk!';
    if (ppO2 > 1.4) return 'Caution: Approaching toxicity limit';
    if (ppO2 < 0.16) return 'DANGER: Hypoxic - insufficient oxygen!';
    return 'Safe oxygen partial pressure';
  }

  String _getEndTooltip(double end) {
    if (end > 40) return 'DANGER: Severe narcosis risk!';
    if (end > 30) return 'Caution: Narcosis may affect judgment';
    return 'Narcosis risk within acceptable limits';
  }

  Color _getStatusColor(WarningStatus status) {
    switch (status) {
      case WarningStatus.ok:
        return Colors.green;
      case WarningStatus.warning:
        return Colors.orange;
      case WarningStatus.danger:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(WarningStatus status) {
    switch (status) {
      case WarningStatus.ok:
        return Icons.check_circle;
      case WarningStatus.warning:
        return Icons.warning;
      case WarningStatus.danger:
        return Icons.dangerous;
    }
  }
}

enum WarningStatus { ok, warning, danger }
