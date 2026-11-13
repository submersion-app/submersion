import 'dart:math' as math;

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

/// The stretches of [ndlCurve] (seconds) the strip draws its NDL line along
/// (issue #4509): where the limit dips below the top of its scale,
/// [ProfileMetricBands.ndl]'s hour.
///
/// Held at the top the line was a bar across most of a recreational dive, so
/// it shows only where it dips: each run reaches out to the at-the-top
/// sample on either side, so the line drops in from the top edge and climbs
/// back out to it. Once NDL is spent (zero, or negative in deco) the line
/// ends, as on the full chart, so a run never bridges a deco phase. Worked
/// out once per curve: the strip repaints on every scroll frame while it
/// shows.
List<List<StripSeriesPoint>> pinnedNdlRuns(List<int> ndlCurve) =>
    _ndlRuns[ndlCurve] ??= _ndlRunsOf(ndlCurve);

List<List<StripSeriesPoint>> _ndlRunsOf(List<int> curve) {
  final top = ProfileMetricBands.ndl.fixedMax;
  final held = [for (final s in curve) math.min(s.toDouble(), top)];
  bool atTop(int i) => i >= 0 && i < curve.length && curve[i] >= top;
  final runs = <List<StripSeriesPoint>>[];
  var start = -1;
  for (var i = 0; i <= curve.length; i++) {
    final below = i < curve.length && curve[i] > 0 && curve[i] < top;
    if (below && start < 0) start = i;
    if (!below && start >= 0) {
      final from = atTop(start - 1) ? start - 1 : start;
      final to = atTop(i) ? i + 1 : i;
      runs.add(_thinned(held, from, to));
      start = -1;
    }
  }
  return List.unmodifiable(runs);
}

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
