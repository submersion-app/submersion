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

        // Leading compartment
        Expanded(
          child: _buildMetricTile(
            context,
            label: context.l10n.diveLog_deco_label_leading,
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
            chartType: 'Tissue loading bar',
            description:
                '${status.compartments.length} compartments, leading compartment ${status.leadingCompartmentNumber} at ${status.leadingCompartmentLoading.toStringAsFixed(0)} percent',
          ),
          child: SizedBox(
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
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(2),
              ),
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

  Color _getLoadingColor(double loading) {
    if (loading >= 100) return Colors.red;
    if (loading >= 80) return Colors.orange;
    if (loading >= 60) return Colors.amber;
    return Colors.green;
  }
}

/// Compact decompression status panel showing all deco data in a condensed
/// card format. Tappable to expand to the full [DecoInfoPanel] view.
class CompactDecoPanel extends StatelessWidget {
  /// Current decompression status
  final DecoStatus status;

  /// Optional subtitle text (e.g. "at 3:42")
  final String? subtitle;

  /// Callback when the panel is tapped to expand
  final VoidCallback? onTap;

  const CompactDecoPanel({
    super.key,
    required this.status,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              _buildHeaderRow(context, colorScheme, textTheme),
              const SizedBox(height: 8),

              // Metrics row
              _buildMetricsRow(context, colorScheme, textTheme),
              const SizedBox(height: 8),

              // Tissue chart
              _buildTissueChart(context),
              const SizedBox(height: 6),

              // Bottom row: GF values and deco stops
              _buildBottomRow(context, colorScheme, textTheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderRow(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Row(
      children: [
        ExcludeSemantics(
          child: Icon(
            status.inDeco ? Icons.warning : Icons.check_circle,
            size: 16,
            color: status.inDeco ? Colors.orange : Colors.green,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          context.l10n.diveLog_detail_section_decoStatus,
          style: textTheme.titleSmall,
        ),
        if (subtitle != null) ...[
          const SizedBox(width: 6),
          Text(
            subtitle!,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const Spacer(),
        Semantics(
          label: status.inDeco
              ? context.l10n.diveLog_deco_semantics_required
              : context.l10n.diveLog_deco_semantics_notRequired,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: status.inDeco
                  ? Colors.orange.withValues(alpha: 0.2)
                  : Colors.green.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status.inDeco
                  ? context.l10n.diveLog_deco_badge_deco
                  : context.l10n.diveLog_deco_badge_noDeco,
              style: textTheme.labelSmall?.copyWith(
                fontSize: 10,
                color: status.inDeco ? Colors.orange : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        ExcludeSemantics(
          child: Icon(
            Icons.expand_more,
            size: 18,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsRow(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Row(
      children: [
        // NDL or Ceiling
        Expanded(
          child: _buildCompactMetric(
            context,
            value: status.inDeco
                ? '${status.ceilingMeters.toStringAsFixed(1)}m'
                : status.ndlFormatted,
            label: status.inDeco
                ? context.l10n.diveLog_deco_label_ceiling
                : context.l10n.diveLog_deco_label_ndl,
            textTheme: textTheme,
            colorScheme: colorScheme,
          ),
        ),

        // TTS
        Expanded(
          child: _buildCompactMetric(
            context,
            value: status.ttsFormatted,
            label: context.l10n.diveLog_deco_label_tts,
            textTheme: textTheme,
            colorScheme: colorScheme,
          ),
        ),

        // Leading compartment
        Expanded(
          child: _buildCompactMetric(
            context,
            value:
                '#${status.leadingCompartmentNumber} ${status.leadingCompartmentLoading.toStringAsFixed(0)}%',
            label: context.l10n.diveLog_deco_label_leading,
            textTheme: textTheme,
            colorScheme: colorScheme,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactMetric(
    BuildContext context, {
    required String value,
    required String label,
    required TextTheme textTheme,
    required ColorScheme colorScheme,
  }) {
    return Semantics(
      label: '$label: $value',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          children: [
            Text(
              value,
              style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                fontSize: 10,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTissueChart(BuildContext context) {
    return Semantics(
      label: chartSummaryLabel(
        chartType: 'Tissue loading bar',
        description:
            '${status.compartments.length} compartments, leading compartment ${status.leadingCompartmentNumber} at ${status.leadingCompartmentLoading.toStringAsFixed(0)} percent',
      ),
      child: SizedBox(
        height: 40,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: status.compartments.map((comp) {
            final loading = comp.percentLoading.clamp(0.0, 120.0);
            final normalizedHeight = (loading / 120.0).clamp(0.0, 1.0);
            final color = _getLoadingColor(loading);

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0.5),
                child: Container(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.3),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(1),
                    ),
                  ),
                  child: FractionallySizedBox(
                    heightFactor: normalizedHeight,
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(1),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBottomRow(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Row(
      children: [
        Semantics(
          label:
              'Gradient factors: low ${(status.gfLow * 100).toInt()}, high ${(status.gfHigh * 100).toInt()}',
          child: Text(
            'GF: ${(status.gfLow * 100).toInt()}/${(status.gfHigh * 100).toInt()}',
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (status.decoStops.isNotEmpty) ...[
          const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              label:
                  '${context.l10n.diveLog_deco_sectionDecoStops}: ${status.decoStops.take(3).map((s) => '${s.depthFormatted()} ${s.durationFormatted}').join(', ')}',
              child: Text(
                '${context.l10n.diveLog_deco_sectionDecoStops}: ${status.decoStops.take(3).map((s) => '${s.depthFormatted()} ${s.durationFormatted}').join(', ')}',
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ],
    );
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
