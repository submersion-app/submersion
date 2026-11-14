import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart'
    show TooltipRow;
import 'package:submersion/features/dive_log/presentation/widgets/profile_cursor_tooltip.dart';

/// Gap between the cursor and the near edge of the tooltip.
const double kPinnedTooltipCursorGap = 10;

/// Gap the tooltip keeps from the strip's left and right edges.
const double kPinnedTooltipEdgeMargin = 8;

/// Gap between the bottom of the strip and the top of the tooltip.
const double kPinnedTooltipDrop = 4;

const double _fontSize = 11;
const double _bulletSize = 6;
const double _bulletGap = 5;
const double _labelGap = 6;
const double _radius = 6;
const EdgeInsets _padding = EdgeInsets.symmetric(horizontal: 7, vertical: 5);

/// Where the tooltip's left edge goes for a cursor at [cursorX] across a
/// strip [stripWidth] wide (issue #4509): right of the cursor, or left of it
/// when the right side would come within [kPinnedTooltipEdgeMargin] of the
/// strip's right edge, and never closer than that margin to either edge.
double pinnedTooltipLeft({
  required double cursorX,
  required double tooltipWidth,
  required double stripWidth,
}) {
  final right = cursorX + kPinnedTooltipCursorGap;
  final preferred =
      right + tooltipWidth <= stripWidth - kPinnedTooltipEdgeMargin
      ? right
      : cursorX - kPinnedTooltipCursorGap - tooltipWidth;
  return preferred.clamp(
    kPinnedTooltipEdgeMargin,
    math.max(
      kPinnedTooltipEdgeMargin,
      stripWidth - kPinnedTooltipEdgeMargin - tooltipWidth,
    ),
  );
}

/// The pinned strip's compact readout (issue #4509): the full profile
/// chart's dark tooltip, at about half its size, since it floats over the
/// page's content rather than over a chart.
class PinnedStripTooltip extends StatelessWidget {
  const PinnedStripTooltip({super.key, required this.rows});

  final List<TooltipRow> rows;

  @override
  Widget build(BuildContext context) {
    const base = TextStyle(
      fontSize: _fontSize,
      height: 1.25,
      color: tooltipTextColor,
      fontFeatures: [FontFeature.tabularFigures()],
    );
    final labelStyle = base.copyWith(
      color: tooltipTextColor.withValues(alpha: 0.7),
    );
    final valueStyle = base.copyWith(fontWeight: FontWeight.w600);
    return DecoratedBox(
      key: const ValueKey('pinnedTooltipBox'),
      decoration: BoxDecoration(
        color: tooltipBackgroundColor,
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: Padding(
        padding: _padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < rows.length; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DecoratedBox(
                    key: ValueKey('pinnedTooltipBullet$i'),
                    decoration: BoxDecoration(
                      color: rows[i].bulletColor,
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox.square(dimension: _bulletSize),
                  ),
                  const SizedBox(width: _bulletGap),
                  Text(rows[i].label, style: labelStyle),
                  const SizedBox(width: _labelGap),
                  Text(rows[i].value, style: valueStyle),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
