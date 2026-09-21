import 'package:flutter/material.dart';

import 'package:fl_chart/fl_chart.dart';

/// Build vertical line for playback cursor
List<VerticalLine> buildPlaybackCursor(
  ColorScheme colorScheme,
  int? playbackTimestamp,
) {
  final timestamp = playbackTimestamp;
  if (timestamp == null) {
    return [];
  }

  // Convert timestamp to x position (seconds)
  final xPosition = timestamp.toDouble();

  return [
    VerticalLine(
      x: xPosition,
      color: colorScheme.primary,
      strokeWidth: 2,
      dashArray: [4, 4],
      label: VerticalLineLabel(
        show: true,
        alignment: Alignment.topCenter,
        padding: const EdgeInsets.only(bottom: 4),
        style: TextStyle(
          color: colorScheme.onPrimaryContainer,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.9),
        ),
        labelResolver: (line) {
          final minutes = timestamp ~/ 60;
          final seconds = timestamp % 60;
          return ' ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')} ';
        },
      ),
    ),
  ];
}

/// Build vertical line for external highlight (e.g. heat map hover)
List<VerticalLine> buildHighlightCursor(
  ColorScheme colorScheme,
  int? highlightedTimestamp,
) {
  final timestamp = highlightedTimestamp;
  if (timestamp == null) {
    return [];
  }

  return [
    VerticalLine(
      x: timestamp.toDouble(),
      color: colorScheme.onSurface.withValues(alpha: 0.5),
      strokeWidth: 1,
      dashArray: [3, 3],
    ),
  ];
}

/// Edge lines at the highlight band's (possibly inflated) edges.
List<VerticalLine> buildHighlightRangeLines(
  ({double x1, double x2})? span,
  Color? highlightRangeColor,
) {
  if (highlightRangeColor == null || span == null) return [];
  return [
    for (final x in [span.x1, span.x2])
      VerticalLine(
        x: x,
        color: highlightRangeColor.withValues(alpha: 0.7),
        strokeWidth: 1,
      ),
  ];
}
