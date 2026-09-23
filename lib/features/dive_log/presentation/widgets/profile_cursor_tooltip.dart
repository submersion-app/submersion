import 'dart:math' as math;

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

/// Margin the box's top edge keeps clear of local y = 0 (the container's
/// own top) once it can no longer track the cursor at all -- the same size
/// as [tooltipTopMargin] on the opposite edge, so the box reads as sitting
/// just inside the chart on either side it detaches from the cursor at.
const double tooltipCeilingMargin = 8;

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

/// Real height of one tooltip row at [tooltipBaseFontSize] and scale 1.0,
/// measured with a [TextPainter] using the exact same font as the rendered
/// rows, then cached (it never changes at runtime).
///
/// No safety margin on top any more: an earlier version padded this
/// estimate by 15%, back when the box's rendered size came directly from it
/// and an underestimate could let the box overlap whatever sits above the
/// chart. [TooltipCard] now sizes its real content with a [FittedBox]
/// instead, which measures the actual, unscaled content and scales it to
/// fit the box regardless of any mismatch here -- so the same margin only
/// left the box larger than its content needed, wasting space that could
/// otherwise go to a bigger font (issue #2228 follow-up).
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
  return rowContentHeight + _rowVerticalPadding;
}

/// Fixed dark background, not the theme's `colorScheme.inverseSurface`:
/// that token is designed to invert with the theme (it renders light in a
/// dark theme, meant for things like snackbars), which left this box
/// noticeably lighter than the old fl_chart bubble it replaced. This keeps
/// it dark regardless of the active theme, matching that original bubble.
const Color tooltipBackgroundColor = Color(0xFF1C1C1E);

/// Row text colour against [tooltipBackgroundColor].
const Color tooltipTextColor = Color(0xFFF2F2F2);

/// Fraction of the plot rect's short side (`min(width, height)`) the
/// tooltip's height may occupy at most, in either orientation, before its
/// text starts shrinking to fit (down to [tooltipMinFontSize]). The mouse
/// can never reach this hover-following box to scroll it, so a hard height
/// cap is the only way to bound how much of the chart it can occlude around
/// the touched sample -- capping only the width (the previous approach) left
/// the box as tall as however many metrics were active, which could occupy
/// nearly the whole chart in a short landscape window, or trigger a real
/// layout overflow in a narrow portrait one (issue #2228 follow-up).
///
/// 1.0, not a smaller fraction: the box should grow to use all the room the
/// short side allows before its text starts shrinking at all: shrinking
/// existing font size before the box has actually run out of room to grow
/// into left the box smaller than it needed to be for no benefit (issue
/// #2228 follow-up).
const double tooltipMaxHeightFraction = 1.0;

/// Floor for the row font size in logical pixels: text never renders
/// smaller than this, even if that means the box must grow past
/// [tooltipMaxHeightFraction] to fit every active metric. Legibility wins
/// over the height cap once shrinking further would make the tooltip
/// useless -- but only past this floor, so it takes a genuinely pathological
/// row count to spill past the cap at all.
const double tooltipMinFontSize = 8;

/// [tooltipMinFontSize] expressed as a fraction of [tooltipBaseFontSize],
/// for [computeTooltipScaleFactor]'s `minScale`.
const double tooltipMinScale = tooltipMinFontSize / tooltipBaseFontSize;

/// Computes the uniform shrink factor applied to the tooltip's rows so their
/// combined natural height fits within [availableHeight].
///
/// Returns 1.0 (no shrink) when the content already fits or either input is
/// non-positive. Otherwise returns `availableHeight / naturalHeight`, floored
/// at [minScale] so text never becomes illegibly small -- past that floor
/// the box grows beyond [availableHeight] rather than clip.
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

/// Computes the tooltip box's horizontal position and, while it can still
/// track the cursor, its bottom edge's Y -- given the cursor position it
/// anchors to and the plot rect it must stay inside.
///
/// Horizontally, the box is nominally placed [gap] logical pixels to the
/// right of [cursorLocal] (clear of the vertical indicator line fl_chart
/// draws through it), flipped to the cursor's left side first if it would
/// otherwise overflow [plotRect.right], then clamped so it never extends
/// past either horizontal edge.
///
/// Vertically, [bottom] is the box's bottom edge, at the cursor's Y -- the
/// caller positions the box with a `bottom` (not `top`) offset derived from
/// it, so the box grows upward from exactly the cursor's height regardless
/// of the box's own real (as-laid-out) height. It tracks the cursor this way
/// except at its two edges:
/// - low: it stops following once the cursor goes low enough that the
///   bottom edge would otherwise pass `plotRect.bottom - tooltipTopMargin`
///   (so it never trails into the safety-lane area below the plot) --
///   [floorHeadroom] extends that floor further down, past the plot's own
///   bottom edge and into whatever sits directly below it (the time axis
///   labels), symmetric to [ceilingHeadroom] above: 0 by default, so a
///   caller that never measured that space keeps the previous behaviour
///   (issue #2228 follow-up: the same pathological row count that may grow
///   into the legend above may use the room below it too, before its text
///   has to start shrinking at all);
/// - high: with enough active metrics the box can be taller than the room
///   between the cursor and local y = 0 -- the container's own top edge.
///   [ceilingHeadroom] extends that ceiling further up, past local y = 0
///   and into whatever sits directly above the plot (the legend, in
///   Vollbild even the window chrome) -- 0 by default, so the box still
///   detaches from the cursor exactly at the plot's own edge unless a
///   caller explicitly measured how much more room is above it (issue #2228
///   follow-up: requested so a pathological row count uses that room before
///   its text has to start shrinking at all). Past that point [bottom]
///   comes back null instead: a `bottom` offset derived from [boxSize]'s
///   merely *estimated* height would leave a gap should the box's real
///   height come out smaller than the estimate (which happens routinely --
///   the estimate deliberately overestimates a little to avoid clipping,
///   see `_measuredRowHeight`), so the caller pins the box's `top` instead
///   ([tooltipCeilingMargin] clear of the (possibly extended) ceiling) and
///   lets its real height determine where the bottom ends up (issue #2228
///   follow-up: earlier versions of this clamp kept deriving a `bottom`
///   from the height estimate regardless, which either triggered long
///   before the box was actually that tall -- read as the tooltip getting
///   stuck -- or, once that was fixed, left a gap between the box and the
///   container's top exactly as wide as the estimate's own overshoot).
({double left, double? bottom, double pinnedTop}) computeTooltipBoxPosition({
  required Offset cursorLocal,
  required Size boxSize,
  required Rect plotRect,
  double gap = tooltipCursorGap,
  double ceilingHeadroom = 0,
  double floorHeadroom = 0,
}) {
  final maxLeft = plotRect.right - boxSize.width;
  final minLeft = plotRect.left;

  var left = cursorLocal.dx + gap;
  if (left > maxLeft) {
    final flippedLeft = cursorLocal.dx - gap - boxSize.width;
    left = flippedLeft >= minLeft ? flippedLeft : maxLeft;
  }
  left = left.clamp(minLeft, minLeft > maxLeft ? minLeft : maxLeft);

  final maxBottom = plotRect.bottom - tooltipTopMargin + floorHeadroom;
  final bottom = cursorLocal.dy > maxBottom ? maxBottom : cursorLocal.dy;
  final pinnedTop = tooltipCeilingMargin - ceilingHeadroom;

  if (bottom - boxSize.height < pinnedTop) {
    return (left: left, bottom: null, pinnedTop: pinnedTop);
  }
  return (left: left, bottom: bottom, pinnedTop: pinnedTop);
}

/// Mirrored variant of [computeTooltipBoxPosition]: the box's TOP edge
/// tracks the cursor (so it grows downward from it) instead of the bottom
/// edge -- an experiment requested to compare against the default anchor,
/// with the same headroom extensions on both sides (issue #2228
/// follow-up). `top`/`pinnedBottom` here play the same roles
/// `bottom`/`pinnedTop` play above, just on the opposite edge.
({double left, double? top, double pinnedBottom})
computeTooltipBoxPositionTopAnchored({
  required Offset cursorLocal,
  required Size boxSize,
  required Rect plotRect,
  double gap = tooltipCursorGap,
  double ceilingHeadroom = 0,
  double floorHeadroom = 0,
}) {
  final maxLeft = plotRect.right - boxSize.width;
  final minLeft = plotRect.left;

  var left = cursorLocal.dx + gap;
  if (left > maxLeft) {
    final flippedLeft = cursorLocal.dx - gap - boxSize.width;
    left = flippedLeft >= minLeft ? flippedLeft : maxLeft;
  }
  left = left.clamp(minLeft, minLeft > maxLeft ? minLeft : maxLeft);

  final minTop = plotRect.top + tooltipCeilingMargin - ceilingHeadroom;
  final top = cursorLocal.dy < minTop ? minTop : cursorLocal.dy;
  final pinnedBottom = plotRect.bottom - tooltipTopMargin + floorHeadroom;

  if (top + boxSize.height > pinnedBottom) {
    return (left: left, top: null, pinnedBottom: pinnedBottom);
  }
  return (left: left, top: top, pinnedBottom: pinnedBottom);
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

  /// How far above the plot's own top edge (the legend row, in Vollbild
  /// even the window chrome) the box may grow into before its text has to
  /// start shrinking -- 0 by default, so callers that never measured this
  /// keep the previous behaviour of detaching from the cursor right at the
  /// plot's edge (issue #2228 follow-up).
  final double extraHeadroomAbove;

  /// Anchors the box's TOP edge to the cursor instead of its bottom edge,
  /// so it grows downward rather than upward (issue #2228 follow-up).
  /// True by default, confirmed live over the bottom-anchored alternative
  /// (still available via [computeTooltipBoxPosition], kept as the `else`
  /// branch in [build] for anyone who wants it back).
  final bool anchorTopToCursor;

  const ProfileCursorTooltip({
    super.key,
    required this.rows,
    required this.cursorLocal,
    required this.insets,
    this.highlightedMetric,
    this.extraHeadroomAbove = 0,
    this.anchorTopToCursor = true,
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

        // Plot height plus both headroom extensions, not plotRect.height
        // alone: the box may grow into the legend above and the time-axis
        // labels below before its text has to start shrinking at all, so
        // capping this at the bare plot height needlessly shrank the text
        // even while that room sat unused (issue #2228 follow-up). Still
        // capped by plotRect.width in portrait, where the narrow width (not
        // the height) is the actual constraint.
        final shortSideForCap = math.min(
          plotRect.width,
          plotRect.height + extraHeadroomAbove + insets.bottom,
        );
        // The box can grow upward past the plot's own top edge (Clip.none,
        // the ceiling clamp), so the true hard ceiling is the container's
        // full height plus however much further extraHeadroomAbove opens up
        // beyond that, not just plotRect.height.
        final hardMaxHeight = constraints.maxHeight + extraHeadroomAbove;

        final boxSize = computeTooltipCardSize(
          rowCount: rows.length,
          maxWidth: plotRect.width,
          shortSideForCap: shortSideForCap,
          hardMaxHeight: hardMaxHeight,
        );

        double left;
        double? topOffset;
        double? bottomOffset;
        if (anchorTopToCursor) {
          // Default: TOP edge tracks the cursor, box grows downward. See
          // [computeTooltipBoxPositionTopAnchored].
          final position = computeTooltipBoxPositionTopAnchored(
            cursorLocal: cursorLocal,
            boxSize: boxSize,
            plotRect: plotRect,
            ceilingHeadroom: extraHeadroomAbove,
            floorHeadroom: insets.bottom,
          );
          left = position.left;
          topOffset = position.top;
          bottomOffset = position.top == null
              ? constraints.maxHeight - position.pinnedBottom
              : null;
        } else {
          final position = computeTooltipBoxPosition(
            cursorLocal: cursorLocal,
            boxSize: boxSize,
            plotRect: plotRect,
            ceilingHeadroom: extraHeadroomAbove,
            // Symmetric to ceilingHeadroom: the time-axis labels below the
            // plot are already excluded from plotRect via insets.bottom, so
            // that same gutter is exactly how far the box's bottom may
            // reach past plotRect.bottom before it stops following the
            // cursor.
            floorHeadroom: insets.bottom,
          );
          left = position.left;
          // position.bottom is the box's bottom edge, not its top: a
          // `bottom` Positioned offset places the actual (as-laid-out) box
          // there exactly, regardless of any mismatch between boxHeight's
          // estimate and the real rendered height -- a `top` offset
          // combined with that estimate previously left the bottom edge
          // adrift from the cursor by however much the estimate was off
          // (issue #2228 follow-up). Null once the ceiling clamp engages:
          // the box is then pinned by `top` instead, for the same reason in
          // reverse (see [computeTooltipBoxPosition]).
          final bottom = position.bottom;
          topOffset = bottom == null ? position.pinnedTop : null;
          bottomOffset = bottom == null ? null : constraints.maxHeight - bottom;
        }

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
              left: left,
              top: topOffset,
              bottom: bottomOffset,
              child: TooltipCard(
                rows: rows,
                maxWidth: plotRect.width,
                shortSideForCap: shortSideForCap,
                hardMaxHeight: hardMaxHeight,
                highlightedMetric: highlightedMetric,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Computes the tooltip card's target size: [naturalWidth] (capped at
/// [tooltipMaxContentWidth]) by the natural height of [rowCount] rows,
/// shrunk by [computeTooltipScaleFactor] to fit within
/// [tooltipMaxHeightFraction] of [shortSideForCap] (down to
/// [tooltipMinFontSize] before the cap gives way -- see
/// [computeTooltipScaleFactor]) -- but never past [hardMaxHeight] even then:
/// that soft cap's floor protects legibility at the cost of letting a
/// pathological row count grow past it, and without an absolute ceiling
/// that had no limit at all, running the box past the actual visible chart
/// (or window) entirely -- effectively hiding whatever rows fell outside it
/// as surely as if they had been clipped (issue #2228 follow-up).
///
/// Shared by every tooltip presentation ([ProfileCursorTooltip]'s
/// cursor-following box and the fullscreen page's fixed-corner panel) so
/// switching between them never changes how much of the chart the tooltip
/// may occlude.
Size computeTooltipCardSize({
  required int rowCount,
  required double maxWidth,
  required double shortSideForCap,
  required double hardMaxHeight,
}) {
  if (rowCount == 0) return Size.zero;
  final naturalHeight =
      tooltipContentPadding * 2 + rowCount * _measuredRowHeight();
  final naturalWidth = math.min(tooltipMaxContentWidth, maxWidth);
  final maxTooltipHeight = shortSideForCap * tooltipMaxHeightFraction;
  // This ratio shrinks the box's own footprint (both width and height
  // together, so the background box visually shrinks along with its content
  // rather than leaving empty padding around smaller text -- see the
  // FittedBox in [TooltipCard] for why it is not also used to compute a
  // font size directly).
  final softCapScale = computeTooltipScaleFactor(
    naturalHeight: naturalHeight,
    availableHeight: maxTooltipHeight,
  );
  // No minScale floor here: this bound is absolute, so it must win even
  // over legibility once the soft cap's floor would otherwise carry the box
  // past it. tooltipCeilingMargin short of the full height, not the full
  // height itself: right at it, the box's bottom edge landed exactly on the
  // container's own edge, with no room left to show its rounded corner --
  // indistinguishable from being cut off there instead of ending on its own.
  final hardCapScale = computeTooltipScaleFactor(
    naturalHeight: naturalHeight,
    availableHeight: hardMaxHeight - tooltipCeilingMargin,
    minScale: 0,
  );
  final scale = math.min(softCapScale, hardCapScale);
  return Size(naturalWidth * scale, naturalHeight * scale);
}

/// The tooltip's rows, laid out inside a box sized by
/// [computeTooltipCardSize] -- independent of how the caller positions it.
/// [ProfileCursorTooltip] tracks the cursor with it; the fullscreen page's
/// fixed-corner panel docks it in a corner instead. Both share this card so
/// the size cap (and the legibility floor beneath it) applies the same way
/// regardless of which presentation is active.
class TooltipCard extends StatelessWidget {
  final List<TooltipRow> rows;

  /// The most the card's natural (unshrunk) width may be -- typically the
  /// plot's width, so the card never reaches past it.
  final double maxWidth;

  /// The dimension [tooltipMaxHeightFraction] is taken of -- see
  /// [computeTooltipCardSize].
  final double shortSideForCap;

  /// The absolute most the card's height may ever be -- see
  /// [computeTooltipCardSize].
  final double hardMaxHeight;

  final Object? highlightedMetric;

  const TooltipCard({
    super.key,
    required this.rows,
    required this.maxWidth,
    required this.shortSideForCap,
    required this.hardMaxHeight,
    this.highlightedMetric,
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();

    final naturalWidth = math.min(tooltipMaxContentWidth, maxWidth);
    final boxSize = computeTooltipCardSize(
      rowCount: rows.length,
      maxWidth: maxWidth,
      shortSideForCap: shortSideForCap,
      hardMaxHeight: hardMaxHeight,
    );

    const rowStyle = TextStyle(
      fontFamily: 'RobotoMono',
      fontSize: tooltipBaseFontSize,
      color: tooltipTextColor,
      fontFeatures: [FontFeature.tabularFigures()],
    );
    final boldRowStyle = rowStyle.copyWith(fontWeight: FontWeight.bold);

    return SizedBox(
      width: boxSize.width,
      height: boxSize.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tooltipBackgroundColor,
          borderRadius: BorderRadius.circular(6),
        ),
        // FittedBox, not relying on the manually computed font-size scale
        // alone: real text metrics do not shrink perfectly linearly with the
        // requested font size (rounding, hinting, minimum line-height), so a
        // row's real rendered height can drift from [_measuredRowHeight]'s
        // linear estimate -- most noticeably near [tooltipMinFontSize], the
        // smallest and therefore least linear end of the range (issue #2228
        // follow-up: the box was measured to land exactly at the cap, then
        // rendered taller than it). FittedBox measures the real, unscaled
        // content and scales it down to exactly fit [boxSize] regardless, so
        // the box can never exceed its own bounds no matter how far off the
        // estimate that sized those bounds was.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: naturalWidth,
            child: Padding(
              padding: const EdgeInsets.all(tooltipContentPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final row in rows)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _TooltipBullet(
                            color: row.bulletColor,
                            diamond: row.diamondBullet,
                            size: _rowBulletSize,
                            margin: 6,
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
                          const SizedBox(width: 12),
                          // Flexible too (not just the label): a long value
                          // (e.g. a tank row with its gas type) must never
                          // push the row past the box's fixed width, which
                          // the label's own Flexible alone cannot guarantee
                          // once the value's own natural width is the
                          // culprit. maxLines: 1 on both Text widgets keeps a
                          // row to one line -- ellipsis alone only elides
                          // overflow within the given number of lines, it
                          // does not by itself prevent wrapping to a second
                          // one, which would make the box taller than
                          // [_measuredRowHeight]'s estimate assumed.
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
      ),
    );
  }
}

/// A tooltip row's bullet: a circle for an ordinary metric row, or a diamond
/// (a square rotated 45 degrees -- [BoxDecoration] has no diamond shape of
/// its own) for a marker row, so it stands out among several stacked rows
/// the same way it did in the native fl_chart bubble this widget replaced.
class _TooltipBullet extends StatelessWidget {
  final Color color;
  final bool diamond;
  final double size;
  final double margin;

  const _TooltipBullet({
    required this.color,
    required this.diamond,
    required this.size,
    required this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: diamond ? BoxShape.rectangle : BoxShape.circle,
      ),
    );
    return Container(
      margin: EdgeInsets.only(right: margin),
      child: diamond ? Transform.rotate(angle: math.pi / 4, child: dot) : dot,
    );
  }
}
