import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart'
    show TooltipRow;

/// Gap, in logical pixels, between the touch/hover cursor (the vertical
/// indicator line fl_chart draws at the touched sample) and the tooltip
/// box's nearest corner. 40, not the original 8, per direct feedback once
/// the tooltip was actually tried live: 8px read as touching the cursor
/// line rather than sitting clearly beside it.
const double tooltipCursorGap = 40;

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
/// anchors to and the plot rect it must stay inside.
///
/// The box's bottom-left corner is nominally placed [gap] logical pixels up
/// and to the right of [cursorLocal] (so the box sits above-and-right of the
/// cursor by default, clear of the vertical indicator line fl_chart draws
/// through it). That placement is then clamped so the box:
/// - never extends above [plotRect.top] or below [plotRect.bottom]
///   (pinned to whichever edge it would otherwise cross), and
/// - never extends past [plotRect.right] -- flipped to the cursor's left
///   side first, then clamped, so it only touches the right edge when even
///   the flipped placement would not fit.
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

  final maxTop = plotRect.bottom - boxSize.height;
  final minTop = plotRect.top;
  var top = cursorLocal.dy - gap - boxSize.height;
  top = top.clamp(minTop, minTop > maxTop ? minTop : maxTop);

  return Offset(left, top);
}

/// The dive-detail / fullscreen profile chart's own in-chart, cursor-
/// following tooltip.
///
/// Replaces fl_chart's built-in bubble for [DiveProfileChart]'s
/// `!tooltipBelow` path (the dive detail page and fullscreen profile page --
/// the `tooltipBelow` path, used by the dive-list side panel, keeps rendering
/// its own overlay elsewhere and never reaches this widget). fl_chart's
/// bubble positioned and sized itself, and with many metrics enabled it
/// could overflow the chart's top/bottom edge and clip rows rather than fit
/// (`fitInsideVertically: false` was set because fl_chart's own vertical
/// fitting pushed the box somewhere worse). This widget instead:
/// - anchors its bottom-left corner near the cursor (see
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

  const ProfileCursorTooltip({
    super.key,
    required this.rows,
    required this.cursorLocal,
    required this.insets,
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;

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
          color: colorScheme.onInverseSurface,
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
                  color: colorScheme.inverseSurface,
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
                                  style: rowStyle,
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
