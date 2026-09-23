/// A touched spot fl_chart reported, reduced to the two things nearest-line
/// hit-testing needs: which bar it belongs to, and its Y position in the
/// chart's data space (the same coordinate space as [LineChartBarData]'s
/// spots -- see `TouchLineBarSpot.y`).
typedef HoveredBarCandidate = ({int barIndex, double dataY});

/// The candidate in [spots] whose pixel-Y distance to [cursorPixelY] is
/// smallest, or null when [spots] is empty.
///
/// [toPixelY] converts a candidate's [HoveredBarCandidate.dataY] into a
/// pixel-Y in the same coordinate space as [cursorPixelY] (typically the
/// chart widget's local coordinate space, with the plot rect's own insets
/// folded in -- see `_DiveProfileChartState`'s touchCallback for the actual
/// depth-axis conversion this is used with). Only the Y axis is considered:
/// fl_chart's own `touchSpotThreshold` has already filtered candidates in
/// the X direction, so every entry in [spots] is already "close enough"
/// horizontally, and the deciding factor is which line the cursor sits
/// closest to vertically.
int? nearestHoveredBarIndex({
  required List<HoveredBarCandidate> spots,
  required double cursorPixelY,
  required double Function(double dataY) toPixelY,
}) {
  int? bestBarIndex;
  double? bestDistance;
  for (final spot in spots) {
    final distance = (toPixelY(spot.dataY) - cursorPixelY).abs();
    if (bestDistance == null || distance < bestDistance) {
      bestDistance = distance;
      bestBarIndex = spot.barIndex;
    }
  }
  return bestBarIndex;
}
