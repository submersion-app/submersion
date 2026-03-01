import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_color_schemes.dart';

/// A Subsurface-style tissue loading heat map that visualizes all 16
/// Bühlmann compartment loadings over the full dive duration.
///
/// Each row represents a tissue compartment (fast tissues at top, slow at
/// bottom). Each column represents a time point. Color encodes the tissue
/// loading relative to ambient pressure using Subsurface's two-phase scale:
/// - Below ambient (ongassing): cyan -> blue -> purple -> black
/// - Above ambient (offgassing): green -> yellow -> orange -> red
class TissueHeatMap extends StatelessWidget {
  /// Full time-series of decompression statuses across the dive
  final List<DecoStatus> decoStatuses;

  /// Currently selected point index (for cursor line)
  final int? selectedIndex;

  /// Chart height in logical pixels
  final double height;

  /// Color function mapping tissue loading percentage to a color.
  final TissueColorFn colorFn;

  const TissueHeatMap({
    super.key,
    required this.decoStatuses,
    this.selectedIndex,
    this.height = 48,
    this.colorFn = thermalColor,
  });

  @override
  Widget build(BuildContext context) {
    if (decoStatuses.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Tissue Loading', style: textTheme.titleSmall),
                const Spacer(),
                TissueHeatMapLegend(
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                  colorFn: colorFn,
                ),
              ],
            ),
            const SizedBox(height: 8),
            TissueHeatMapStrip(
              decoStatuses: decoStatuses,
              selectedIndex: selectedIndex,
              height: height,
              colorFn: colorFn,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Fast',
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 9,
                  ),
                ),
                Text(
                  'Slow',
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Just the painted heat map strip without any card or labels.
///
/// Use this to embed the heat map inside another widget's layout.
/// Supports hover (desktop) and tap (mobile) tooltips showing compartment
/// details for each cell.
class TissueHeatMapStrip extends StatefulWidget {
  /// Full time-series of decompression statuses across the dive
  final List<DecoStatus> decoStatuses;

  /// Currently selected point index (for cursor line)
  final int? selectedIndex;

  /// Strip height in logical pixels
  final double height;

  /// Color function mapping tissue loading percentage to a color.
  final TissueColorFn colorFn;

  /// Called when the user hovers over a time index, or null when hover ends.
  final ValueChanged<int?>? onHoverIndexChanged;

  /// Called when the user hovers over a compartment, or null when hover ends.
  /// The value is the compartment index (0-based).
  final ValueChanged<int?>? onCompartmentHoverChanged;

  const TissueHeatMapStrip({
    super.key,
    required this.decoStatuses,
    this.selectedIndex,
    this.height = 32,
    required this.colorFn,
    this.onHoverIndexChanged,
    this.onCompartmentHoverChanged,
  });

  @override
  State<TissueHeatMapStrip> createState() => _TissueHeatMapStripState();
}

class _TissueHeatMapStripState extends State<TissueHeatMapStrip> {
  OverlayEntry? _tooltipOverlay;
  int? _hoveredTimeIdx;
  int? _hoveredCompIdx;
  final LayerLink _layerLink = LayerLink();

  @override
  void dispose() {
    _removeTooltip();
    super.dispose();
  }

  void _removeTooltip() {
    _tooltipOverlay?.remove();
    _tooltipOverlay?.dispose();
    _tooltipOverlay = null;
    final hadHover = _hoveredTimeIdx != null;
    _hoveredTimeIdx = null;
    _hoveredCompIdx = null;
    if (hadHover) {
      widget.onHoverIndexChanged?.call(null);
      widget.onCompartmentHoverChanged?.call(null);
    }
  }

  /// Returns (timeIndex, compartmentIndex) for the given local position.
  (int, int)? _cellAt(Offset localPosition, Size size) {
    if (widget.decoStatuses.isEmpty) return null;
    final numTimePoints = widget.decoStatuses.length;
    final numComps = widget.decoStatuses.first.compartments.length;
    if (numComps == 0) return null;

    final timeIdx = (localPosition.dx / size.width * numTimePoints)
        .floor()
        .clamp(0, numTimePoints - 1);
    final compIdx = (localPosition.dy / size.height * numComps).floor().clamp(
      0,
      numComps - 1,
    );
    return (timeIdx, compIdx);
  }

  void _showTooltipForPosition(Offset localPosition) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final cell = _cellAt(localPosition, box.size);
    if (cell == null) {
      _removeTooltip();
      return;
    }

    final (timeIdx, compIdx) = cell;
    if (timeIdx == _hoveredTimeIdx && compIdx == _hoveredCompIdx) return;

    // Clear old tooltip without firing exit callback
    _tooltipOverlay?.remove();
    _tooltipOverlay?.dispose();
    _tooltipOverlay = null;
    _hoveredTimeIdx = timeIdx;
    _hoveredCompIdx = compIdx;

    widget.onHoverIndexChanged?.call(timeIdx);
    widget.onCompartmentHoverChanged?.call(compIdx);

    final status = widget.decoStatuses[timeIdx];
    final comp = status.compartments[compIdx];
    final ambientPressure = status.ambientPressureBar;
    final isOffgassing = comp.totalInertGas > ambientPressure;

    final gfAtDepth = comp.gradientFactor(ambientPressure);
    final lines = <String>[
      'Compartment ${comp.compartmentNumber}',
      '${comp.percentLoading.toStringAsFixed(1)}% loaded',
      'GF: ${(gfAtDepth * 100).toStringAsFixed(0)}%',
      'N\u2082: ${comp.currentPN2.toStringAsFixed(2)} bar',
      if (comp.currentPHe > 0.001)
        'He: ${comp.currentPHe.toStringAsFixed(2)} bar',
      'Half-time: ${comp.halfTimeN2.toStringAsFixed(0)} min',
      isOffgassing ? 'Offgassing' : 'Ongassing',
    ];
    final message = lines.join('\n');

    // Position tooltip horizontally at the cell center, above the heat map
    final numTimePoints = widget.decoStatuses.length;
    final cellCenterX = (timeIdx + 0.5) / numTimePoints * box.size.width;

    final overlay = OverlayEntry(
      builder: (context) {
        final theme = Theme.of(context);
        return UnconstrainedBox(
          child: CompositedTransformFollower(
            link: _layerLink,
            targetAnchor: Alignment.topLeft,
            followerAnchor: Alignment.bottomCenter,
            offset: Offset(cellCenterX, -4),
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(6),
              color: theme.colorScheme.inverseSurface,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onInverseSurface,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    _tooltipOverlay = overlay;
    Overlay.of(context).insert(overlay);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.decoStatuses.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onHover: (event) => _showTooltipForPosition(event.localPosition),
        onExit: (_) => _removeTooltip(),
        child: GestureDetector(
          onTapDown: (details) {
            _showTooltipForPosition(details.localPosition);
          },
          onTapUp: (_) => _removeTooltip(),
          onHorizontalDragStart: (details) {
            _showTooltipForPosition(details.localPosition);
          },
          onHorizontalDragUpdate: (details) {
            _showTooltipForPosition(details.localPosition);
          },
          onHorizontalDragEnd: (_) => _removeTooltip(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: widget.height,
              width: double.infinity,
              child: CustomPaint(
                painter: _TissueHeatMapPainter(
                  decoStatuses: widget.decoStatuses,
                  selectedIndex: widget.selectedIndex,
                  cursorColor: colorScheme.onSurface,
                  colorFn: widget.colorFn,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small legend showing the Subsurface heat map color scale.
///
/// Shows the two-phase color gradient: cool colors (ongassing) on the left,
/// warm colors (offgassing) on the right, with the ambient boundary marked.
class TissueHeatMapLegend extends StatelessWidget {
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  /// Color function mapping tissue loading percentage to a color.
  final TissueColorFn colorFn;

  /// Label displayed on the left (low-loading) end of the gradient.
  final String leftLabel;

  /// Label displayed on the right (high-loading) end of the gradient.
  final String rightLabel;

  const TissueHeatMapLegend({
    super.key,
    required this.colorScheme,
    required this.textTheme,
    required this.colorFn,
    this.leftLabel = 'On-gassing',
    this.rightLabel = 'Off-gassing',
  });

  @override
  Widget build(BuildContext context) {
    // Sample the color scale at many points to build a smooth gradient
    final colors = <Color>[];
    for (int i = 0; i <= 20; i++) {
      final pct = i * 5.0; // 0, 5, 10, ..., 100
      colors.add(colorFn(pct));
    }

    final labelStyle = textTheme.labelSmall?.copyWith(
      fontSize: 9,
      color: colorScheme.onSurfaceVariant,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(leftLabel, style: labelStyle),
        const SizedBox(width: 4),
        Container(
          width: 60,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: LinearGradient(colors: colors),
          ),
        ),
        const SizedBox(width: 4),
        Text(rightLabel, style: labelStyle),
      ],
    );
  }
}

/// Efficiently paints the 2D tissue heat map using canvas operations.
///
/// Uses Subsurface's algorithm: each cell's color is derived from the tissue's
/// saturation relative to ambient pressure at that time point, mapped through
/// an HSV-based color scale.
class _TissueHeatMapPainter extends CustomPainter {
  final List<DecoStatus> decoStatuses;
  final int? selectedIndex;
  final Color cursorColor;

  /// Color function mapping tissue loading percentage to a color.
  final TissueColorFn colorFn;

  _TissueHeatMapPainter({
    required this.decoStatuses,
    required this.selectedIndex,
    required this.cursorColor,
    required this.colorFn,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (decoStatuses.isEmpty) return;

    final numTimePoints = decoStatuses.length;
    final numCompartments = decoStatuses.first.compartments.length;
    if (numCompartments == 0) return;

    final cellHeight = size.height / numCompartments;

    // For large datasets, sample columns to avoid painting thousands of
    // sub-pixel rectangles. Target roughly 1 column per logical pixel.
    final maxColumns = size.width.ceil();
    final step = numTimePoints > maxColumns ? numTimePoints / maxColumns : 1.0;

    final paint = Paint()..style = PaintingStyle.fill;

    double x = 0;
    double col = 0;
    while (col < numTimePoints) {
      final timeIdx = col.floor().clamp(0, numTimePoints - 1);
      final status = decoStatuses[timeIdx];
      final ambientPressure = status.ambientPressureBar;

      // Calculate next x position based on progress through time points
      final nextX = (col + step) / numTimePoints * size.width;
      final rectWidth = math.max(nextX - x, 1.0);

      for (int row = 0; row < numCompartments; row++) {
        final comp = status.compartments[row];
        final percentage = subsurfacePercentage(comp, ambientPressure);
        paint.color = colorFn(percentage);

        canvas.drawRect(
          Rect.fromLTWH(x, row * cellHeight, rectWidth, cellHeight),
          paint,
        );
      }

      x = nextX;
      col += step;
    }

    // Draw cursor line at selected index
    if (selectedIndex != null &&
        selectedIndex! >= 0 &&
        selectedIndex! < numTimePoints) {
      final cursorX = (selectedIndex! + 0.5) / numTimePoints * size.width;
      final cursorPaint = Paint()
        ..color = cursorColor.withValues(alpha: 0.7)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        Offset(cursorX, 0),
        Offset(cursorX, size.height),
        cursorPaint,
      );
    }
  }

  // colorFn equality works because colorFnForScheme always returns
  // a top-level function reference (not a closure).
  @override
  bool shouldRepaint(_TissueHeatMapPainter oldDelegate) {
    return oldDelegate.decoStatuses != decoStatuses ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.colorFn != colorFn;
  }
}
