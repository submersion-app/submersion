import 'package:flutter/material.dart';

import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart'
    show ChartOnlyMetric, TooltipRow;

/// Horizontal gap, in logical pixels, between the touch/hover cursor (the
/// vertical indicator line fl_chart draws at the touched sample) and the
/// tooltip box's nearest edge. 40, not the original 8, per direct feedback
/// once the tooltip was actually tried live: 8px read as touching the
/// cursor line rather than sitting clearly beside it.
const double tooltipCursorGap = 40;

/// Margin the box's bottom edge keeps clear of `plotRect.bottom` when the
/// cursor is low enough to otherwise push it into the safety-lane area
/// below the plot (see [computeTooltipBoxPosition]).
const double tooltipTopMargin = 8;

/// How far above the plot's top edge the tooltip box may grow before it
/// hits its hard ceiling and stops rising (see [computeTooltipBoxPosition])
/// -- generous enough for the legend row above the chart, but finite, so
/// the box can never wander past that into space that does not belong to
/// the chart at all.
const double tooltipCeilingHeadroom = 200;

/// Cap on the tooltip box's content width, carried over from the old
/// fl_chart bubble's `maxContentWidth: 320` -- wide enough for a tank row
/// carrying the gas type (e.g. "Tank 1 (EAN32) 2064 psi") without wrapping.
const double tooltipMaxContentWidth = 320;

/// Base row font size, matching the old fl_chart bubble's monospace rows.
const double tooltipBaseFontSize = 14;

/// Vertical + horizontal content padding inside the tooltip box.
const double tooltipContentPadding = 8;

/// A row's own vertical padding (`EdgeInsets.symmetric(vertical: 1)` around
/// each row, at scale 1.0) -- 1 logical pixel on top and bottom.
const double _rowVerticalPadding = 2;

/// The bullet dot's diameter at scale 1.0.
const double _rowBulletSize = 8;

double? _cachedRowTextHeight;

/// Safety margin applied on top of the raw [TextPainter] measurement in
/// [_measuredRowHeight]: the actual `Text` widgets in the row (inside a
/// `Row`/`Padding`/`Flexible` tree, with the platform's real text renderer
/// rather than a bare paragraph) reliably came out taller than the bare
/// measurement by a roughly constant factor, not merely a rounding error.
/// Overestimating here is the safe direction -- it only pushes the box a
/// little further than strictly necessary -- while underestimating is what
/// let the box overlap whatever sits above the chart in the first place.
const double _rowHeightSafetyFactor = 1.15;

/// Real height of one tooltip row at [tooltipBaseFontSize] and scale 1.0,
/// measured with a [TextPainter] using the exact same font as the rendered
/// rows (plus [_rowHeightSafetyFactor]), then cached (it never changes at
/// runtime).
///
/// A guessed constant here previously stood in for this, and RobotoMono's
/// real line height did not match it closely enough: the clamp and shrink
/// calculations built on that guess let the box's real height quietly
/// exceed what they assumed, so a box that should have been clamped inside
/// the plot instead grew tall enough to overlap the legend above it (issue
/// #2228 follow-up).
double _measuredRowHeight() {
  final textHeight = _cachedRowTextHeight ??= (TextPainter(
    text: const TextSpan(
      text: 'Ag0',
      style: TextStyle(
        fontFamily: 'RobotoMono',
        fontSize: tooltipBaseFontSize,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout()).height;
  final rowContentHeight = textHeight > _rowBulletSize
      ? textHeight
      : _rowBulletSize;
  return (rowContentHeight + _rowVerticalPadding) * _rowHeightSafetyFactor;
}

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

/// Computes the tooltip box's horizontal position and its bottom edge's Y,
/// given the cursor position it anchors to and the plot rect it must stay
/// inside.
///
/// Horizontally, the box is nominally placed [gap] logical pixels to the
/// right of [cursorLocal] (clear of the vertical indicator line fl_chart
/// draws through it), flipped to the cursor's left side first if it would
/// otherwise overflow [plotRect.right], then clamped so it never extends
/// past either horizontal edge.
///
/// Vertically, the returned Y is the box's bottom edge, at the cursor's Y --
/// the caller positions the box with a `bottom` (not `top`) offset derived
/// from it, so the box grows upward from exactly the cursor's height
/// regardless of the box's own real (as-laid-out) height. It tracks the
/// cursor this way except at its two edges:
/// - low: it stops following once the cursor goes low enough that the
///   bottom edge would otherwise pass `plotRect.bottom - tooltipTopMargin`
///   (so it never trails into the safety-lane area below the plot);
/// - high: with enough active metrics the box can be taller than the room
///   between the cursor and the plot's top edge. [boxSize] lets it grow
///   above the plot into whatever the caller's Clip.none exposes above it
///   (the legend), but not past `plotRect.top - tooltipCeilingHeadroom` --
///   past that hard ceiling it stops rising, and the bottom edge detaches
///   from the cursor rather than the box continuing to grow off the top of
///   the chart entirely (issue #2228 follow-up: an earlier version of this
///   clamp used a height estimate inflated enough that it triggered long
///   before the box was actually that tall, which read as the tooltip
///   getting stuck instead of following the pointer -- this one only ever
///   engages once the box's real height genuinely reaches the ceiling).
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

  final maxBottom = plotRect.bottom - tooltipTopMargin;
  var bottom = cursorLocal.dy > maxBottom ? maxBottom : cursorLocal.dy;

  // Hard ceiling: once the box's own real height would push its top past
  // this point, it stops rising -- the bottom edge detaches from the
  // cursor rather than the box continuing to grow off the top of the
  // chart entirely.
  final ceiling = plotRect.top - tooltipCeilingHeadroom;
  final minBottom = ceiling + boxSize.height;
  if (bottom < minBottom) bottom = minBottom;

  return Offset(left, bottom);
}

/// The fullscreen profile chart's own in-chart, cursor-following tooltip
/// (the dive detail page's embedded chart uses fl_chart's own native bubble
/// instead -- see [DiveProfileChart.tooltipNativeBubble] -- and the
/// `tooltipBelow` path, used by the dive-list side panel, renders its own
/// overlay elsewhere and never reaches this widget). This widget:
/// - tracks the cursor horizontally, with its bottom edge at the cursor's Y
///   so it grows upward from it, clamped so it never rises above the
///   plot's top edge or trails below its bottom edge (see
///   [computeTooltipBoxPosition]),
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
  /// thicker, or the ascent-rate bars lit up) -- a [ProfileRightAxisMetric]
  /// or a [ChartOnlyMetric] -- so the matching row renders bold instead of
  /// every row looking equally important. Null renders every row the same.
  final Object? highlightedMetric;

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
            tooltipContentPadding * 2 + rows.length * _measuredRowHeight();
        final scale = computeTooltipScaleFactor(
          naturalHeight: naturalHeight,
          availableHeight: plotRect.height,
        );
        // Shrinks with the same factor as the text (issue #2228 follow-up):
        // on a small window, capping only the row count's height left the
        // box as wide as the whole plot while the text inside it kept
        // shrinking, so the box visually dominated the chart instead of
        // shrinking down with it.
        final boxWidth =
            (tooltipMaxContentWidth < plotRect.width
                ? tooltipMaxContentWidth
                : plotRect.width) *
            scale;
        final boxHeight = naturalHeight * scale;

        final position = computeTooltipBoxPosition(
          cursorLocal: cursorLocal,
          boxSize: Size(boxWidth, boxHeight),
          plotRect: plotRect,
        );
        // position.dy is the box's bottom edge, not its top: a `bottom`
        // Positioned offset places the actual (as-laid-out) box there
        // exactly, regardless of any mismatch between boxHeight's estimate
        // and the real rendered height -- a `top` offset combined with that
        // estimate previously left the bottom edge adrift from the cursor by
        // however much the estimate was off (issue #2228 follow-up).
        final bottomOffset = constraints.maxHeight - position.dy;

        final fontSize = tooltipBaseFontSize * scale;
        final rowStyle = TextStyle(
          fontFamily: 'RobotoMono',
          fontSize: fontSize,
          color: tooltipTextColor,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
        final boldRowStyle = rowStyle.copyWith(fontWeight: FontWeight.bold);

        return Stack(
          // Clip.none: the enclosing chart Stack already allows this, but
          // this widget's own LayoutBuilder constrains its Stack to the
          // chart's size too, so both need it -- a box whose real height
          // exceeds the plot's available space (even after the text has
          // shrunk to fit as best it can) must be free to spill above the
          // plot rather than have its top rows silently clipped away.
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: position.dx,
              bottom: bottomOffset,
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
                                      ? boldRowStyle
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
                                  style:
                                      row.metric != null &&
                                          row.metric == highlightedMetric
                                      ? boldRowStyle
                                      : rowStyle,
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
