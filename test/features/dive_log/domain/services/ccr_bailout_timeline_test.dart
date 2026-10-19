import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/services/ccr_bailout_timeline.dart';

/// Issue #3307: a CCR transmitter's name-derived role is checked against when
/// its cylinder lost pressure. A bailout is flat on the loop and drains on
/// open circuit; an O2 supply or diluent drains on the loop.
void main() {
  const loopTanks = {'dil', 'o2'};
  bool isLoop(String k) => loopTanks.contains(k);

  /// One sample every 10 s from [from] to [to] (inclusive), dropping
  /// [barPerMinute] from [startBar].
  List<TimelinePressure> series(
    int from,
    int to,
    double startBar,
    double barPerMinute,
  ) => [
    for (var t = from; t <= to; t += 10)
      (t: t, bar: startBar - barPerMinute * (t - from) / 60),
  ];

  test('a bailout breathed after a switch to OC is flagged', () {
    final result = bailoutEvidence<String>(
      switches: [(t: 2400, tankKey: 'oc')],
      isLoopTank: isLoop,
      pressures: {
        'tx': [...series(0, 2390, 200, 0), ...series(2400, 3000, 200, 6)],
      },
      candidates: ['tx'],
      inWaterEndSeconds: null,
    );
    expect(result, hasLength(1));
    final e = result!.single;
    expect(e.tankKey, 'tx');
    expect(e.ocTankKey, 'oc');
    expect(e.ocDropBar, closeTo(60, 0.001));
    expect(e.loopRate, closeTo(0, 0.001));
    expect(e.ocRate, closeTo(6, 0.01));
  });

  test('a true O2 supply is not flagged', () {
    final result = bailoutEvidence<String>(
      switches: [(t: 2400, tankKey: 'oc')],
      isLoopTank: isLoop,
      pressures: {
        'tx': [...series(0, 2400, 200, 0.5), ...series(2410, 3000, 180, 0)],
      },
      candidates: ['tx'],
      inWaterEndSeconds: null,
    );
    expect(result, isEmpty);
  });

  test('an mCCR O2 supply on a long OC deco is not flagged', () {
    // The constant-mass-flow orifice bleeds at the same rate on the loop and
    // on open circuit: 1 bar/min for the whole hour, bailout at 20 minutes.
    final result = bailoutEvidence<String>(
      switches: [(t: 1200, tankKey: 'oc')],
      isLoopTank: isLoop,
      pressures: {'tx': series(0, 3600, 200, 1)},
      candidates: ['tx'],
      inWaterEndSeconds: null,
    );
    expect(result, isEmpty);
  });

  test('topside bleed-down after a dive ends on OC does not count', () {
    final result = bailoutEvidence<String>(
      switches: [(t: 2400, tankKey: 'oc')],
      isLoopTank: isLoop,
      pressures: {
        'tx': [...series(0, 3000, 200, 0), ...series(3010, 3600, 200, 5)],
      },
      candidates: ['tx'],
      inWaterEndSeconds: 3000,
    );
    expect(result, isEmpty);
  });

  test('first switch to a loop tank skips the dive', () {
    final result = bailoutEvidence<String>(
      switches: [(t: 600, tankKey: 'dil'), (t: 2400, tankKey: 'oc')],
      isLoopTank: isLoop,
      pressures: {
        'tx': [...series(0, 2390, 200, 0), ...series(2400, 3000, 200, 6)],
      },
      candidates: ['tx'],
      inWaterEndSeconds: null,
    );
    expect(result, isNull);
  });

  test('no switches skips the dive', () {
    final result = bailoutEvidence<String>(
      switches: const [],
      isLoopTank: isLoop,
      pressures: {'tx': series(0, 3000, 200, 1)},
      candidates: ['tx'],
      inWaterEndSeconds: null,
    );
    expect(result, isNull);
  });

  test('OC time under 120 s is not flagged', () {
    final result = bailoutEvidence<String>(
      switches: [(t: 2400, tankKey: 'oc'), (t: 2460, tankKey: 'dil')],
      isLoopTank: isLoop,
      pressures: {
        'tx': [
          ...series(0, 2390, 200, 0),
          ...series(2400, 2460, 200, 30),
          ...series(2470, 3000, 170, 0),
        ],
      },
      candidates: ['tx'],
      inWaterEndSeconds: null,
    );
    expect(result, isEmpty);
  });

  // Review: a transmitter dropout (a reading of 0, or one isolated low
  // sample) is not a pressure drop.
  test('a dropout on open circuit does not flag an O2 supply', () {
    final o2 = [...series(0, 2400, 200, 0.5), ...series(2410, 3000, 180, 0)];
    final withDropout = [
      for (final p in o2) p.t == 2700 ? (t: 2700, bar: 0.0) : p,
    ];
    final result = bailoutEvidence<String>(
      switches: [(t: 2400, tankKey: 'oc')],
      isLoopTank: isLoop,
      pressures: {'tx': withDropout},
      candidates: ['tx'],
      inWaterEndSeconds: null,
    );
    expect(result, isEmpty);
  });

  test('an isolated low sample on the loop does not hide a bailout', () {
    final bailout = [...series(0, 2390, 200, 0), ...series(2400, 3000, 200, 6)];
    final withDip = [
      for (final p in bailout) p.t == 1200 ? (t: 1200, bar: 60.0) : p,
    ];
    final result = bailoutEvidence<String>(
      switches: [(t: 2400, tankKey: 'oc')],
      isLoopTank: isLoop,
      pressures: {'tx': withDip},
      candidates: ['tx'],
      inWaterEndSeconds: null,
    );
    expect(result, hasLength(1));
  });
}
