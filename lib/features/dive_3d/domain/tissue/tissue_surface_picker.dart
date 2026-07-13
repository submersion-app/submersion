import 'dart:ui';

/// Where a compartment sits relative to ambient-equilibrium (the Subsurface
/// convention: 50% = at ambient). Thresholds are half-open.
enum TissueSaturationState { onGassing, equilibrium, offGassing, pastMValue }

TissueSaturationState tissueSaturationStateForPercent(double percent) {
  if (percent < 45) return TissueSaturationState.onGassing;
  if (percent < 55) return TissueSaturationState.equilibrium;
  if (percent <= 100) return TissueSaturationState.offGassing;
  return TissueSaturationState.pastMValue;
}

/// A picked surface vertex: its grid coordinates and where it landed on screen.
class TissuePick {
  final int col;
  final int comp;
  final Offset screenPos;
  const TissuePick({
    required this.col,
    required this.comp,
    required this.screenPos,
  });
}

/// Nearest projected surface vertex to [cursor] within [thresholdPx]. The
/// strictly-nearest vertex wins; only when two vertices project to the exact
/// same point (a front face in front of a back face) does the greater
/// [viewDepths] value break the tie, so the cursor picks the visible front
/// surface rather than a vertex hidden behind it. Returns null if nothing
/// qualifies. [projected]/[viewDepths] are indexed col*compartments + comp.
TissuePick? pickNearestTissueVertex({
  required Offset cursor,
  required List<Offset> projected,
  required List<double> viewDepths,
  required int columns,
  required int compartments,
  double thresholdPx = 20,
}) {
  if (compartments <= 0 || projected.isEmpty) return null;
  // Compare squared distances so hovers (which fire often on desktop) avoid a
  // sqrt per vertex; squaring preserves ordering and exact ties.
  final thresholdSq = thresholdPx * thresholdPx;
  var bestIndex = -1;
  var bestDistSq = thresholdSq;
  var bestDepth = double.negativeInfinity;
  for (var i = 0; i < projected.length; i++) {
    final dSq = (projected[i] - cursor).distanceSquared;
    if (dSq > thresholdSq) continue;
    final better =
        bestIndex < 0 ||
        dSq < bestDistSq ||
        (dSq == bestDistSq && viewDepths[i] > bestDepth);
    if (better) {
      bestIndex = i;
      bestDistSq = dSq;
      bestDepth = viewDepths[i];
    }
  }
  if (bestIndex < 0) return null;
  return TissuePick(
    col: bestIndex ~/ compartments,
    comp: bestIndex % compartments,
    screenPos: projected[bestIndex],
  );
}
