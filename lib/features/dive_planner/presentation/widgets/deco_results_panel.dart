import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';

/// Panel displaying decompression calculation results.
///
/// Shows:
/// - Runtime summary
/// - NDL (No Decompression Limit) or deco status
/// - TTS (Time To Surface)
/// - Ceiling depth
/// - Decompression schedule (if applicable)
/// - Warnings and alerts
class DecoResultsPanel extends ConsumerWidget {
  const DecoResultsPanel({super.key});

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
                Icon(Icons.analytics, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Decompression',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Main stats row
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Runtime',
                    value: _formatDuration(results.totalRuntime),
                    icon: Icons.timer,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    label: results.ndlAtBottom < 0 ? 'Status' : 'NDL',
                    value: results.ndlAtBottom < 0
                        ? 'DECO'
                        : _formatDuration(results.ndlAtBottom),
                    icon: Icons.warning_amber,
                    valueColor: results.ndlAtBottom < 0
                        ? Colors.orange
                        : Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    label: 'TTS',
                    value: _formatDuration(results.ttsAtBottom),
                    icon: Icons.arrow_upward,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Ceiling
            if (results.maxCeiling > 0) ...[
              _InfoRow(
                icon: Icons.layers,
                label: 'Ceiling',
                value: units.formatDepth(results.maxCeiling),
              ),
              const SizedBox(height: 8),
            ],

            // Deco schedule
            if (results.decoSchedule.isNotEmpty) ...[
              const Divider(),
              const SizedBox(height: 8),
              Text('Decompression Schedule', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              ...results.decoSchedule.map(
                (stop) => _DecoStopRow(stop: stop, units: units),
              ),
            ],

            // Warnings
            if (results.warnings.isNotEmpty) ...[
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Warnings',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              ...results.warnings.map(
                (warning) => _WarningRow(warning: warning, units: units),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds < 0) return '--';
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return '${hours}h ${mins}min';
    }
    if (secs == 0) return '${minutes}min';
    return '${minutes}min ${secs}s';
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.outline),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: valueColor ?? theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.outline),
        const SizedBox(width: 8),
        Text(label, style: theme.textTheme.bodyMedium),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _DecoStopRow extends StatelessWidget {
  final DecoStop stop;
  final UnitFormatter units;

  const _DecoStopRow({required this.stop, required this.units});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            units.formatDepth(stop.depth),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 16),
          Text(stop.durationFormatted, style: theme.textTheme.bodyMedium),
          const Spacer(),
          Text(
            stop.gasMix.name,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningRow extends StatelessWidget {
  final PlanWarning warning;
  final UnitFormatter units;

  const _WarningRow({required this.warning, required this.units});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCritical = warning.severity == PlanWarningSeverity.critical;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCritical ? Icons.error : Icons.warning_amber,
            size: 18,
            color: isCritical ? theme.colorScheme.error : Colors.orange,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _formatWarningMessage(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: isCritical
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Format warning message with proper units.
  String _formatWarningMessage() {
    switch (warning.type) {
      case PlanWarningType.ppO2High:
        // ppO2 is universally expressed in bar (partial pressure)
        return 'ppO₂ of ${warning.value?.toStringAsFixed(2) ?? "--"} bar exceeds working limit';
      case PlanWarningType.ppO2Critical:
        return 'ppO₂ of ${warning.value?.toStringAsFixed(2) ?? "--"} bar exceeds critical limit';
      case PlanWarningType.gasLow:
        final threshold = warning.threshold ?? 50;
        return 'Tank below ${units.formatPressure(threshold)} reserve';
      case PlanWarningType.gasOut:
        return 'Tank will be empty';
      case PlanWarningType.ndlExceeded:
        return 'Dive enters decompression obligation';
      case PlanWarningType.cnsWarning:
        return 'CNS% exceeds ${warning.threshold?.toStringAsFixed(0) ?? "80"}%';
      case PlanWarningType.cnsCritical:
        return 'CNS% exceeds 100%';
      case PlanWarningType.otuWarning:
        return 'OTU accumulation high';
      case PlanWarningType.ascentRateHigh:
        final rate = warning.value;
        if (rate != null) {
          return 'Ascent rate ${units.formatDepth(rate)}/min exceeds safe limit';
        }
        return 'Ascent rate exceeds safe limit';
      case PlanWarningType.endHigh:
        final end = warning.value;
        if (end != null) {
          return 'END of ${units.formatDepth(end)} exceeds safe limit';
        }
        return 'Equivalent Narcotic Depth too high';
      case PlanWarningType.minGasViolation:
        return 'Minimum gas reserve not maintained';
      case PlanWarningType.modViolation:
        return 'Gas switch attempted above MOD';
    }
  }
}
