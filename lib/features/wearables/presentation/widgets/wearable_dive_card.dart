import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:submersion/features/wearables/domain/entities/wearable_dive.dart';

/// Card displaying a wearable dive for selection in the import wizard.
class WearableDiveCard extends StatelessWidget {
  const WearableDiveCard({
    super.key,
    required this.dive,
    required this.isSelected,
    required this.onToggleSelection,
    this.matchStatus,
  });

  final WearableDive dive;
  final bool isSelected;
  final VoidCallback onToggleSelection;
  final WearableDiveMatchStatus? matchStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: isSelected ? 2 : 0,
      color: isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
      child: InkWell(
        onTap: onToggleSelection,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildCheckbox(context),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 8),
                    _buildMetrics(context),
                    if (matchStatus != null) ...[
                      const SizedBox(height: 8),
                      _buildMatchBadge(context),
                    ],
                  ],
                ),
              ),
              _buildSourceBadge(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckbox(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? colorScheme.primary : colorScheme.outline,
          width: 2,
        ),
        color: isSelected ? colorScheme.primary : Colors.transparent,
      ),
      child: isSelected
          ? Icon(Icons.check, size: 16, color: colorScheme.onPrimary)
          : null,
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd();
    final timeFormat = DateFormat.jm();

    return Row(
      children: [
        Text(
          dateFormat.format(dive.startTime),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          timeFormat.format(dive.startTime),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildMetrics(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodyMedium;
    final labelStyle = textStyle?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        _MetricChip(
          icon: Icons.arrow_downward,
          value: '${dive.maxDepth.toStringAsFixed(1)}m',
          label: 'Max Depth',
          textStyle: textStyle,
          labelStyle: labelStyle,
        ),
        _MetricChip(
          icon: Icons.timer_outlined,
          value: _formatDuration(dive.duration),
          label: 'Duration',
          textStyle: textStyle,
          labelStyle: labelStyle,
        ),
        if (dive.minTemperature != null)
          _MetricChip(
            icon: Icons.thermostat_outlined,
            value: '${dive.minTemperature!.toStringAsFixed(0)}C',
            label: 'Temp',
            textStyle: textStyle,
            labelStyle: labelStyle,
          ),
        if (dive.avgHeartRate != null)
          _MetricChip(
            icon: Icons.favorite_outline,
            value: '${dive.avgHeartRate!.round()} bpm',
            label: 'Avg HR',
            textStyle: textStyle,
            labelStyle: labelStyle,
          ),
      ],
    );
  }

  Widget _buildMatchBadge(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final (color, icon, text) = switch (matchStatus!) {
      WearableDiveMatchStatus.probable => (
        colorScheme.error,
        Icons.warning_amber_rounded,
        'Likely duplicate',
      ),
      WearableDiveMatchStatus.possible => (
        colorScheme.tertiary,
        Icons.info_outline,
        'Possible duplicate',
      ),
      WearableDiveMatchStatus.alreadyImported => (
        colorScheme.outline,
        Icons.check_circle_outline,
        'Already imported',
      ),
      WearableDiveMatchStatus.none => (
        colorScheme.primary,
        Icons.add_circle_outline,
        'New dive',
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceBadge(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (icon, label) = switch (dive.source) {
      WearableSource.appleWatch => (Icons.watch, 'Watch'),
      WearableSource.garmin => (Icons.watch, 'Garmin'),
      WearableSource.suunto => (Icons.watch, 'Suunto'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return '${hours}h ${mins}m';
    }
    return '${minutes}m';
  }
}

/// Match status for a wearable dive during import.
enum WearableDiveMatchStatus {
  /// Score >= 0.7 - Very likely same dive as existing
  probable,

  /// Score >= 0.5 - Might be same dive
  possible,

  /// Already imported (wearable_id matches)
  alreadyImported,

  /// No match found - new dive
  none,
}

/// Small metric display chip for dive summary.
class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.value,
    required this.label,
    this.textStyle,
    this.labelStyle,
  });

  final IconData icon;
  final String value;
  final String label;
  final TextStyle? textStyle;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: labelStyle?.color),
        const SizedBox(width: 4),
        Text(value, style: textStyle),
      ],
    );
  }
}
