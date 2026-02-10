import 'package:flutter/material.dart';

import 'package:submersion/core/accessibility/semantic_helpers.dart';
import 'package:submersion/core/deco/entities/o2_exposure.dart';

/// Card displaying oxygen toxicity information (CNS% and OTU).
class O2ToxicityCard extends StatelessWidget {
  /// Oxygen exposure data
  final O2Exposure exposure;

  /// Whether to show detailed breakdown
  final bool showDetails;

  /// Whether to show the header row (title + warning badge)
  final bool showHeader;

  /// Whether to wrap content in a Card
  final bool useCard;

  const O2ToxicityCard({
    super.key,
    required this.exposure,
    this.showDetails = true,
    this.showHeader = true,
    this.useCard = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        if (showHeader) ...[
          Row(
            children: [
              ExcludeSemantics(
                child: Icon(Icons.air, size: 20, color: colorScheme.primary),
              ),
              const SizedBox(width: 8),
              Text(
                'Oxygen Toxicity',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (exposure.cnsWarning || exposure.ppO2Warning)
                Semantics(
                  label: exposure.cnsCritical || exposure.ppO2Critical
                      ? 'Critical oxygen toxicity warning'
                      : 'Oxygen toxicity warning',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: exposure.cnsCritical || exposure.ppO2Critical
                          ? colorScheme.error
                          : Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      exposure.cnsCritical || exposure.ppO2Critical
                          ? 'CRITICAL'
                          : 'WARNING',
                      style: textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // CNS Progress
        _buildCnsProgress(context),
        const SizedBox(height: 16),

        // OTU Display
        _buildOtuDisplay(context),

        // Detailed breakdown
        if (showDetails) ...[
          const Divider(height: 24),
          _buildDetailsSection(context),
        ],
      ],
    );

    if (!useCard) {
      return Padding(padding: const EdgeInsets.all(16), child: content);
    }

    return Card(
      child: Padding(padding: const EdgeInsets.all(16), child: content),
    );
  }

  Widget _buildCnsProgress(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Determine color based on CNS level
    Color getProgressColor() {
      if (exposure.cnsEnd >= 100) return colorScheme.error;
      if (exposure.cnsEnd >= 80) return Colors.orange;
      if (exposure.cnsEnd >= 50) return Colors.amber;
      return Colors.green;
    }

    return Semantics(
      label: statLabel(name: 'CNS Oxygen Clock', value: exposure.cnsFormatted),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('CNS Oxygen Clock', style: textTheme.bodyMedium),
              Text(
                exposure.cnsFormatted,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: getProgressColor(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Semantics(
            label: 'CNS progress ${exposure.cnsEnd.toStringAsFixed(0)} percent',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (exposure.cnsEnd / 100).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(getProgressColor()),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Start: ${exposure.cnsStart.toStringAsFixed(0)}%',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '+${exposure.cnsDelta.toStringAsFixed(1)}% this dive',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOtuDisplay(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // OTU color based on daily limit
    Color getOtuColor() {
      if (exposure.otuPercentOfDaily >= 100) return colorScheme.error;
      if (exposure.otuPercentOfDaily >= 80) return Colors.orange;
      if (exposure.otuPercentOfDaily >= 50) return Colors.amber;
      return Colors.green;
    }

    return Semantics(
      label:
          'Oxygen Tolerance Units: ${exposure.otuFormatted}, ${exposure.otuPercentOfDaily.toStringAsFixed(0)} percent of daily limit',
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Oxygen Tolerance Units', style: textTheme.bodyMedium),
                const SizedBox(height: 4),
                Text(
                  exposure.otuFormatted,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: getOtuColor(),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  '${exposure.otuPercentOfDaily.toStringAsFixed(0)}%',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: getOtuColor(),
                  ),
                ),
                Text(
                  'of daily limit',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Details',
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        _buildDetailRow(
          context,
          'Max ppO2',
          exposure.maxPpO2Formatted,
          icon: Icons.trending_up,
          valueColor: exposure.ppO2Critical
              ? colorScheme.error
              : exposure.ppO2Warning
              ? Colors.orange
              : null,
        ),
        _buildDetailRow(
          context,
          'Max ppO2 Depth',
          '${exposure.maxPpO2Depth.toStringAsFixed(1)}m',
          icon: Icons.vertical_align_bottom,
        ),
        if (exposure.timeAboveWarning > 0)
          _buildDetailRow(
            context,
            'Time above 1.4 bar',
            _formatDuration(exposure.timeAboveWarning),
            icon: Icons.timer,
            valueColor: Colors.orange,
          ),
        if (exposure.timeAboveCritical > 0)
          _buildDetailRow(
            context,
            'Time above 1.6 bar',
            _formatDuration(exposure.timeAboveCritical),
            icon: Icons.warning,
            valueColor: colorScheme.error,
          ),
      ],
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    IconData? icon,
    Color? valueColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label: '$label: $value',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            if (icon != null) ...[
              ExcludeSemantics(
                child: Icon(
                  icon,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                label,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Text(
              value,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (secs == 0) return '${minutes}m';
    return '${minutes}m ${secs}s';
  }
}

/// Compact version of O2 toxicity display for inline use.
class O2ToxicityBadge extends StatelessWidget {
  final O2Exposure exposure;

  const O2ToxicityBadge({super.key, required this.exposure});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color getBadgeColor() {
      if (exposure.cnsCritical) return colorScheme.error;
      if (exposure.cnsWarning) return Colors.orange;
      return Colors.green;
    }

    return Semantics(
      label: 'CNS oxygen toxicity ${exposure.cnsFormatted}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: getBadgeColor().withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: getBadgeColor()),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(Icons.air, size: 14, color: getBadgeColor()),
            ),
            const SizedBox(width: 4),
            Text(
              'CNS ${exposure.cnsFormatted}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: getBadgeColor(),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
