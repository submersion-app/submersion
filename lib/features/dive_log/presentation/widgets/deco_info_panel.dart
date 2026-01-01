import 'package:flutter/material.dart';

import '../../../../core/deco/entities/deco_status.dart';
import '../../../../core/deco/entities/tissue_compartment.dart';

/// Panel displaying decompression status and tissue loading.
class DecoInfoPanel extends StatelessWidget {
  /// Current decompression status
  final DecoStatus status;

  /// Whether to show tissue loading chart
  final bool showTissueChart;

  /// Whether to show deco stops
  final bool showDecoStops;

  const DecoInfoPanel({
    super.key,
    required this.status,
    this.showTissueChart = true,
    this.showDecoStops = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  status.inDeco ? Icons.warning : Icons.check_circle,
                  size: 20,
                  color: status.inDeco ? Colors.orange : Colors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  'Decompression Status',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: status.inDeco
                        ? Colors.orange.withValues(alpha: 0.2)
                        : Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.inDeco ? 'DECO' : 'NO DECO',
                    style: textTheme.labelSmall?.copyWith(
                      color: status.inDeco ? Colors.orange : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Key metrics row
            _buildMetricsRow(context),

            // Tissue loading chart
            if (showTissueChart) ...[
              const SizedBox(height: 16),
              _buildTissueChart(context),
            ],

            // Deco stops
            if (showDecoStops && status.decoStops.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildDecoStops(context),
            ],

            // Gradient factors
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'GF: ${(status.gfLow * 100).toInt()}/${(status.gfHigh * 100).toInt()}',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsRow(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        // NDL or Ceiling
        Expanded(
          child: _buildMetricTile(
            context,
            label: status.inDeco ? 'Ceiling' : 'NDL',
            value: status.inDeco
                ? '${status.ceilingMeters.toStringAsFixed(1)}m'
                : status.ndlFormatted,
            icon: status.inDeco ? Icons.arrow_upward : Icons.timer,
            color: status.inDeco ? Colors.orange : Colors.green,
          ),
        ),
        const SizedBox(width: 12),

        // TTS
        Expanded(
          child: _buildMetricTile(
            context,
            label: 'TTS',
            value: status.ttsFormatted,
            icon: Icons.schedule,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),

        // Leading compartment
        Expanded(
          child: _buildMetricTile(
            context,
            label: 'Leading',
            value: '#${status.leadingCompartmentNumber}',
            subtitle: '${status.leadingCompartmentLoading.toStringAsFixed(0)}%',
            icon: Icons.show_chart,
            color: _getLoadingColor(status.leadingCompartmentLoading),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String label,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTissueChart(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tissue Loading',
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 60,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: status.compartments.map((comp) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: _buildTissueBar(context, comp),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Fast',
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              'Slow',
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTissueBar(BuildContext context, TissueCompartment comp) {
    final loading = comp.percentLoading.clamp(0.0, 120.0);
    final normalizedHeight = (loading / 120.0).clamp(0.0, 1.0);
    final color = _getLoadingColor(loading);

    return Tooltip(
      message:
          'Compartment ${comp.compartmentNumber}\n${loading.toStringAsFixed(1)}% loaded\nHalf-time: ${comp.halfTimeN2.toStringAsFixed(0)} min',
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.3),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
        ),
        child: FractionallySizedBox(
          heightFactor: normalizedHeight,
          alignment: Alignment.bottomCenter,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(2)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDecoStops(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Deco Stops',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              'Total: ${_formatTotalDecoTime()}',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: status.decoStops.map((stop) {
            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: stop.isDeepStop
                    ? Colors.purple.withValues(alpha: 0.1)
                    : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: stop.isDeepStop ? Colors.purple : Colors.orange,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    stop.depthFormatted(),
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: stop.isDeepStop ? Colors.purple : Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    stop.durationFormatted,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _formatTotalDecoTime() {
    final totalSeconds = status.totalDecoTime;
    final minutes = totalSeconds ~/ 60;
    return '${minutes}min';
  }

  Color _getLoadingColor(double loading) {
    if (loading >= 100) return Colors.red;
    if (loading >= 80) return Colors.orange;
    if (loading >= 60) return Colors.amber;
    return Colors.green;
  }
}

/// Compact NDL/Ceiling display widget.
class NdlBadge extends StatelessWidget {
  final DecoStatus status;

  const NdlBadge({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final isInDeco = status.inDeco;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isInDeco
            ? Colors.orange.withValues(alpha: 0.1)
            : Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isInDeco ? Colors.orange : Colors.green,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isInDeco ? Icons.warning : Icons.timer,
            size: 14,
            color: isInDeco ? Colors.orange : Colors.green,
          ),
          const SizedBox(width: 4),
          Text(
            isInDeco
                ? 'Ceiling ${status.ceilingMeters.toStringAsFixed(1)}m'
                : 'NDL ${status.ndlFormatted}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isInDeco ? Colors.orange : Colors.green,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
