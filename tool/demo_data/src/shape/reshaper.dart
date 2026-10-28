import 'dart:math';

import 'dive_shape.dart';
import 'shape_extractor.dart';

/// Turns a real dive's shape into a new dive that matches no source dive one
/// to one (issue #3708), while staying physically believable.
///
/// - Time is stretched and depth scaled by factors drawn from
///   [0.85, 0.96] or [1.04, 1.15], never close to the source's own scale.
///   A target depth may scale a rebreather shape down to 0.7
///   ([minDepthScale]).
/// - The profile is re-sampled onto the source's regular sample interval,
///   as a dive computer would log it, with a little depth and temperature
///   jitter and a constant temperature offset.
/// - The ascent rate never goes past [ascentLimit], measured over 30 s.
/// - Each tank's pressure trace keeps the source's shape of gas use, re-fitted
///   to the new tank: gas used scales with time and ambient pressure, and the
///   tank never ends below 40 bar.
class Reshaper {
  Reshaper(this.random);

  final Random random;

  static const ascentLimit = 18.0;

  /// The least a target depth may scale a shape's depth by. Rebreather
  /// shapes are scarce and deep in the harvest, so they may be squeezed
  /// further, to reach the depths a first rebreather card allows.
  static double minDepthScale(String diveMode) =>
      diveMode == 'ccr' ? 0.7 : 0.85;

  /// The limit the time stretch aims for, leaving room for jitter.
  static const _ascentTarget = 17.4;

  DiveShape reshape(
    DiveShape source, {
    double? targetMaxDepth,
    List<double>? startBar,
    List<double>? volumesL,
  }) {
    final interval = source.sampleIntervalSec;
    final srcMax = source.maxDepth;
    final srcDur = source.durationSec;

    var df = targetMaxDepth == null
        ? _offScale()
        : (targetMaxDepth / srcMax).clamp(minDepthScale(source.diveMode), 1.15);
    if (df > 0.96 && df < 1.04) df = df < 1 ? 0.96 : 1.04;

    var tf = _offScale();
    final rate = _maxAscent(source.samples);
    tf = max(tf, df * rate / _ascentTarget);
    var newDur = (srcDur * tf / interval).round() * interval;
    while ((newDur / srcDur - 1).abs() < 0.04) {
      newDur += interval;
    }
    tf = newDur / srcDur;

    final tempOffset = _uniform(-1.5, 1.5);
    final hrFactor = _uniform(0.9, 1.1);
    final samples = <ShapeSample>[];
    for (var t = 0; t <= newDur; t += interval) {
      final s = _at(source.samples, t / tf);
      final base = s.depth * df;
      samples.add(
        ShapeSample(
          t: t,
          depth: base > 1 ? _round(base + _uniform(-0.1, 0.1), 0.01) : base,
          temp: s.temp == null
              ? null
              : _round(s.temp! + tempOffset + _uniform(-0.1, 0.1), 0.1),
          heartRate: s.heartRate == null
              ? null
              : (s.heartRate! * hrFactor).round(),
          ppO2: s.ppO2 == null
              ? null
              : _round(s.ppO2! + _uniform(-0.02, 0.02), 0.01),
          setpoint: s.setpoint,
          cells: s.cells
              ?.map((c) => _round(c + _uniform(-0.02, 0.02), 0.01))
              .toList(),
        ),
      );
    }

    final avgSrc = _avgDepth(source.samples);
    final avgNew = _avgDepth(samples);
    final gasScale = tf * (1 + avgNew / 10) / (1 + avgSrc / 10);
    final tanks = [
      for (var i = 0; i < source.tanks.length; i++)
        _reshapeTank(
          source.tanks[i],
          tf: tf,
          gasScale: gasScale,
          startBar: startBar != null && i < startBar.length
              ? startBar[i]
              : null,
          volumeL: volumesL != null && i < volumesL.length ? volumesL[i] : null,
        ),
    ];

    return DiveShape(
      id: ShapeExtractor.shapeId(samples),
      kinds: source.kinds,
      diveMode: source.diveMode,
      sampleIntervalSec: interval,
      samples: samples,
      tanks: tanks,
      computerCount: source.computerCount,
    );
  }

  ShapeTank _reshapeTank(
    ShapeTank t, {
    required double tf,
    required double gasScale,
    double? startBar,
    double? volumeL,
  }) {
    final trace = t.pressures;
    final srcStart = t.startBar ?? (trace.isEmpty ? 200.0 : trace.first.$2);
    final srcEnd = t.endBar ?? (trace.isEmpty ? srcStart * 0.4 : trace.last.$2);
    final srcVol = t.volumeL ?? volumeL ?? 11.1;
    final newVol = volumeL ?? srcVol;
    final newStart =
        startBar ?? _round(srcStart + _uniform(-10, 10), 1).clamp(150.0, 300.0);

    final usedLiters = max(0.0, srcStart - srcEnd) * srcVol;
    var usedBar = usedLiters * gasScale * _uniform(0.95, 1.05) / newVol;
    if (newStart - usedBar < 40) usedBar = newStart - _uniform(40, 60);
    final newEnd = _round(newStart - usedBar, 0.5);

    final traceStart = trace.isEmpty ? srcStart : trace.first.$2;
    final traceEnd = trace.isEmpty ? srcEnd : trace.last.$2;
    final span = max(1.0, traceStart - traceEnd);
    var usedSoFar = 0.0;
    var last = double.infinity;
    final pressures = <(int, double)>[];
    for (var i = 0; i < trace.length; i++) {
      final (time, bar) = trace[i];
      usedSoFar = max(usedSoFar, ((traceStart - bar) / span).clamp(0.0, 1.0));
      final isLast = i == trace.length - 1;
      final value = isLast
          ? newEnd
          : _round(newStart - usedBar * usedSoFar, 0.5);
      last = min(last, max(value, newEnd));
      pressures.add(((time * tf).round(), last));
    }

    return ShapeTank(
      o2: t.o2,
      he: t.he,
      role: t.role,
      volumeL: newVol,
      startBar: newStart,
      endBar: newEnd,
      pressures: pressures,
    );
  }

  double _offScale() =>
      random.nextBool() ? _uniform(0.85, 0.96) : _uniform(1.04, 1.15);

  double _uniform(double lo, double hi) => lo + random.nextDouble() * (hi - lo);

  static double _round(double v, double step) => (v / step).round() * step;

  static double _avgDepth(List<ShapeSample> s) =>
      s.isEmpty ? 0 : s.fold<double>(0, (sum, x) => sum + x.depth) / s.length;

  /// The worst ascent in m/min over 30 s windows.
  static double _maxAscent(List<ShapeSample> s) {
    var worst = 0.0;
    var j = 0;
    for (var i = 0; i < s.length; i++) {
      if (j <= i) j = i + 1;
      while (j < s.length && s[j].t - s[i].t < 30) {
        j++;
      }
      if (j >= s.length) break;
      final rate = (s[i].depth - s[j].depth) / (s[j].t - s[i].t) * 60;
      if (rate > worst) worst = rate;
    }
    return worst;
  }

  /// The source sample at [t] seconds, interpolated.
  static ShapeSample _at(List<ShapeSample> s, double t) {
    if (t <= s.first.t) return s.first;
    if (t >= s.last.t) return s.last;
    var lo = 0;
    var hi = s.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (s[mid].t <= t) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final a = s[lo];
    final b = s[hi];
    final f = (t - a.t) / (b.t - a.t);
    double? lerp(double? x, double? y) =>
        x == null || y == null ? (x ?? y) : x + (y - x) * f;
    return ShapeSample(
      t: t.round(),
      depth: lerp(a.depth, b.depth)!,
      temp: lerp(a.temp, b.temp),
      heartRate: lerp(
        a.heartRate?.toDouble(),
        b.heartRate?.toDouble(),
      )?.round(),
      ppO2: lerp(a.ppO2, b.ppO2),
      setpoint: f < 0.5 ? a.setpoint : b.setpoint,
      cells:
          a.cells == null ||
              b.cells == null ||
              a.cells!.length != b.cells!.length
          ? (a.cells ?? b.cells)
          : [
              for (var i = 0; i < a.cells!.length; i++)
                lerp(a.cells![i], b.cells![i])!,
            ],
    );
  }
}
