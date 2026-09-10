import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/presentation/widgets/profile_highlight_range.dart';
import 'package:submersion/features/equipment/domain/entities/dive_sensor_summary.dart';

/// The dive's O2 cell divergence runs as chart bands, sorted by start.
/// Drawn only while the O2 cell overlay is on (the chart gates them), in
/// the error colour so a diverging cell reads as a warning, not a
/// selection.
List<ProfileHighlightRange> cellDivergenceHighlightRanges(
  DiveSensorSummary? summary,
  ColorScheme scheme,
) {
  if (summary == null) return const [];
  final ranges = [
    for (final cell in summary.cellMetrics)
      for (final range in cell.divergenceRanges)
        ProfileHighlightRange(
          startTimestamp: range.startSeconds,
          endTimestamp: range.endSeconds,
          color: scheme.error,
        ),
  ]..sort((a, b) => a.startTimestamp.compareTo(b.startTimestamp));
  return ranges;
}
