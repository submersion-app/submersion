import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// The profile chart's bars cut down to one visible X window, plus where each
/// cut bar starts inside the bar it came from.
///
/// fl_chart builds a path over every spot it is given and only clips at
/// raster time. Zoomed in, that path runs many plot-widths past the visible
/// window, and on macOS the Impeller (MetalSDF) renderer corrupts the frame
/// once it gets big enough: blanked series, stray triangles, smeared glyphs.
/// Handing fl_chart only the window keeps every path about one plot wide at
/// any zoom.
///
/// fl_chart reports touches as `(barIndex, spotIndex)` against the bars it
/// was given, so any code that reads a touched spot's index back into the
/// source data must go through [sourceSpotIndex].
@immutable
class WindowedBars {
  const WindowedBars(this.bars, this.offsets);

  /// The bars as given, uncut: offsets are all zero.
  WindowedBars.unwindowed(this.bars)
    : offsets = List<int>.filled(bars.length, 0);

  final List<LineChartBarData> bars;

  /// Index of each cut bar's first spot within its source bar's spot list.
  final List<int> offsets;

  /// Maps a spot index fl_chart reported against [bars] back to the index of
  /// the same spot in the source bar.
  int sourceSpotIndex(int barIndex, int spotIndex) =>
      barIndex >= 0 && barIndex < offsets.length
      ? offsets[barIndex] + spotIndex
      : spotIndex;
}

/// Cuts each bar down to the spots inside [minX, maxX], keeping [margin] real
/// (non-gap) samples beyond each edge so lines and curves still run off the
/// plot exactly as before. Two neighbours keep a curved segment that crosses
/// an edge identical: its control points come from the samples either side.
///
/// A bar whose x values ever decrease (a shape that doubles back, such as a
/// closed band) is passed through whole, since cutting a prefix and suffix
/// would change its outline. A bar that already fits is returned as the same
/// instance.
///
/// [chartMinY] is the chart's current minY, the bottom edge fl_chart sizes a
/// below-area gradient to (see [_remappedFill]).
WindowedBars windowBars(
  List<LineChartBarData> bars, {
  required double minX,
  required double maxX,
  required double chartMinY,
  int margin = 2,
}) {
  final out = <LineChartBarData>[];
  final offsets = <int>[];
  for (final bar in bars) {
    final clip = _canClipAtEdges(bar);
    final range = _windowRange(bar.spots, minX, maxX, clip ? 1 : margin);
    final kept = range == null
        ? null
        : bar.spots.sublist(range.start, range.end + 1);
    final spots = kept != null && clip
        ? _clippedToEdges(kept, minX, maxX)
        : kept;
    if (range == null ||
        (range.start == 0 &&
            range.end == bar.spots.length - 1 &&
            identical(spots, kept))) {
      out.add(bar);
      offsets.add(0);
    } else {
      final cut = bar.copyWith(spots: spots);
      out.add(_remappedFill(bar, cut, chartMinY));
      offsets.add(range.start);
    }
  }
  return WindowedBars(out, offsets);
}

/// Whether [bar]'s edge samples can be moved onto the window edges without
/// changing what is drawn: a straight line joins its samples (no curve, whose
/// shape depends on the samples either side, and no steps), and no dots mark
/// where the samples are.
bool _canClipAtEdges(LineChartBarData bar) =>
    !bar.isCurved && !bar.isStepLineChart && !bar.dotData.show;

/// [spots] with a first sample left of [minX], and a last one right of
/// [maxX], moved along their segment onto that edge. A span from a
/// full-dive series (the O2 cell rug is two points, start to end) would
/// otherwise stay the width of the whole dive. A sample whose neighbour is a
/// gap has no segment into the window and stays put. Only the end samples
/// move, so spot indices into the cut are unchanged.
List<FlSpot> _clippedToEdges(List<FlSpot> spots, double minX, double maxX) {
  if (spots.length < 2) return spots;
  FlSpot onEdge(FlSpot from, FlSpot to, double x) =>
      FlSpot(x, from.y + (to.y - from.y) * (x - from.x) / (to.x - from.x));

  final first = spots.first;
  final second = spots[1];
  final last = spots.last;
  final beforeLast = spots[spots.length - 2];
  final clipFirst =
      !first.isNull() && !second.isNull() && first.x < minX && second.x > minX;
  final clipLast =
      !last.isNull() &&
      !beforeLast.isNull() &&
      last.x > maxX &&
      beforeLast.x < maxX;
  if (!clipFirst && !clipLast) return spots;
  return [
    for (var i = 0; i < spots.length; i++)
      if (i == 0 && clipFirst)
        onEdge(first, second, minX)
      else if (i == spots.length - 1 && clipLast)
        onEdge(beforeLast, last, maxX)
      else
        spots[i],
  ];
}

/// [cut] with its below-area gradient moved back to where it sat on [source].
///
/// fl_chart stretches a below-area gradient over the bar's own bounds: its
/// leftmost to rightmost spot, and its topmost spot down to the chart's minY.
/// Cutting the bar shrinks those bounds, which would slide the fill's shading
/// around as the window moves. The mapping from data to pixels is linear, so
/// re-expressing each alignment against the cut bounds, all in data units,
/// puts every colour back on the same depth.
LineChartBarData _remappedFill(
  LineChartBarData source,
  LineChartBarData cut,
  double chartMinY,
) {
  final fill = cut.belowBarData;
  final gradient = fill.gradient;
  if (!fill.show || gradient is! LinearGradient) return cut;
  final begin = gradient.begin;
  final end = gradient.end;
  if (begin is! Alignment || end is! Alignment) return cut;

  final srcLeft = source.mostLeftSpot.x;
  final srcRight = source.mostRightSpot.x;
  final srcTop = source.mostTopSpot.y;
  final cutLeft = cut.mostLeftSpot.x;
  final cutRight = cut.mostRightSpot.x;
  final cutTop = cut.mostTopSpot.y;
  if (!(cutRight > cutLeft) || !(cutTop > chartMinY)) return cut;

  // An alignment runs -1..1 across a rect edge to edge; y runs top (larger
  // data y) to bottom (chartMinY), matching the chart's inverted pixel axis.
  double remap(
    double a,
    double srcFrom,
    double srcTo,
    double from,
    double to,
  ) => 2 * (srcFrom + (a + 1) / 2 * (srcTo - srcFrom) - from) / (to - from) - 1;
  Alignment moved(Alignment a) => Alignment(
    remap(a.x, srcLeft, srcRight, cutLeft, cutRight),
    remap(a.y, srcTop, chartMinY, cutTop, chartMinY),
  );

  return cut.copyWith(
    belowBarData: BarAreaData(
      show: fill.show,
      color: fill.color,
      gradient: LinearGradient(
        begin: moved(begin),
        end: moved(end),
        colors: gradient.colors,
        stops: gradient.stops,
        tileMode: gradient.tileMode,
        transform: gradient.transform,
      ),
      spotsLine: fill.spotsLine,
      cutOffY: fill.cutOffY,
      applyCutOffY: fill.applyCutOffY,
    ),
  );
}

/// Inclusive spot range to keep, or null to keep the bar whole.
({int start, int end})? _windowRange(
  List<FlSpot> spots,
  double minX,
  double maxX,
  int margin,
) {
  if (spots.isEmpty || !_isOrderedByX(spots)) return null;

  var first = 0; // first real spot at or after minX
  while (first < spots.length &&
      (spots[first].isNull() || spots[first].x < minX)) {
    first++;
  }
  var last = spots.length - 1; // last real spot at or before maxX
  while (last >= 0 && (spots[last].isNull() || spots[last].x > maxX)) {
    last--;
  }

  var start = first;
  for (var kept = 0, i = first - 1; i >= 0 && kept < margin; i--) {
    if (spots[i].isNull()) continue;
    start = i;
    kept++;
  }
  var end = last;
  for (var kept = 0, i = last + 1; i < spots.length && kept < margin; i++) {
    if (spots[i].isNull()) continue;
    end = i;
    kept++;
  }

  if (start >= spots.length) start = spots.length - 1;
  if (end < 0) end = 0;
  if (end < start) return null;
  return (start: start, end: end);
}

/// Whether the real spots' x values never decrease, memoized per spot list:
/// the chart's bars are memoized too, so this runs once per bar, not once
/// per pan frame.
bool _isOrderedByX(List<FlSpot> spots) => _orderedByX[spots] ??= () {
  var prev = double.negativeInfinity;
  for (final s in spots) {
    if (s.isNull()) continue;
    if (s.x < prev) return false;
    prev = s.x;
  }
  return true;
}();

final Expando<bool> _orderedByX = Expando<bool>('orderedByX');

/// The window starting at [minX] and [width] wide, widened to whole
/// eighth-window steps.
///
/// Snapping keeps the cut bars (and so fl_chart's touched spot indices)
/// unchanged while a pan stays inside one step, instead of shifting on every
/// frame. The result is at most a quarter of a window wider than asked.
/// [width] is taken rather than derived from a max so one zoom level always
/// yields the exact same step.
({double minX, double maxX}) snappedBarWindow({
  required double minX,
  required double width,
}) {
  final step = width / 8;
  if (!(step > 0)) return (minX: minX, maxX: minX + width);
  return (
    minX: (minX / step).floorToDouble() * step,
    maxX: ((minX + width) / step).ceilToDouble() * step,
  );
}
