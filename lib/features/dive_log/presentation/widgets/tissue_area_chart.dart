import 'package:flutter/material.dart';

import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_color_schemes.dart';

/// A tissue loading area chart that visualizes compartment loading curves
/// for all 16 Buhlmann compartments as filled areas over time.
///
/// In compact mode, only the leading compartment's loading curve is drawn.
/// In expanded mode, all 16 compartments are drawn as semi-transparent
/// filled areas (slowest first so fast tissues draw on top).
///
/// Supports hover (desktop) and tap/drag (mobile) tooltips showing the
/// leading compartment details at the hovered time index.
class TissueAreaChart extends StatefulWidget {
  /// Full time-series of decompression statuses across the dive.
  final List<DecoStatus> decoStatuses;

  /// Currently selected profile point index (for cursor line).
  final int? selectedIndex;

  /// Chart height in logical pixels.
  final double height;

  /// Whether the chart is in expanded mode (shows all 16 compartments).
  final bool isExpanded;

  /// Color function mapping tissue loading percentage to a color.
  final TissueColorFn colorFn;

  /// Called when the user hovers over a time index, or null when hover ends.
  final ValueChanged<int?>? onHoverIndexChanged;

  /// Called when the user hovers over a compartment, or null when hover ends.
  /// The value is the compartment index (0-based).
  final ValueChanged<int?>? onCompartmentHoverChanged;

  const TissueAreaChart({
    super.key,
    required this.decoStatuses,
    required this.colorFn,
    this.selectedIndex,
    this.height = 72,
    this.isExpanded = false,
    this.onHoverIndexChanged,
    this.onCompartmentHoverChanged,
  });

  @override
  State<TissueAreaChart> createState() => _TissueAreaChartState();
}

class _TissueAreaChartState extends State<TissueAreaChart> {
  OverlayEntry? _tooltipOverlay;
  int? _hoveredTimeIdx;
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
    if (hadHover) {
      widget.onHoverIndexChanged?.call(null);
      widget.onCompartmentHoverChanged?.call(null);
    }
  }

  void _showTooltipForPosition(Offset localPosition) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || box.size.width <= 0) return;

    final numTimePoints = widget.decoStatuses.length;
    if (numTimePoints == 0) {
      _removeTooltip();
      return;
    }

    final timeIdx = (localPosition.dx / box.size.width * numTimePoints)
        .floor()
        .clamp(0, numTimePoints - 1);

    if (timeIdx == _hoveredTimeIdx) return;

    // Clear old tooltip without firing exit callback
    _tooltipOverlay?.remove();
    _tooltipOverlay?.dispose();
    _tooltipOverlay = null;
    _hoveredTimeIdx = timeIdx;

    widget.onHoverIndexChanged?.call(timeIdx);

    // Find leading compartment at this time index
    final status = widget.decoStatuses[timeIdx];
    final ambient = status.ambientPressureBar;
    int leadingCompIdx = 0;
    double maxPct = 0;
    for (int i = 0; i < status.compartments.length; i++) {
      final pct = subsurfacePercentage(status.compartments[i], ambient);
      if (pct > maxPct) {
        maxPct = pct;
        leadingCompIdx = i;
      }
    }

    widget.onCompartmentHoverChanged?.call(leadingCompIdx);

    final comp = status.compartments[leadingCompIdx];
    final isOffgassing = comp.totalInertGas > ambient;
    final gfAtDepth = comp.gradientFactor(ambient);

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

    // Position tooltip horizontally at the time index, above the chart
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
          onTapDown: (details) =>
              _showTooltipForPosition(details.localPosition),
          onTapUp: (_) => _removeTooltip(),
          onHorizontalDragStart: (details) =>
              _showTooltipForPosition(details.localPosition),
          onHorizontalDragUpdate: (details) =>
              _showTooltipForPosition(details.localPosition),
          onHorizontalDragEnd: (_) => _removeTooltip(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: widget.height,
              width: double.infinity,
              child: CustomPaint(
                painter: _TissueAreaChartPainter(
                  decoStatuses: widget.decoStatuses,
                  selectedIndex: widget.selectedIndex,
                  isExpanded: widget.isExpanded,
                  colorFn: widget.colorFn,
                  cursorColor: colorScheme.onSurface,
                  mValueLineColor: colorScheme.error,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter that draws tissue loading curves as filled areas.
///
/// In compact mode, draws only the leading compartment's loading curve.
/// In expanded mode, draws all 16 compartments as semi-transparent layers,
/// painting slowest compartments first so fast tissues appear on top.
class _TissueAreaChartPainter extends CustomPainter {
  final List<DecoStatus> decoStatuses;
  final int? selectedIndex;
  final bool isExpanded;
  final TissueColorFn colorFn;
  final Color cursorColor;
  final Color mValueLineColor;

  _TissueAreaChartPainter({
    required this.decoStatuses,
    required this.selectedIndex,
    required this.isExpanded,
    required this.colorFn,
    required this.cursorColor,
    required this.mValueLineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (decoStatuses.isEmpty) return;

    final numTimePoints = decoStatuses.length;
    final numCompartments = decoStatuses.first.compartments.length;
    if (numCompartments == 0) return;

    const maxPercent = 120.0;

    // Column sampling for performance: target ~1 column per logical pixel
    final maxColumns = size.width.ceil();
    final step = numTimePoints > maxColumns ? numTimePoints / maxColumns : 1.0;

    // Draw M-value reference line at 100%
    final mValueY = size.height * (1.0 - 100.0 / maxPercent);
    final mPaint = Paint()
      ..color = mValueLineColor.withValues(alpha: 0.3)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, mValueY), Offset(size.width, mValueY), mPaint);

    if (isExpanded) {
      _paintExpanded(
        canvas,
        size,
        numTimePoints,
        numCompartments,
        maxPercent,
        step,
      );
    } else {
      _paintCompact(canvas, size, numTimePoints, maxPercent, step);
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

  /// Draws only the leading compartment's loading curve as a single
  /// filled area with a stroked top edge.
  void _paintCompact(
    Canvas canvas,
    Size size,
    int numTimePoints,
    double maxPercent,
    double step,
  ) {
    final fillPath = Path();
    final strokePath = Path();

    // Start fill path at bottom-left
    fillPath.moveTo(0, size.height);

    double pctSum = 0;
    int sampleCount = 0;
    bool firstStroke = true;
    double col = 0;

    while (col < numTimePoints) {
      final timeIdx = col.floor().clamp(0, numTimePoints - 1);
      final status = decoStatuses[timeIdx];
      final ambient = status.ambientPressureBar;

      // Find leading compartment (highest percentage)
      double maxPct = 0;
      for (final comp in status.compartments) {
        final pct = subsurfacePercentage(comp, ambient);
        if (pct > maxPct) maxPct = pct;
      }
      pctSum += maxPct;
      sampleCount++;

      final x = col / numTimePoints * size.width;
      final y =
          size.height * (1.0 - maxPct.clamp(0.0, maxPercent) / maxPercent);

      fillPath.lineTo(x, y);

      if (firstStroke) {
        strokePath.moveTo(x, y);
        firstStroke = false;
      } else {
        strokePath.lineTo(x, y);
      }

      col += step;
    }

    // Close fill path along bottom
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    final avgPct = sampleCount > 0 ? pctSum / sampleCount : 50.0;

    final fillPaint = Paint()
      ..color = colorFn(avgPct).withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Stroke the top edge
    final strokePaint = Paint()
      ..color = colorFn(avgPct)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(strokePath, strokePaint);
  }

  /// Draws all 16 compartments as stroked lines.
  /// Paints slowest compartments first so fast tissues draw on top.
  /// Each compartment gets a distinct hue based on its index (0-15)
  /// so lines are visually distinguishable regardless of loading level.
  void _paintExpanded(
    Canvas canvas,
    Size size,
    int numTimePoints,
    int numCompartments,
    double maxPercent,
    double step,
  ) {
    for (int compIdx = numCompartments - 1; compIdx >= 0; compIdx--) {
      final strokePath = Path();
      bool firstStroke = true;
      double col = 0;

      while (col < numTimePoints) {
        final timeIdx = col.floor().clamp(0, numTimePoints - 1);
        final status = decoStatuses[timeIdx];
        final ambient = status.ambientPressureBar;
        final comp = status.compartments[compIdx];
        final pct = subsurfacePercentage(comp, ambient);

        final x = col / numTimePoints * size.width;
        final y = size.height * (1.0 - pct.clamp(0.0, maxPercent) / maxPercent);

        if (firstStroke) {
          strokePath.moveTo(x, y);
          firstStroke = false;
        } else {
          strokePath.lineTo(x, y);
        }

        col += step;
      }

      // Hue spread: 0 (red/fast) through 240 (blue/slow)
      final hue = compIdx / (numCompartments - 1) * 240.0;
      final lineColor = HSVColor.fromAHSV(1.0, hue, 0.8, 0.9).toColor();

      final strokePaint = Paint()
        ..color = lineColor.withValues(alpha: 0.7)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawPath(strokePath, strokePaint);
    }
  }

  // colorFn equality works because colorFnForScheme always returns
  // a top-level function reference (not a closure).
  @override
  bool shouldRepaint(_TissueAreaChartPainter oldDelegate) {
    return oldDelegate.decoStatuses != decoStatuses ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.isExpanded != isExpanded ||
        oldDelegate.colorFn != colorFn ||
        oldDelegate.cursorColor != cursorColor ||
        oldDelegate.mValueLineColor != mValueLineColor;
  }
}
