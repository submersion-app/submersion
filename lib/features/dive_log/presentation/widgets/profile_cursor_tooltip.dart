import 'package:flutter/material.dart';

import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart'
    show TooltipRow;

/// Horizontal gap, in logical pixels, between the touch/hover cursor (the
/// vertical indicator line fl_chart draws at the touched sample) and the
/// tooltip box's nearest edge. 40, not the original 8, per direct feedback
/// once the tooltip was actually tried live: 8px read as touching the
/// cursor line rather than sitting clearly beside it.
const double tooltipCursorGap = 40;

/// The tooltip box's highest allowed top edge: [plotRect.top] plus this
/// margin. The box's bottom edge otherwise tracks the cursor's Y (see
/// [computeTooltipBoxPosition]), growing upward from it; this is only the
/// ceiling for when the cursor sits high enough that the box would
/// otherwise be pushed above the plot.
const double tooltipTopMargin = 8;

/// Cap on the tooltip box's content width, carried over from the old
/// fl_chart bubble's `maxContentWidth: 320` -- wide enough for a tank row
/// carrying the gas type (e.g. "Tank 1 (EAN32) 2064 psi") without wrapping.
const double tooltipMaxContentWidth = 320;

/// Base row font size, matching the old fl_chart bubble's monospace rows.
const double tooltipBaseFontSize = 14;

/// Estimated natural height of one row at [tooltipBaseFontSize], including
/// inter-row spacing. Used only to size-estimate the box before the shrink
/// factor is applied; the actual `Text` widgets still reflow within it.
const double tooltipBaseRowHeight = 20;

/// Vertical + horizontal content padding inside the tooltip box.
const double tooltipContentPadding = 8;

/// Fixed dark background, not the theme's `colorScheme.inverseSurface`:
/// that token is designed to invert with the theme (it renders light in a
/// dark theme, meant for things like snackbars), which left this box
/// noticeably lighter than the old fl_chart bubble it replaced. This keeps
/// it dark regardless of the active theme, matching that original bubble.
const Color tooltipBackgroundColor = Color(0xFF1C1C1E);

/// Row text colour against [tooltipBackgroundColor].
const Color tooltipTextColor = Color(0xFFF2F2F2);

/// Floor for the text-shrink factor: rows never render smaller than this
/// fraction of [tooltipBaseFontSize] (here, 60% -> 8.4px), so a pathological
/// number of enabled metrics degrades to a small but legible tooltip rather
/// than an unreadable sliver. Beyond this floor the box may occupy more than
/// the available height rather than clip -- rare in practice (it takes on
/// the order of 30+ simultaneous rows in a short window to hit it).
const double tooltipMinScale = 0.6;

/// Computes the uniform shrink factor applied to the tooltip's rows so their
/// combined natural height fits within [availableHeight].
///
/// Returns 1.0 (no shrink) when the content already fits or either input is
/// non-positive. Otherwise returns `availableHeight / naturalHeight`, floored
/// at [minScale] so text never becomes illegibly small.
double computeTooltipScaleFactor({
  required double naturalHeight,
  required double availableHeight,
  double minScale = tooltipMinScale,
}) {
  if (naturalHeight <= 0 || availableHeight <= 0) return 1.0;
  if (naturalHeight <= availableHeight) return 1.0;
  final scale = availableHeight / naturalHeight;
  return scale.clamp(minScale, 1.0);
}

/// Computes the tooltip box's top-left position given the cursor position it
/// anchors to horizontally and the plot rect it must stay inside.
///
/// Horizontally, the box is nominally placed [gap] logical pixels to the
/// right of [cursorLocal] (clear of the vertical indicator line fl_chart
/// draws through it), flipped to the cursor's left side first if it would
/// otherwise overflow [plotRect.right], then clamped so it never extends
/// past either horizontal edge.
///
/// Vertically, the box's bottom edge sits at the cursor's Y, so it grows
/// upward from wherever the cursor is -- never lower than
/// [tooltipTopMargin] below [plotRect.top], so a cursor near the top of the
/// plot cannot push the box above it.
Offset computeTooltipBoxPosition({
  required Offset cursorLocal,
  required Size boxSize,
  required Rect plotRect,
  double gap = tooltipCursorGap,
}) {
  final maxLeft = plotRect.right - boxSize.width;
  final minLeft = plotRect.left;

  var left = cursorLocal.dx + gap;
  if (left > maxLeft) {
    final flippedLeft = cursorLocal.dx - gap - boxSize.width;
    left = flippedLeft >= minLeft ? flippedLeft : maxLeft;
  }
  left = left.clamp(minLeft, minLeft > maxLeft ? minLeft : maxLeft);

  final minTop = plotRect.top + tooltipTopMargin;
  final desiredTop = cursorLocal.dy - boxSize.height;
  final top = desiredTop < minTop ? minTop : desiredTop;

  return Offset(left, top);
}

/// The fullscreen profile chart's own in-chart, cursor-following tooltip
/// (the dive detail page's embedded chart uses fl_chart's own native bubble
/// instead -- see [DiveProfileChart.tooltipNativeBubble] -- and the
/// `tooltipBelow` path, used by the dive-list side panel, renders its own
/// overlay elsewhere and never reaches this widget). This widget:
/// - tracks the cursor horizontally, with its bottom edge at the cursor's Y
///   so it grows upward from it, never pushed above the plot's top edge
///   (see [computeTooltipBoxPosition]),
/// - clamps to the plot rect so it can never overflow it, and
/// - shrinks its text (never clips) when the rows would not otherwise fit
///   in the available vertical space (see [computeTooltipScaleFactor]).
///
/// Rendered as a `Positioned` Stack layer alongside the chart's other widget
/// overlays (photo markers, safety findings, ...), wrapped in [IgnorePointer]
/// by the caller so it never steals the touch/hover that drives it.
class ProfileCursorTooltip extends StatelessWidget {
  /// Rows to render, built by [DiveProfileChart]'s shared tooltip row
  /// builder. Empty hides the tooltip.
  final List<TooltipRow> rows;

  /// The cursor's local position in the same coordinate space as [insets]
  /// (the chart's Stack-local coordinates).
  final Offset cursorLocal;

  /// Reserved axis gutters around the plot rect (the chart's `_plotInsets`).
  final ({double left, double top, double right, double bottom}) insets;

  /// The metric currently hover-highlighted on the chart (its line drawn
  /// thicker, or the ascent-rate bars lit up), so the matching row renders
  /// bold instead of every row looking equally important. Null renders every
  /// row the same.
  final ProfileRightAxisMetric? highlightedMetric;

  const ProfileCursorTooltip({
    super.key,
    required this.rows,
    required this.cursorLocal,
    required this.insets,
    this.highlightedMetric,
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final plotRect = Rect.fromLTWH(
          insets.left,
          insets.top,
          constraints.maxWidth - insets.left - insets.right,
          constraints.maxHeight - insets.top - insets.bottom,
        );
        if (plotRect.width <= 0 || plotRect.height <= 0) {
          return const SizedBox.shrink();
        }

        final naturalHeight =
            tooltipContentPadding * 2 + rows.length * tooltipBaseRowHeight;
        final scale = computeTooltipScaleFactor(
          naturalHeight: naturalHeight,
          availableHeight: plotRect.height,
        );
        final boxWidth = tooltipMaxContentWidth < plotRect.width
            ? tooltipMaxContentWidth
            : plotRect.width;
        final boxHeight = naturalHeight * scale;

        final position = computeTooltipBoxPosition(
          cursorLocal: cursorLocal,
          boxSize: Size(boxWidth, boxHeight),
          plotRect: plotRect,
        );

        final fontSize = tooltipBaseFontSize * scale;
        final rowStyle = TextStyle(
          fontFamily: 'RobotoMono',
          fontSize: fontSize,
          color: tooltipTextColor,
          fontFeatures: const [FontFeature.tabularFigures()],
        );

        return Stack(
          children: [
            Positioned(
              left: position.dx,
              top: position.dy,
              width: boxWidth,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: tooltipBackgroundColor,
                  borderRadius: BorderRadius.circular(6 * scale),
                ),
                child: Padding(
                  padding: EdgeInsets.all(tooltipContentPadding * scale),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final row in rows)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 1 * scale),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 8 * scale,
                                height: 8 * scale,
                                margin: EdgeInsets.only(right: 6 * scale),
                                decoration: BoxDecoration(
                                  color: row.bulletColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  row.label,
                                  style:
                                      row.metric != null &&
                                          row.metric == highlightedMetric
                                      ? rowStyle.copyWith(
                                          fontWeight: FontWeight.bold,
                                        )
                                      : rowStyle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 12 * scale),
                              // Flexible too (not just the label): a long
                              // value (e.g. a tank row with its gas type)
                              // must never push the row past the box's
                              // fixed width, which the label's own
                              // Flexible alone cannot guarantee once the
                              // value's own natural width is the culprit.
                              // maxLines: 1 on both Text widgets keeps a row
                              // to one line -- ellipsis alone only elides
                              // overflow within the given number of lines, it
                              // does not by itself prevent wrapping to a
                              // second one, which would make the box taller
                              // than computeTooltipScaleFactor's estimate.
                              Flexible(
                                child: Text(
                                  row.value,
                                  style: rowStyle.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
