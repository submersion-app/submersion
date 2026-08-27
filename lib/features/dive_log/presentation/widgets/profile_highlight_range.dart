import 'dart:math' as math;
import 'dart:ui';

/// A time range on the dive profile to emphasize, e.g. the span of a selected
/// safety finding. Timestamps are seconds from dive start (the chart x-axis
/// unit). [startTimestamp] == [endTimestamp] marks a single instant, which the
/// chart renders as a cursor line instead of a band.
class ProfileHighlightRange {
  final int startTimestamp;
  final int endTimestamp;

  /// Fully opaque accent color; the chart applies its own band/edge alphas.
  final Color color;

  const ProfileHighlightRange({
    required this.startTimestamp,
    required this.endTimestamp,
    required this.color,
  });
}

/// Clamps [range] to the chart's visible x-window.
///
/// Returns the drawable span, or null when nothing of the range is visible.
/// fl_chart asserts that annotations and extra lines lie within [minX, maxX],
/// so callers must only draw what this returns. An instant range survives
/// while its timestamp is inside the window; a true range collapses to null
/// when the visible overlap has zero width (window just touching an edge).
({double x1, double x2})? visibleHighlightSpan(
  ProfileHighlightRange range, {
  required double visibleMinX,
  required double visibleMaxX,
}) {
  final start = range.startTimestamp.toDouble();
  final end = range.endTimestamp.toDouble();

  if (start == end) {
    if (start < visibleMinX || start > visibleMaxX) return null;
    return (x1: start, x2: start);
  }

  final x1 = math.max(start, visibleMinX);
  final x2 = math.min(end, visibleMaxX);
  if (x1 >= x2) return null;
  return (x1: x1, x2: x2);
}

/// The drawable band for [range], inflated to at least [minWidthX] (x-axis
/// units) so short and instant findings stay visible. Centered on the
/// clamped span's midpoint, shifted (not shrunk) to stay inside the window;
/// a window narrower than [minWidthX] yields the whole window. Returns null
/// when nothing of the range is visible.
({double x1, double x2})? highlightBandSpan(
  ProfileHighlightRange range, {
  required double visibleMinX,
  required double visibleMaxX,
  required double minWidthX,
}) {
  final span = visibleHighlightSpan(
    range,
    visibleMinX: visibleMinX,
    visibleMaxX: visibleMaxX,
  );
  if (span == null) return null;
  if (span.x2 - span.x1 >= minWidthX) return span;
  if (visibleMaxX - visibleMinX <= minWidthX) {
    return (x1: visibleMinX, x2: visibleMaxX);
  }
  final mid = (span.x1 + span.x2) / 2;
  var x1 = mid - minWidthX / 2;
  var x2 = mid + minWidthX / 2;
  if (x1 < visibleMinX) {
    x2 += visibleMinX - x1;
    x1 = visibleMinX;
  } else if (x2 > visibleMaxX) {
    x1 -= x2 - visibleMaxX;
    x2 = visibleMaxX;
  }
  return (x1: x1, x2: x2);
}
