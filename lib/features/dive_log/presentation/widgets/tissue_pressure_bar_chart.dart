import 'package:flutter/material.dart';

import 'package:submersion/core/accessibility/semantic_helpers.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_tooltip_text.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Subsurface-style bar chart of the 16 compartments' loading, fast to slow.
///
/// Each bar carries a marker at the loading that compartment settles at when
/// fully equilibrated with air at the surface (issue #4228): a desaturated
/// compartment stands at its marker, never at 0%, so the marker is what shows
/// whether a bar still holds load left over from diving. The red line is the
/// surface M-value (100%).
class TissuePressureBarChart extends StatelessWidget {
  final DecoStatus status;

  /// Compartment (0-based) drawn with an outline, or null for none.
  final int? highlightedIndex;

  /// Called with a compartment's index when it is hovered or tapped.
  final ValueChanged<int> onCompartmentHover;

  /// Called when the pointer leaves the chart.
  final VoidCallback onHoverExit;

  const TissuePressureBarChart({
    super.key,
    required this.status,
    required this.highlightedIndex,
    required this.onCompartmentHover,
    required this.onHoverExit,
  });

  static const double chartHeight = 50.0;
  static const double maxLoadingPercent = 120.0;

  /// Height of the surface level marker drawn across each bar.
  static const double markerHeight = 2.0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = context.l10n;
    const mValueBottom = chartHeight * (100.0 / maxLoadingPercent);

    final labelStyle = textTheme.labelSmall?.copyWith(
      fontSize: 11,
      color: colorScheme.onSurfaceVariant,
    );
    final isDark = colorScheme.brightness == Brightness.dark;
    final outlineColor = colorScheme.onSurface.withValues(
      alpha: isDark ? 1.0 : 0.8,
    );
    final markerColor = surfaceLevelMarkerColor(colorScheme);
    final mValueColor = colorScheme.error.withValues(alpha: 0.5);
    final equilibriumN2 = status.surfaceEquilibriumN2Bar;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: chartSummaryLabel(
            chartType: 'Tissue pressure diagram',
            description:
                '${status.compartments.length} compartments showing '
                'nitrogen and helium loading relative to M-value, leading '
                'compartment ${status.leadingCompartmentNumber} at '
                '${status.leadingCompartmentLoading.toStringAsFixed(0)}'
                ' percent',
          ),
          child: SizedBox(
            height: chartHeight,
            child: Stack(
              children: [
                MouseRegion(
                  onExit: (_) => onHoverExit(),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final entry in status.compartments.asMap().entries)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 0.5,
                            ),
                            child: MouseRegion(
                              onEnter: (_) => onCompartmentHover(entry.key),
                              child: GestureDetector(
                                onTapDown: (_) => onCompartmentHover(entry.key),
                                child: Tooltip(
                                  message: tissueCompartmentTooltip(
                                    l10n,
                                    status,
                                    entry.value,
                                  ),
                                  child: _CompartmentBar(
                                    comp: entry.value,
                                    equilibriumPercent: entry.value
                                        .equilibriumLoadingPercent(
                                          equilibriumN2,
                                        ),
                                    markerColor: markerColor,
                                    outlineColor: entry.key == highlightedIndex
                                        ? outlineColor
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // M-value reference line
                Positioned(
                  bottom: mValueBottom,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Container(height: 1, color: mValueColor),
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
            Text(l10n.diveLog_deco_tissueFast, style: labelStyle),
            Text(l10n.diveLog_deco_tissueSlow, style: labelStyle),
          ],
        ),
        const SizedBox(height: 2),
        Wrap(
          spacing: 12,
          runSpacing: 2,
          children: [
            _LegendItem(
              key: const ValueKey('tissue-legend-surface-level'),
              color: markerColor,
              swatchHeight: markerHeight,
              label: l10n.diveLog_deco_surfaceLevel,
              style: labelStyle,
            ),
            _LegendItem(
              key: const ValueKey('tissue-legend-m-value'),
              color: mValueColor,
              swatchHeight: 1,
              label: l10n.diveLog_deco_mValue,
              style: labelStyle,
            ),
          ],
        ),
      ],
    );
  }

  /// Color of the surface level marker: high contrast against both the
  /// green-to-red bars and the card, in light and dark mode.
  static Color surfaceLevelMarkerColor(ColorScheme colorScheme) =>
      colorScheme.onSurface.withValues(alpha: 0.85);
}

class _CompartmentBar extends StatelessWidget {
  final TissueCompartment comp;
  final double equilibriumPercent;
  final Color markerColor;
  final Color? outlineColor;

  const _CompartmentBar({
    required this.comp,
    required this.equilibriumPercent,
    required this.markerColor,
    required this.outlineColor,
  });

  @override
  Widget build(BuildContext context) {
    const chartHeight = TissuePressureBarChart.chartHeight;
    const maxLoading = TissuePressureBarChart.maxLoadingPercent;
    const markerHeight = TissuePressureBarChart.markerHeight;

    final totalLoading = comp.percentLoading.clamp(0.0, maxLoading);
    final barHeight = chartHeight * (totalLoading / maxLoading);

    final totalGas = comp.totalInertGas;
    final heRatio = totalGas > 0 ? comp.currentPHe / totalGas : 0.0;
    final n2Height = barHeight * (1.0 - heRatio);
    final heHeight = barHeight * heRatio;

    final barColumn = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (heHeight > 0.5)
          Container(
            height: heHeight,
            decoration: BoxDecoration(
              color: Colors.deepPurple.withValues(alpha: 0.8),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(1),
              ),
            ),
          ),
        Container(
          height: n2Height.clamp(0.0, barHeight),
          decoration: BoxDecoration(
            color: _n2Color(totalLoading),
            borderRadius: BorderRadius.vertical(
              top: heHeight > 0.5 ? Radius.zero : const Radius.circular(1),
            ),
          ),
        ),
      ],
    );

    // Highlight via foregroundDecoration so the outline is painted OVER the
    // bar without enlarging it. A decoration border would inset the child and
    // add its width to the box on every side, making the bar taller than its
    // fixed-height slot (overflowing when the bar is already full height) and
    // wider than its unhighlighted neighbours (hover jitter).
    final bar = outlineColor != null
        ? Container(
            foregroundDecoration: BoxDecoration(
              border: Border.all(color: outlineColor!, width: 2),
              borderRadius: BorderRadius.circular(2),
            ),
            child: barColumn,
          )
        : barColumn;

    // Centered on the equilibrium loading, kept inside the slot.
    final markerBottom =
        (chartHeight *
                    (equilibriumPercent.clamp(0.0, maxLoading) / maxLoading) -
                markerHeight / 2)
            .clamp(0.0, chartHeight - markerHeight);

    return SizedBox(
      height: chartHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [bar],
            ),
          ),
          Positioned(
            key: ValueKey('tissue-surface-marker-${comp.compartmentNumber}'),
            left: 0,
            right: 0,
            bottom: markerBottom,
            height: markerHeight,
            child: IgnorePointer(child: ColoredBox(color: markerColor)),
          ),
        ],
      ),
    );
  }

  static Color _n2Color(double loading) {
    if (loading >= 100) return Colors.red;
    if (loading >= 80) return Colors.orange;
    if (loading >= 60) return Colors.amber;
    return Colors.green;
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final double swatchHeight;
  final String label;
  final TextStyle? style;

  const _LegendItem({
    super.key,
    required this.color,
    required this.swatchHeight,
    required this.label,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Container(width: 12, height: swatchHeight, color: color),
        ),
        const SizedBox(width: 4),
        Text(label, style: style),
      ],
    );
  }
}
