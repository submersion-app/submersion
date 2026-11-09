import 'dart:math' as math;

import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/profile/tank_pressure_glitches.dart';
import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';

/// How long before a pause a cylinder's breathing rate is measured over, in
/// seconds.
const int kLeftRateWindowSeconds = 300;

/// The share of a cylinder's breathing rate, both scaled to the surface,
/// that it must fall below during a pause to count as left. A diver at a
/// 5 m stop breathes about a third of the gas they did at 30 m, so the bar a
/// minute drops that far while the depth-scaled rate stays about the same;
/// a cylinder nobody breathes loses next to nothing.
const double kLeftRateFraction = 0.5;

/// Whether [series] shows its cylinder left between [from] and [to], rather
/// than breathed more slowly (issue #165).
///
/// A large cylinder breathed at a shallow stop can lose too little to read
/// as falling, so a pause in its fall alone does not say the diver changed
/// to another cylinder. Its loss during the pause is compared with its loss
/// over the [kLeftRateWindowSeconds] before it, each divided by the ambient
/// pressure the diver breathed at: below [kLeftRateFraction] of the earlier
/// rate, the cylinder was left. [series] is in time order and free of
/// glitches; [samples] is the profile, in time order. False when there is
/// no breathing before [from] to compare with.
bool cylinderLeftBetween({
  required List<PressureReading> series,
  required List<QualitySample> samples,
  required int from,
  required int to,
  DiveEnvironment? environment,
}) {
  if (series.isEmpty || samples.isEmpty || to <= from) return false;
  final before = math.max(series.first.t, from - kLeftRateWindowSeconds);
  if (before >= from) return false;
  double ambient(int a, int b) =>
      _ambientBarSeconds(samples, a, b, environment);
  final breathed =
      (_barAt(series, before) - _barAt(series, from)) / ambient(before, from);
  if (breathed <= 0) return false;
  final paused =
      (_barAt(series, from) - _barAt(series, to)) / ambient(from, to);
  return paused < breathed * kLeftRateFraction;
}

/// The depth at [t], interpolated linearly between the bracketing samples
/// as the switch editor's profile lookup does (`profileDepthAt`); the first
/// or last depth outside the profile. [samples] is in time order.
double qualityDepthAt(List<QualitySample> samples, int t) {
  if (t <= samples.first.t) return samples.first.depth;
  if (t >= samples.last.t) return samples.last.depth;
  final lo = _lastAtOrBefore(samples.length, (i) => samples[i].t, t);
  final a = samples[lo];
  final b = samples[lo + 1];
  final span = b.t - a.t;
  if (span <= 0) return b.depth;
  return a.depth + (b.depth - a.depth) * (t - a.t) / span;
}

/// The bar [series] reads at [t], interpolated linearly; its first or last
/// reading outside it.
double _barAt(List<PressureReading> series, int t) {
  if (t <= series.first.t) return series.first.bar;
  if (t >= series.last.t) return series.last.bar;
  final lo = _lastAtOrBefore(series.length, (i) => series[i].t, t);
  final a = series[lo];
  final b = series[lo + 1];
  final span = b.t - a.t;
  if (span <= 0) return b.bar;
  return a.bar + (b.bar - a.bar) * (t - a.t) / span;
}

/// The ambient pressure breathed between [a] and [b], in bar seconds,
/// integrated over the profile's samples (trapezoids).
double _ambientBarSeconds(
  List<QualitySample> samples,
  int a,
  int b,
  DiveEnvironment? environment,
) {
  double ambientAt(double depth) {
    final d = math.max(depth, 0.0);
    return environment?.pressureAtDepth(d) ?? 1.0 + d / 10.0;
  }

  double barAt(int t) => ambientAt(qualityDepthAt(samples, t));

  var total = 0.0;
  var t0 = a;
  var p0 = barAt(a);
  var i = a < samples.first.t
      ? 0
      : _lastAtOrBefore(samples.length, (i) => samples[i].t, a) + 1;
  for (; i < samples.length && samples[i].t < b; i++) {
    final t1 = samples[i].t;
    if (t1 <= t0) continue;
    // A sample's own depth: only the window's ends need interpolating.
    final p1 = ambientAt(samples[i].depth);
    total += (p0 + p1) / 2 * (t1 - t0);
    (t0, p0) = (t1, p1);
  }
  return total + (p0 + barAt(b)) / 2 * (b - t0);
}

/// The last index of a time-ordered list of [length] whose time ([timeAt])
/// is at or before [t]; the first one's time is at or before [t].
int _lastAtOrBefore(int length, int Function(int i) timeAt, int t) {
  var lo = 0;
  var hi = length - 1;
  while (lo < hi) {
    final mid = (lo + hi + 1) >> 1;
    if (timeAt(mid) <= t) {
      lo = mid;
    } else {
      hi = mid - 1;
    }
  }
  return lo;
}
