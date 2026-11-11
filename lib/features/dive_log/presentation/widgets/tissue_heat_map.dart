import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/features/dive_log/presentation/widgets/highlight_outline.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_color_schemes.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_tooltip_text.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A Subsurface-style tissue loading heat map that visualizes all 16
/// Bühlmann compartment loadings over the full dive duration.
///
/// Each row represents a tissue compartment (fast tissues at top, slow at
/// bottom). Each column represents a time point. Color encodes the tissue
/// loading relative to ambient pressure using Subsurface's two-phase scale:
/// - Undersaturated (below ambient): cyan -> blue -> purple -> black
/// - Supersaturated (above ambient): green -> yellow -> orange -> red
///
/// The halves say nothing about which way gas moves: a compartment between
/// the inspired and the ambient pressure is undersaturated yet already
/// offgassing. Direction is the badges' job (see `DecoStatus.n2Exchange`).
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
                Text(
                  context.l10n.diveLog_tissue_title,
                  style: textTheme.titleSmall,
                ),
                const SizedBox(width: 8),
                // Bounded width, so the legend's labels can shorten.
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TissueHeatMapLegend(
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                      colorFn: colorFn,
                    ),
                  ),
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
                  context.l10n.diveLog_deco_tissueFast,
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 9,
                  ),
                ),
                Text(
                  context.l10n.diveLog_deco_tissueSlow,
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

  /// When true, the strip fills its parent's height instead of using [height].
  final bool flexible;

  /// Index of the compartment to highlight with an outline (0-based).
  /// Typically driven by hover on the bar chart or this heat map itself.
  final int? hoveredCompartmentIndex;

  const TissueHeatMapStrip({
    super.key,
    required this.decoStatuses,
    this.selectedIndex,
    this.height = 32,
    required this.colorFn,
    this.onHoverIndexChanged,
    this.onCompartmentHoverChanged,
    this.flexible = false,
    this.hoveredCompartmentIndex,
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
    final message = tissueCompartmentTooltip(context.l10n, status, comp);

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

    final highlightColor = HighlightOutline.heatMapColorOf(
      Theme.of(context).colorScheme,
    );

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
              height: widget.flexible ? null : widget.height,
              width: double.infinity,
              child: CustomPaint(
                painter: _TissueHeatMapPainter(
                  decoStatuses: widget.decoStatuses,
                  selectedIndex: widget.selectedIndex,
                  colorFn: widget.colorFn,
                  hoveredCompartmentIndex: widget.hoveredCompartmentIndex,
                  highlightColor: highlightColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small legend showing the Subsurface heat map color scale: the cool,
/// undersaturated half (below ambient) at the start, the warm,
/// supersaturated half (above ambient) at the end.
///
/// The legend names the halves itself, in the standard deco terms (issue
/// #4228). The scale is measured against AMBIENT pressure, so it must not
/// borrow "Ongassing"/"Offgassing": those are measured against the inspired
/// gas, and a compartment between the two pressures is undersaturated yet
/// already offgassing, which would contradict the compartment badges.
class TissueHeatMapLegend extends StatelessWidget {
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  /// Color function mapping tissue loading percentage to a color.
  final TissueColorFn colorFn;

  const TissueHeatMapLegend({
    super.key,
    required this.colorScheme,
    required this.textTheme,
    required this.colorFn,
  });

  @override
  Widget build(BuildContext context) {
    final leftLabel = context.l10n.diveLog_deco_heatMapUndersaturated;
    final rightLabel = context.l10n.diveLog_deco_heatMapSupersaturated;
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
        // Flexible: some locales' labels are long, and a narrow card must
        // shorten them rather than overflow.
        Flexible(
          child: Text(
            leftLabel,
            style: labelStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 4),
        Container(
          width: 60,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            // Directional, like the Row around it: in RTL the labels swap
            // sides, so the low end must follow leftLabel to the right.
            gradient: LinearGradient(
              begin: AlignmentDirectional.centerStart,
              end: AlignmentDirectional.centerEnd,
              colors: colors,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            rightLabel,
            style: labelStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
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

  /// Color function mapping tissue loading percentage to a color.
  final TissueColorFn colorFn;

  /// Index of the compartment row to outline (0-based), or null for none.
  final int? hoveredCompartmentIndex;

  /// Colour of the time cursor and the compartment row outline.
  final Color highlightColor;

  _TissueHeatMapPainter({
    required this.decoStatuses,
    required this.selectedIndex,
    required this.colorFn,
    required this.highlightColor,
    this.hoveredCompartmentIndex,
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

    // The cursor and the row outline use HighlightOutline.heatMapColorOf:
    // the cells under them run from pure black to white, where the theme's
    // text colour vanished in one theme or the other (issue #4431).
    final highlightPaint = HighlightOutline.strokeOf(highlightColor);

    // Draw cursor line at selected index
    if (selectedIndex != null &&
        selectedIndex! >= 0 &&
        selectedIndex! < numTimePoints) {
      final cursorX = (selectedIndex! + 0.5) / numTimePoints * size.width;
      canvas.drawLine(
        Offset(cursorX, 0),
        Offset(cursorX, size.height),
        highlightPaint,
      );
    }

    // Draw outline around hovered compartment row
    if (hoveredCompartmentIndex != null &&
        hoveredCompartmentIndex! >= 0 &&
        hoveredCompartmentIndex! < numCompartments) {
      canvas.drawRect(
        _rowOutlineRect(hoveredCompartmentIndex!, cellHeight, size),
        highlightPaint,
      );
    }
  }

  /// Where the row outline's line is centred for compartment [row].
  ///
  /// A row is only a few pixels tall, so the line sits just outside it, over
  /// the edges of the neighbouring rows, and leaves the highlighted row
  /// itself in full view. Every edge is kept inside the strip, where a line
  /// outside it would be clipped away: the two ends, the first row's top and
  /// the last row's bottom sit just inside the strip's edge instead, which
  /// leaves most of a row in view because the line is narrow.
  static Rect _rowOutlineRect(int row, double cellHeight, Size size) {
    const half = HighlightOutline.width / 2;
    final top = row * cellHeight;
    final maxY = math.max(half, size.height - half);
    return Rect.fromLTRB(
      half,
      (top - half).clamp(half, maxY),
      math.max(half, size.width - half),
      (top + cellHeight + half).clamp(half, maxY),
    );
  }

  // colorFn equality works because colorFnForScheme always returns
  // a top-level function reference (not a closure).
  @override
  bool shouldRepaint(_TissueHeatMapPainter oldDelegate) {
    return oldDelegate.decoStatuses != decoStatuses ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.colorFn != colorFn ||
        oldDelegate.hoveredCompartmentIndex != hoveredCompartmentIndex ||
        oldDelegate.highlightColor != highlightColor;
  }
}
