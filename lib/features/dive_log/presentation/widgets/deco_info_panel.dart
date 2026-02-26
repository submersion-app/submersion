import 'package:flutter/material.dart';

import 'package:submersion/core/accessibility/semantic_helpers.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Panel displaying decompression status and tissue loading.
class DecoInfoPanel extends StatelessWidget {
  /// Current decompression status
  final DecoStatus status;

  /// Whether to show tissue loading chart
  final bool showTissueChart;

  /// Whether to show deco stops
  final bool showDecoStops;

  /// Whether to show the header row (title + status badge)
  final bool showHeader;

  /// Whether to wrap content in a Card
  final bool useCard;

  const DecoInfoPanel({
    super.key,
    required this.status,
    this.showTissueChart = true,
    this.showDecoStops = true,
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
                child: Icon(
                  status.inDeco ? Icons.warning : Icons.check_circle,
                  size: 20,
                  color: status.inDeco ? Colors.orange : Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.diveLog_deco_title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Semantics(
                label: status.inDeco
                    ? context.l10n.diveLog_deco_semantics_required
                    : context.l10n.diveLog_deco_semantics_notRequired,
                child: Container(
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
                    status.inDeco
                        ? context.l10n.diveLog_deco_badge_deco
                        : context.l10n.diveLog_deco_badge_noDeco,
                    style: textTheme.labelSmall?.copyWith(
                      color: status.inDeco ? Colors.orange : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],

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
        Semantics(
          label:
              'Gradient factors: low ${(status.gfLow * 100).toInt()}, high ${(status.gfHigh * 100).toInt()}',
          child: Row(
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
        ),
      ],
    );

    if (!useCard) {
      return Padding(padding: const EdgeInsets.all(16), child: content);
    }

    return Card(
      child: Padding(padding: const EdgeInsets.all(16), child: content),
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
            label: status.inDeco
                ? context.l10n.diveLog_deco_label_ceiling
                : context.l10n.diveLog_deco_label_ndl,
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
            label: context.l10n.diveLog_deco_label_tts,
            value: status.ttsFormatted,
            icon: Icons.schedule,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),

        // GF99
        Expanded(
          child: _buildMetricTile(
            context,
            label: context.l10n.diveLog_deco_label_gf99,
            value: '${status.gf99.toStringAsFixed(0)}%',
            subtitle: '#${status.gf99LeadingCompartmentNumber}',
            icon: Icons.show_chart,
            color: _getGfColor(status.gf99),
          ),
        ),
        const SizedBox(width: 12),

        // SurfGF
        Expanded(
          child: _buildMetricTile(
            context,
            label: context.l10n.diveLog_deco_label_surfGf,
            value: '${status.surfGf.toStringAsFixed(0)}%',
            icon: Icons.arrow_upward,
            color: _getGfColor(status.surfGf),
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

    return Semantics(
      label: subtitle != null ? '$label: $value, $subtitle' : '$label: $value',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            ExcludeSemantics(child: Icon(icon, size: 20, color: color)),
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
      ),
    );
  }

  Widget _buildTissueChart(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    const chartHeight = 80.0;
    const maxLoadingPercent = 120.0;
    const mValueBottom = chartHeight * (100.0 / maxLoadingPercent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.diveLog_deco_sectionTissueLoading,
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: chartSummaryLabel(
            chartType: 'Tissue pressure diagram',
            description:
                '${status.compartments.length} compartments showing nitrogen '
                'and helium loading relative to M-value, leading compartment '
                '${status.leadingCompartmentNumber} at '
                '${status.leadingCompartmentLoading.toStringAsFixed(0)} percent',
          ),
          child: SizedBox(
            height: chartHeight,
            child: Stack(
              children: [
                // Tissue bars
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: status.compartments.map((comp) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: _buildSubsurfaceBar(
                          comp,
                          chartHeight,
                          maxLoadingPercent,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                // M-value reference line at 100%
                Positioned(
                  bottom: mValueBottom,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 1,
                    color: colorScheme.error.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.l10n.diveLog_deco_tissueFast,
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              context.l10n.diveLog_deco_tissueSlow,
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubsurfaceBar(
    TissueCompartment comp,
    double chartHeight,
    double maxLoading,
  ) {
    final totalLoading = comp.percentLoading.clamp(0.0, maxLoading);
    final barHeight = chartHeight * (totalLoading / maxLoading);

    // Split bar into N2 and He portions
    final totalGas = comp.totalInertGas;
    final n2Ratio = totalGas > 0 ? comp.currentPN2 / totalGas : 1.0;
    final heRatio = totalGas > 0 ? comp.currentPHe / totalGas : 0.0;

    final n2Height = barHeight * n2Ratio;
    final heHeight = barHeight * heRatio;

    final n2Color = _getN2Color(totalLoading);

    return Tooltip(
      message:
          'Compartment ${comp.compartmentNumber}\n'
          '${totalLoading.toStringAsFixed(1)}% loaded\n'
          'N\u2082: ${comp.currentPN2.toStringAsFixed(2)} bar'
          '${comp.currentPHe > 0 ? '\nHe: ${comp.currentPHe.toStringAsFixed(2)} bar' : ''}\n'
          'Half-time: ${comp.halfTimeN2.toStringAsFixed(0)} min',
      child: SizedBox(
        height: chartHeight,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // He portion (top, purple) - only if helium present
            if (heHeight > 0.5)
              Container(
                height: heHeight,
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withValues(alpha: 0.8),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(2),
                  ),
                ),
              ),
            // N2 portion (bottom, teal-to-red gradient)
            Container(
              height: n2Height.clamp(0.0, barHeight),
              decoration: BoxDecoration(
                color: n2Color,
                borderRadius: BorderRadius.vertical(
                  top: heHeight > 0.5 ? Radius.zero : const Radius.circular(2),
                ),
              ),
            ),
          ],
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
              context.l10n.diveLog_deco_sectionDecoStops,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              context.l10n.diveLog_deco_totalDecoTime(_formatTotalDecoTime()),
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
            return Semantics(
              label:
                  '${stop.isDeepStop ? "Deep" : "Deco"} stop at ${stop.depthFormatted()} for ${stop.durationFormatted}',
              child: Container(
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

  Color _getN2Color(double loading) {
    if (loading >= 100) return Colors.red;
    if (loading >= 80) return Colors.orange;
    if (loading >= 60) return Colors.amber;
    return Colors.green;
  }

  Color _getGfColor(double gfPercent) {
    if (gfPercent >= 100) return Colors.red;
    if (gfPercent >= 80) return Colors.orange;
    if (gfPercent >= 60) return Colors.amber;
    return Colors.green;
  }
}

/// Compact NDL/Ceiling display widget.
class NdlBadge extends StatelessWidget {
  final DecoStatus status;

  const NdlBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final isInDeco = status.inDeco;

    return Semantics(
      label: isInDeco
          ? 'Decompression ceiling ${status.ceilingMeters.toStringAsFixed(1)} meters'
          : 'No decompression limit ${status.ndlFormatted}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isInDeco
              ? Colors.orange.withValues(alpha: 0.1)
              : Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isInDeco ? Colors.orange : Colors.green),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                isInDeco ? Icons.warning : Icons.timer,
                size: 14,
                color: isInDeco ? Colors.orange : Colors.green,
              ),
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
      ),
    );
  }
}
