import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'package:submersion/features/dive_log/presentation/widgets/profile_decimator.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_bands.dart';

/// The most points the strip draws of one curve, the full chart's own curve
/// budget.
const int kPinnedStripPointBudget = 2000;

/// One sample of a curve the pinned strip draws: its [index] into the chart
/// profile, which gives its time, and its [value] (seconds for NDL, metres
/// for the ceiling and deco stops).
@immutable
class StripSeriesPoint {
  const StripSeriesPoint(this.index, this.value);

  final int index;
  final double value;
}

final Expando<List<List<StripSeriesPoint>>> _ndlRuns = Expando('pinnedNdl');
final Expando<List<List<StripSeriesPoint>>> _smoothRuns = Expando(
  'pinnedSmooth',
);
final Expando<List<List<StripSeriesPoint>>> _steppedRuns = Expando(
  'pinnedStepped',
);

/// The stretches of [ndlCurve] (seconds) with no-deco time left, as the
/// strip draws its NDL line (issue #4509).
///
/// Once NDL is spent (zero, or negative in deco) the line ends, as on the
/// full chart, so a run never bridges a deco phase. Readings past
/// [ProfileMetricBands.ndl]'s hour are held at the hour. Worked out once per
/// curve: the strip repaints on every scroll frame while it shows.
List<List<StripSeriesPoint>> pinnedNdlRuns(List<int> ndlCurve) =>
    _ndlRuns[ndlCurve] ??= _runs([
      for (final s in ndlCurve)
        math.min(s.toDouble(), ProfileMetricBands.ndl.fixedMax),
    ], stepped: false);

/// The stretches of [curve] (metres) with an obligation, as the strip draws
/// its ceiling band ([stepped] false) or its deco stop band ([stepped] true).
///
/// Stop depths change in steps, and thinning them like a smooth curve could
/// drop the sample a step happens at and slant its edge, so a stepped run
/// keeps only its ends and the samples either side of each change, as the
/// full chart's deco stop band does.
List<List<StripSeriesPoint>> pinnedDepthRuns(
  List<double> curve, {
  bool stepped = false,
}) {
  final cache = stepped ? _steppedRuns : _smoothRuns;
  return cache[curve] ??= _runs(curve, stepped: stepped);
}

List<List<StripSeriesPoint>> _runs(
  List<double> values, {
  required bool stepped,
}) {
  final runs = <List<StripSeriesPoint>>[];
  var start = -1;
  for (var i = 0; i <= values.length; i++) {
    final inRun = i < values.length && values[i] > 0;
    if (inRun && start < 0) start = i;
    if (!inRun && start >= 0) {
      runs.add(stepped ? _steps(values, start, i) : _thinned(values, start, i));
      start = -1;
    }
  }
  return List.unmodifiable(runs);
}

List<StripSeriesPoint> _steps(List<double> values, int start, int end) {
  final kept = <StripSeriesPoint>[];
  for (var i = start; i < end; i++) {
    final first = i == start;
    final last = i == end - 1;
    final changesNext = !last && values[i + 1] != values[i];
    final changedHere = !first && values[i - 1] != values[i];
    if (first || last || changesNext || changedHere) {
      kept.add(StripSeriesPoint(i, values[i]));
    }
  }
  return List.unmodifiable(kept);
}

List<StripSeriesPoint> _thinned(List<double> values, int start, int end) {
  final run = values.sublist(start, end);
  return List.unmodifiable([
    for (final i in decimateSeriesIndices(
      run,
      targetPoints: kPinnedStripPointBudget,
    ))
      StripSeriesPoint(start + i, run[i]),
  ]);
}

/// Gap between the max-depth dot and its label.
const double _labelGap = 6;

/// How far the label's bottom sits below the dot's centre.
const double _labelDrop = 2;

/// Clearance kept between the label and any point it must not cover.
const double _avoidMargin = 2;

/// Where the max-depth label of [label] size goes beside the dot at [dot],
/// within a strip of [area] size: right of the dot, or left of it when the
/// right side would leave the strip or cross one of [avoid], the NDL line
/// as polylines (one per run, so a break between runs is not a segment).
/// Always inside the strip.
Offset maxDepthLabelOffset({
  required Offset dot,
  required Size label,
  required Size area,
  List<List<Offset>> avoid = const [],
}) {
  final top = dot.dy + _labelDrop - label.height;
  final right = Offset(dot.dx + _labelGap, top);
  final left = Offset(dot.dx - _labelGap - label.width, top);

  bool fits(Offset at) => at.dx >= 0 && at.dx + label.width <= area.width;
  bool clear(Offset at) {
    final rect = (at & label).inflate(_avoidMargin);
    for (final line in avoid) {
      if (line.length == 1 && rect.contains(line.single)) return false;
      for (var i = 1; i < line.length; i++) {
        if (_crosses(line[i - 1], line[i], rect)) return false;
      }
    }
    return true;
  }

  final Offset chosen;
  if (fits(right) && clear(right)) {
    chosen = right;
  } else if (fits(left) && clear(left)) {
    chosen = left;
  } else {
    chosen = fits(right) ? right : left;
  }
  return Offset(
    chosen.dx.clamp(0.0, math.max(0.0, area.width - label.width)),
    chosen.dy.clamp(0.0, math.max(0.0, area.height - label.height)),
  );
}

/// Whether the segment from [a] to [b] passes through [rect], either end
/// inside it included (Liang-Barsky clipping): a segment can cross the label
/// with both its ends outside.
bool _crosses(Offset a, Offset b, Rect rect) {
  var enter = 0.0;
  var leave = 1.0;
  final dx = b.dx - a.dx;
  final dy = b.dy - a.dy;
  for (final (p, q) in [
    (-dx, a.dx - rect.left),
    (dx, rect.right - a.dx),
    (-dy, a.dy - rect.top),
    (dy, rect.bottom - a.dy),
  ]) {
    if (p == 0) {
      if (q < 0) return false;
      continue;
    }
    final t = q / p;
    if (p < 0) {
      if (t > leave) return false;
      if (t > enter) enter = t;
    } else {
      if (t < enter) return false;
      if (t < leave) leave = t;
    }
  }
  return true;
}
