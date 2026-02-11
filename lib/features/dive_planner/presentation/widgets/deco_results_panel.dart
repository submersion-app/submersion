import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

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
                ExcludeSemantics(
                  child: Icon(
                    Icons.analytics,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.divePlanner_label_decompression,
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
                    label: context.l10n.divePlanner_label_runtime,
                    value: _formatDuration(results.totalRuntime),
                    icon: Icons.timer,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatCard(
                    label: results.ndlAtBottom < 0
                        ? context.l10n.divePlanner_label_status
                        : context.l10n.divePlanner_label_ndl,
                    value: results.ndlAtBottom < 0
                        ? context.l10n.divePlanner_label_deco
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
                    label: context.l10n.divePlanner_label_tts,
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
                label: context.l10n.divePlanner_label_ceiling,
                value: units.formatDepth(results.maxCeiling),
              ),
              const SizedBox(height: 8),
            ],

            // Deco schedule
            if (results.decoSchedule.isNotEmpty) ...[
              const Divider(),
              const SizedBox(height: 8),
              Text(
                context.l10n.divePlanner_label_decoSchedule,
                style: theme.textTheme.labelLarge,
              ),
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
                context.l10n.divePlanner_label_warnings,
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

    return Semantics(
      label: '$label: $value',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            ExcludeSemantics(
              child: Icon(icon, size: 20, color: theme.colorScheme.outline),
            ),
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

    return Semantics(
      label: '$label: $value',
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(icon, size: 18, color: theme.colorScheme.outline),
          ),
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
      ),
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

    return Semantics(
      label: context.l10n.divePlanner_semantics_decoStop(
        units.formatDepth(stop.depth),
        stop.durationFormatted,
        stop.gasMix.name,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(4),
                ),
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

    final message = _formatWarningMessage(context);

    return Semantics(
      label: isCritical
          ? context.l10n.divePlanner_semantics_criticalWarning(message)
          : context.l10n.divePlanner_semantics_warning(message),
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(
                isCritical ? Icons.error : Icons.warning_amber,
                size: 18,
                color: isCritical ? theme.colorScheme.error : Colors.orange,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isCritical
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Format warning message with proper units.
  String _formatWarningMessage(BuildContext context) {
    switch (warning.type) {
      case PlanWarningType.ppO2High:
        // ppO2 is universally expressed in bar (partial pressure)
        return context.l10n.divePlanner_warning_ppO2High(
          warning.value?.toStringAsFixed(2) ?? '--',
        );
      case PlanWarningType.ppO2Critical:
        return context.l10n.divePlanner_warning_ppO2Critical(
          warning.value?.toStringAsFixed(2) ?? '--',
        );
      case PlanWarningType.gasLow:
        final threshold = warning.threshold ?? 50;
        return context.l10n.divePlanner_warning_gasLow(
          units.formatPressure(threshold),
        );
      case PlanWarningType.gasOut:
        return context.l10n.divePlanner_warning_gasOut;
      case PlanWarningType.ndlExceeded:
        return context.l10n.divePlanner_warning_ndlExceeded;
      case PlanWarningType.cnsWarning:
        return context.l10n.divePlanner_warning_cnsWarning(
          warning.threshold?.toStringAsFixed(0) ?? '80',
        );
      case PlanWarningType.cnsCritical:
        return context.l10n.divePlanner_warning_cnsCritical;
      case PlanWarningType.otuWarning:
        return context.l10n.divePlanner_warning_otuWarning;
      case PlanWarningType.ascentRateHigh:
        final rate = warning.value;
        if (rate != null) {
          return context.l10n.divePlanner_warning_ascentRateHighWithRate(
            units.formatDepth(rate),
          );
        }
        return context.l10n.divePlanner_warning_ascentRateHigh;
      case PlanWarningType.endHigh:
        final end = warning.value;
        if (end != null) {
          return context.l10n.divePlanner_warning_endHighWithDepth(
            units.formatDepth(end),
          );
        }
        return context.l10n.divePlanner_warning_endHigh;
      case PlanWarningType.minGasViolation:
        return context.l10n.divePlanner_warning_minGasViolation;
      case PlanWarningType.modViolation:
        return context.l10n.divePlanner_warning_modViolation;
    }
  }
}
