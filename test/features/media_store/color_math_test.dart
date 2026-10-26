import 'package:flutter_test/flutter_test.dart';
import 'package:submersion_transcoder/submersion_transcoder.dart';

import 'color_timeline_test.dart' show gains20, identity20;

List<double> gainsWithOffset20(double r, double g, double b, double o) => [
  r, 0, 0, 0, o, //
  0, g, 0, 0, o, //
  0, 0, b, 0, o, //
  0, 0, 0, 1, 0, //
];

/// Issue #3521: the one colour formula every native encoder applies.
void main() {
  test('sdr equals applyToPixel / 255', () {
    final out = correctPixel(
      [0.5, 0.5, 0.5],
      gainsWithOffset20(1.2, 1, 0.8, 25.5),
      SignalTransfer.sdr,
    );
    expect(out[0], closeTo(0.7, 1e-9));
    expect(out[1], closeTo(0.6, 1e-9));
    expect(out[2], closeTo(0.5, 1e-9));
  });

  test('sdr mixes channels and counts the alpha column as 1', () {
    final m = List<double>.of(identity20)
      ..[1] = 0.5
      ..[3] = 0.1;
    final out = correctPixel([0.2, 0.4, 0.6], m, SignalTransfer.sdr);
    expect(out[0], closeTo(0.2 + 0.2 + 0.1, 1e-9));
  });

  test('sdr clamps', () {
    expect(correctPixel([1, 1, 1], gains20(2, 2, 2), SignalTransfer.sdr), [
      1,
      1,
      1,
    ]);
  });

  for (final tr in [SignalTransfer.pq, SignalTransfer.hlg]) {
    test('$tr identity round-trips', () {
      for (final c in [
        [0.1, 0.4, 0.7],
        [0.58, 0.58, 0.58],
        [0.9, 0.2, 0.05],
      ]) {
        final out = correctPixel(c, identity20, tr);
        for (var i = 0; i < 3; i++) {
          expect(out[i], closeTo(c[i], 1e-6), reason: '$c channel $i');
        }
      }
    });
  }

  test('pq transfer round-trips', () {
    for (final nits in [0.1, 100.0, 203.0, 1000.0, 10000.0]) {
      expect(pqEotf(pqInverseEotf(nits)), closeTo(nits, nits * 1e-6));
    }
  });

  test('hlg transfer round-trips', () {
    for (final l in [0.0, 0.01, 1 / 12, 0.26497, 1.0]) {
      expect(hlgInverseOetf(hlgOetf(l)), closeTo(l, 1e-9));
    }
  });

  test('pq reference white behaves like sdr white', () {
    final e = pqInverseEotf(203);
    final out = correctPixel(
      [e, e, e],
      gains20(0.5, 0.5, 0.5),
      SignalTransfer.pq,
    );
    // 0.5 in extended sRGB is linear 0.21404 of SDR white.
    expect(pqEotf(out[0]) / 203, closeTo(0.21404, 1e-4));
  });

  test('pq highlight above white is not clipped by the matrix', () {
    final e = pqInverseEotf(1000);
    final out = correctPixel([e, e, e], gains20(1.1, 1, 1), SignalTransfer.pq);
    expect(pqEotf(out[0]), greaterThan(1000));
  });

  test('hlg inverse OETF at the 75% reference level', () {
    expect(hlgInverseOetf(0.75), closeTo(0.26497, 1e-4));
  });

  test('hlg reference white behaves like sdr white', () {
    final out = correctPixel(
      [0.75, 0.75, 0.75],
      gains20(0.5, 0.5, 0.5),
      SignalTransfer.hlg,
    );
    expect(
      hlgInverseOetf(out[0]) / hlgInverseOetf(0.75),
      closeTo(0.21404, 1e-4),
    );
  });
}
