import 'package:flutter/material.dart';

import 'package:submersion/core/accessibility/semantic_helpers.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';

/// A 16-bar chart showing tissue compartment saturation levels.
///
/// Traditional dive computer-style visualization showing N2 and He
/// loading as stacked bars for each of the 16 Bühlmann tissue compartments.
class TissueSaturationChart extends StatelessWidget {
  /// The 16 tissue compartments with current loading
  final List<TissueCompartment> compartments;

  /// The index of the leading (most saturated) compartment (1-16)
  final int? leadingCompartmentNumber;

  /// Height of the chart
  final double height;

  /// Whether to show labels below bars
  final bool showLabels;

  /// Whether to animate bar height changes
  final bool animate;

  const TissueSaturationChart({
    super.key,
    required this.compartments,
    this.leadingCompartmentNumber,
    this.height = 100,
    this.showLabels = true,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    if (compartments.isEmpty) {
      return SizedBox(height: height);
    }

    final colorScheme = Theme.of(context).colorScheme;

    // Calculate max loading for scaling (use 120% as max for headroom)
    final maxLoading = compartments
        .map((c) => c.percentLoading)
        .reduce((a, b) => a > b ? a : b)
        .clamp(100.0, 150.0);

    final maxLoadedComp = compartments.reduce(
      (a, b) => a.percentLoading > b.percentLoading ? a : b,
    );

    return Semantics(
      label: chartSummaryLabel(
        chartType: 'Tissue saturation',
        description:
            '${compartments.length} compartments. Most loaded: compartment ${maxLoadedComp.compartmentNumber} at ${maxLoadedComp.percentLoading.toStringAsFixed(0)} percent',
      ),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            // M-value line (100% loading indicator)
            Expanded(
              child: Stack(
                children: [
                  // 100% M-value line
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom:
                        (100 / maxLoading) * (height - (showLabels ? 20 : 0)),
                    child: Container(
                      height: 1,
                      color: colorScheme.error.withValues(alpha: 0.5),
                    ),
                  ),
                  // Bars
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (int i = 0; i < compartments.length; i++)
                        _TissueBar(
                          compartment: compartments[i],
                          maxLoading: maxLoading,
                          isLeading:
                              compartments[i].compartmentNumber ==
                              leadingCompartmentNumber,
                          animate: animate,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // Labels
            if (showLabels)
              SizedBox(
                height: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final comp in compartments)
                      SizedBox(
                        width: 16,
                        child: Text(
                          '${comp.compartmentNumber}',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontSize: 8,
                                color: colorScheme.onSurfaceVariant,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Individual tissue compartment bar
class _TissueBar extends StatelessWidget {
  final TissueCompartment compartment;
  final double maxLoading;
  final bool isLeading;
  final bool animate;

  const _TissueBar({
    required this.compartment,
    required this.maxLoading,
    required this.isLeading,
    required this.animate,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Calculate heights for N2 and He portions
    final n2Loading =
        (compartment.currentPN2 / compartment.surfaceMValue) * 100;
    final heLoading =
        (compartment.currentPHe / compartment.surfaceMValue) * 100;
    final totalLoading = compartment.percentLoading;

    // Calculate bar heights as percentage of available height
    final n2HeightPercent = (n2Loading / maxLoading).clamp(0.0, 1.0);
    final heHeightPercent = (heLoading / maxLoading).clamp(0.0, 1.0);

    // Color based on loading percentage
    final n2Color = _getLoadingColor(totalLoading, colorScheme);
    const heColor = Colors.purple;

    // Border for leading compartment
    final border = isLeading
        ? Border.all(color: colorScheme.primary, width: 2)
        : null;

    const barWidth = 12.0;

    return SizedBox(
      width: barWidth + 4, // Add padding for border
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableHeight = constraints.maxHeight;
          final n2Height = availableHeight * n2HeightPercent;
          final heHeight = availableHeight * heHeightPercent;

          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // He portion (on top)
              if (heHeight > 0)
                _AnimatedBar(
                  width: barWidth,
                  height: heHeight,
                  color: heColor,
                  animate: animate,
                  isTop: true,
                  border: border,
                ),
              // N2 portion
              _AnimatedBar(
                width: barWidth,
                height: n2Height,
                color: n2Color,
                animate: animate,
                isTop: heHeight == 0,
                isBottom: true,
                border: heHeight == 0 ? border : null,
              ),
            ],
          );
        },
      ),
    );
  }

  Color _getLoadingColor(double loading, ColorScheme colorScheme) {
    if (loading > 90) return Colors.red;
    if (loading > 70) return Colors.orange;
    if (loading > 50) return Colors.yellow.shade700;
    return Colors.blue;
  }
}

/// Animated bar segment
class _AnimatedBar extends StatelessWidget {
  final double width;
  final double height;
  final Color color;
  final bool animate;
  final bool isTop;
  final bool isBottom;
  final BoxBorder? border;

  const _AnimatedBar({
    required this.width,
    required this.height,
    required this.color,
    required this.animate,
    this.isTop = false,
    this.isBottom = false,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.only(
      topLeft: isTop ? const Radius.circular(2) : Radius.zero,
      topRight: isTop ? const Radius.circular(2) : Radius.zero,
      bottomLeft: isBottom ? const Radius.circular(2) : Radius.zero,
      bottomRight: isBottom ? const Radius.circular(2) : Radius.zero,
    );

    if (animate) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        width: width,
        height: height.clamp(0, double.infinity),
        decoration: BoxDecoration(
          color: color,
          borderRadius: borderRadius,
          border: border,
        ),
      );
    }

    return Container(
      width: width,
      height: height.clamp(0, double.infinity),
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
        border: border,
      ),
    );
  }
}

/// Legend for the tissue saturation chart
class TissueSaturationLegend extends StatelessWidget {
  const TissueSaturationLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        const _LegendItem(color: Colors.blue, label: 'N₂'),
        const _LegendItem(color: Colors.purple, label: 'He'),
        _LegendItem(
          color: colorScheme.error.withValues(alpha: 0.5),
          label: '100% M-value',
          isLine: true,
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool isLine;

  const _LegendItem({
    required this.color,
    required this.label,
    this.isLine = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: isLine
              ? Container(width: 16, height: 2, color: color)
              : Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
