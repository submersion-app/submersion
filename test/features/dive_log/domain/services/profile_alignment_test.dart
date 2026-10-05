import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/profile_alignment.dart';

/// Knots of a 48 minute multilevel reef dive: (seconds, metres).
const _reefKnots = <(int, double)>[
  (0, 0),
  (120, 18),
  (240, 22),
  (600, 21),
  (900, 16),
  (1300, 14),
  (1700, 10),
  (2200, 8),
  (2400, 5),
  (2580, 5),
  (2760, 4.8),
  (2880, 0),
];

double _depthOn(List<(int, double)> knots, int t) {
  if (t <= knots.first.$1) return knots.first.$2;
  for (var i = 1; i < knots.length; i++) {
    final (t0, d0) = knots[i - 1];
    final (t1, d1) = knots[i];
    if (t <= t1) return d0 + (d1 - d0) * (t - t0) / (t1 - t0);
  }
  return knots.last.$2;
}

/// Samples [knots] every [interval] seconds. [lead] seconds of surface come
/// first (a computer that started logging early); [skip] drops the first
/// [skip] seconds of the dive (a computer switched on late); [scale]
/// multiplies every depth (fresh versus salt water calibration).
List<DiveProfilePoint> trace(
  List<(int, double)> knots, {
  int interval = 10,
  int lead = 0,
  int skip = 0,
  double scale = 1.0,
}) {
  final end = knots.last.$1 - skip + lead;
  return [
    for (var t = 0; t <= end; t += interval)
      DiveProfilePoint(
        timestamp: t,
        depth: t < lead ? 0 : _depthOn(knots, t - lead + skip) * scale,
      ),
  ];
}

void main() {
  const aligner = ProfileAligner();
  final reef = trace(_reefKnots);

  test('identical traces align at 0 with no error and a strong match', () {
    final r = aligner.align(reef, trace(_reefKnots));
    expect(r.offsetSeconds, 0);
    expect(r.rmsDepthError, closeTo(0, 1e-9));
    expect(r.usedFallback, isFalse);
    expect(r.isStrongMatch, isTrue);
  });

  test('a secondary that logged 40 s at the surface first is shifted back '
      '40 s', () {
    final r = aligner.align(reef, trace(_reefKnots, lead: 40));
    expect(r.offsetSeconds, -40);
    expect(r.isStrongMatch, isTrue);
  });

  test('a secondary switched on 90 s late is shifted forward about 90 s, '
      'whatever its sample rate', () {
    final r = aligner.align(reef, trace(_reefKnots, interval: 20, skip: 90));
    expect(r.offsetSeconds, closeTo(90, 3));
    expect(r.isStrongMatch, isTrue);
  });

  test(
    'a 3% depth scale (fresh versus salt water) is still a strong match',
    () {
      final r = aligner.align(reef, trace(_reefKnots, lead: 40, scale: 1.03));
      expect(r.offsetSeconds, closeTo(-40, 2));
      expect(r.isStrongMatch, isTrue);
    },
  );

  test('two different dives are not a strong match', () {
    const square = <(int, double)>[
      (0, 0),
      (90, 35),
      (1500, 35),
      (1800, 6),
      (1980, 6),
      (2040, 0),
    ];
    final r = aligner.align(reef, trace(square));
    expect(r.usedFallback, isFalse);
    expect(r.isStrongMatch, isFalse);
  });

  test('an empty profile falls back to offset 0 with no score', () {
    final r = aligner.align(reef, const []);
    expect(r.offsetSeconds, 0);
    expect(r.usedFallback, isTrue);
    expect(r.rmsDepthError, isNull);
    expect(r.isStrongMatch, isFalse);
  });

  test('a profile that never leaves the surface falls back', () {
    final surface = [
      for (var t = 0; t <= 600; t += 10)
        DiveProfilePoint(timestamp: t, depth: t == 300 ? 1.0 : 0.2),
    ];
    final r = aligner.align(surface, reef);
    expect(r.usedFallback, isTrue);
    expect(r.offsetSeconds, 0);
  });

  test('a flat profile ties to offset 0', () {
    final flat = [
      for (var t = 0; t <= 1800; t += 10)
        DiveProfilePoint(timestamp: t, depth: 10),
    ];
    final r = aligner.align(flat, [...flat]);
    expect(r.offsetSeconds, 0);
  });

  test('the search stays inside the window', () {
    // 20 minutes of surface before the descent: the true shift (-1200 s) is
    // outside the 15 minute window, so the result must not exceed it.
    final r = aligner.align(reef, trace(_reefKnots, lead: 1200));
    expect(r.offsetSeconds.abs(), lessThanOrEqualTo(900));
  });

  test('a short dive narrows the window to half its span', () {
    const short = <(int, double)>[(0, 0), (60, 8), (480, 8), (600, 0)];
    final r = aligner.align(trace(short), trace(short, lead: 400));
    expect(r.offsetSeconds.abs(), lessThanOrEqualTo(300));
  });

  test('copyWith replaces only the offset', () {
    final r = aligner.align(reef, trace(_reefKnots, lead: 40));
    final moved = r.copyWith(offsetSeconds: 0);
    expect(moved.offsetSeconds, 0);
    expect(moved.rmsDepthError, r.rmsDepthError);
    expect(moved.isStrongMatch, r.isStrongMatch);
  });
}
