import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/utils/time_weighted_mean.dart';
import 'package:submersion/features/dive_log/domain/services/gas_use_window.dart';

typedef _S = ({int t, double d});

GasUseWindow? _window(List<_S> samples) =>
    gasUseWindowOf<_S>(samples, time: (s) => s.t, depth: (s) => s.d);

/// The gas-use window of a profile: the time the diver was underwater, with
/// surface runs at the start and the end left out (issue #2930).
void main() {
  test('the surface threshold is one metre', () {
    expect(kGasUseSurfaceDepthM, 1.0);
  });

  test('a trailing surface tail is left out', () {
    const samples = <_S>[
      (t: 0, d: 0),
      (t: 60, d: 5),
      (t: 600, d: 12),
      (t: 1200, d: 4),
      (t: 1260, d: 0.5),
      (t: 1500, d: 0.3),
      (t: 1800, d: 0.2),
    ];
    final window = _window(samples)!;
    expect(window.startSeconds, 0);
    expect(window.endSeconds, 1260);
    expect(window.seconds, 1260);
    expect(
      window.avgDepth,
      closeTo(
        timeWeightedMean<_S>(
          samples.take(5),
          time: (s) => s.t,
          value: (s) => s.d,
        )!,
        1e-9,
      ),
    );
    expect(window.use, GasUse(seconds: 1260, avgDepth: window.avgDepth));
  });

  test('a leading surface run is left out', () {
    final window = _window(const [
      (t: 0, d: 0.2),
      (t: 120, d: 0.4),
      (t: 180, d: 6),
      (t: 900, d: 6),
      (t: 960, d: 0),
    ])!;
    expect(window.startSeconds, 120);
    expect(window.endSeconds, 960);
    expect(window.seconds, 840);
  });

  test('nothing to trim gives no window', () {
    expect(
      _window(const [(t: 0, d: 0), (t: 60, d: 10), (t: 120, d: 0)]),
      isNull,
    );
  });

  test('a dive that starts and ends underwater gives no window', () {
    expect(
      _window(const [(t: 0, d: 3), (t: 60, d: 10), (t: 120, d: 2)]),
      isNull,
    );
  });

  test('no underwater sample, one sample, or none gives no window', () {
    expect(_window(const [(t: 0, d: 0.5), (t: 60, d: 0.9)]), isNull);
    expect(_window(const [(t: 0, d: 10)]), isNull);
    expect(_window(const []), isNull);
  });

  test('a surface interval in the middle of the dive is not trimmed', () {
    expect(
      _window(const [
        (t: 0, d: 0),
        (t: 60, d: 8),
        (t: 300, d: 0.2),
        (t: 360, d: 8),
        (t: 600, d: 0),
      ]),
      isNull,
    );
  });

  test('unsorted samples give the same window as sorted ones', () {
    const sorted = <_S>[
      (t: 0, d: 0),
      (t: 60, d: 5),
      (t: 600, d: 12),
      (t: 1200, d: 4),
      (t: 1260, d: 0.5),
      (t: 1800, d: 0.2),
    ];
    final shuffled = [
      sorted[3],
      sorted[0],
      sorted[5],
      sorted[1],
      sorted[4],
      sorted[2],
    ];
    final a = _window(sorted)!;
    final b = _window(shuffled)!;
    expect(b.startSeconds, a.startSeconds);
    expect(b.endSeconds, a.endSeconds);
    expect(b.avgDepth, a.avgDepth);
  });

  test('a recording that starts at a nonzero time keeps its own times', () {
    final window = _window(const [
      (t: 30, d: 0.1),
      (t: 90, d: 0.1),
      (t: 100, d: 4),
      (t: 700, d: 4),
      (t: 710, d: 0.2),
    ])!;
    expect(window.startSeconds, 90);
    expect(window.endSeconds, 710);
  });
}
