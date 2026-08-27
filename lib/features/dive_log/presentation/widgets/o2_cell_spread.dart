/// Cell agreement view for CCR O2 cells (issue #810).
///
/// Cells swing tens of millivolts across a dive as ppO2 changes, while
/// disagreeing with each other by only one or two. Any view drawn on an
/// absolute scale therefore shows the swing and hides the disagreement, which
/// is the only part worth looking at.
///
/// The answer here is the spread -- the gap between the highest and lowest
/// cell -- smoothed and then run-length encoded into discrete tight/drifting/
/// wide agreement levels, drawn as a status rug rather than a continuously
/// scaled ribbon: a discrete verdict needs no axis of its own to read at a
/// glance, and the rug can sit on the depth chart's own coordinate space
/// instead of claiming a second one.
library;

import 'dart:math' as math;

/// Time span the divergence is smoothed over, in seconds.
///
/// A failing cell drifts over minutes; sample-to-sample change on whole-
/// millivolt data is almost entirely quantization.
const int kO2CellSpreadSmoothingSeconds = 120;

/// Upper bound on the smoothing window, so a very densely sampled profile does
/// not turn the rolling median into a whole-dive average.
const int _maxWindowSamples = 121;

/// Spread between the highest and lowest reporting cell at each sample.
///
/// One number per sample rather than one per cell, and free of any baseline at
/// all: it answers "how far apart are my cells right now?" without needing a
/// reference that could itself be wrong. Null where fewer than two cells
/// reported, since a single cell cannot disagree with anything.
List<double?> computeO2CellRange(List<List<int?>> mvCurves) {
  if (mvCurves.isEmpty) return const [];

  var sampleCount = 0;
  for (final curve in mvCurves) {
    sampleCount = math.max(sampleCount, curve.length);
  }

  return [for (var i = 0; i < sampleCount; i++) _rangeAt(mvCurves, i)];
}

double? _rangeAt(List<List<int?>> mvCurves, int i) {
  int? lo, hi;
  var seen = 0;
  for (final curve in mvCurves) {
    if (i >= curve.length) continue;
    final value = curve[i];
    if (value == null) continue;
    seen++;
    if (lo == null || value < lo) lo = value;
    if (hi == null || value > hi) hi = value;
  }
  if (seen < 2) return null;
  return (hi! - lo!).toDouble();
}

/// Centered rolling **median** of each cell's deviation.
///
/// Median, not mean: a median of whole-millivolt values snaps to one of them,
/// so a cell rounding back and forth between -1 and 0 reads as a steady -1
/// rather than a square wave, while a lone spike is rejected outright. A
/// sustained offset passes through untouched, which is the signal worth seeing.
///
/// Gaps are preserved: a sample where the cell reported nothing stays null
/// rather than being filled in from its neighbours.
List<List<double?>> smoothO2CellSpread(
  List<List<double?>> spreadCurves, {
  required int windowSamples,
}) {
  if (windowSamples <= 1) return spreadCurves;
  final half = windowSamples ~/ 2;

  return [
    for (final curve in spreadCurves)
      [
        for (var i = 0; i < curve.length; i++)
          if (curve[i] == null)
            null
          else
            _medianOf(
              curve,
              math.max(0, i - half),
              math.min(curve.length, i + half + 1),
            ),
      ],
  ];
}

/// Median of the non-null values in `curve[start..end)`, or null when the
/// window holds none.
double? _medianOf(List<double?> curve, int start, int end) {
  final window = <double>[];
  for (var i = start; i < end; i++) {
    final value = curve[i];
    if (value != null) window.add(value);
  }
  if (window.isEmpty) return null;
  window.sort();
  final mid = window.length ~/ 2;
  return window.length.isOdd
      ? window[mid]
      : (window[mid - 1] + window[mid]) / 2.0;
}

/// Smoothing window in samples for a profile, covering roughly
/// [kO2CellSpreadSmoothingSeconds] of dive time.
///
/// Always odd so the window can be centered, and 1 (no smoothing) when the
/// profile is too short or its timestamps too irregular to measure an interval.
int o2CellSpreadWindowSamples(List<int> timestamps) {
  if (timestamps.length < 2) return 1;

  final deltas = <int>[];
  for (var i = 1; i < timestamps.length; i++) {
    final delta = timestamps[i] - timestamps[i - 1];
    if (delta > 0) deltas.add(delta);
  }
  if (deltas.isEmpty) return 1;
  deltas.sort();
  final interval = deltas[deltas.length ~/ 2];

  var window = (kO2CellSpreadSmoothingSeconds / interval).round();
  if (window.isEven) window += 1;
  return window.clamp(1, _maxWindowSamples);
}

/// How well the cells agree at a point in time.
enum O2CellAgreement {
  /// Normal cell-to-cell variation. Rigs sit a couple of millivolts apart all
  /// dive; this is the state a healthy set is in essentially the whole time.
  tight,

  /// Far enough apart to be worth noticing, not far enough to be a verdict.
  drifting,

  /// A gap this wide is not sensitivity variation between healthy cells.
  wide,
}

/// Spread at which the cells stop reading as normal variation, in mV.
const double kO2CellDriftingMv = 5.0;

/// Spread at which the gap is too wide to explain as healthy cells, in mV.
const double kO2CellWideMv = 12.0;

O2CellAgreement o2CellAgreementFor(double spreadMv) {
  if (spreadMv >= kO2CellWideMv) return O2CellAgreement.wide;
  if (spreadMv >= kO2CellDriftingMv) return O2CellAgreement.drifting;
  return O2CellAgreement.tight;
}

/// A contiguous stretch of samples sharing one agreement level. Both indices
/// are inclusive.
typedef O2CellAgreementRun = ({
  int startIndex,
  int endIndex,
  O2CellAgreement level,
});

/// Run-length encodes [spread] into stretches of a single agreement level.
///
/// The status rug is drawn one segment per run, not one per sample: a steady
/// dive collapses to a single segment however long it is. Gaps end the current
/// run rather than being bridged, so a stretch with no cell data does not get
/// coloured as if it had been checked.
List<O2CellAgreementRun> o2CellAgreementRuns(List<double?> spread) {
  final runs = <O2CellAgreementRun>[];
  int? startIndex;
  O2CellAgreement? level;

  void close(int endIndex) {
    if (startIndex == null || level == null) return;
    runs.add((startIndex: startIndex!, endIndex: endIndex, level: level!));
    startIndex = null;
    level = null;
  }

  for (var i = 0; i < spread.length; i++) {
    final value = spread[i];
    if (value == null) {
      close(i - 1);
      continue;
    }
    final current = o2CellAgreementFor(value);
    if (level != current) {
      close(i - 1);
      startIndex = i;
      level = current;
    }
  }
  close(spread.length - 1);
  return runs;
}
