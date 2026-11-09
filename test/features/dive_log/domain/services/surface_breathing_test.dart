import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/services/gas_use_window.dart';
import 'package:submersion/features/dive_log/domain/services/surface_breathing.dart';

typedef _S = ({int t, double d});

/// Two minutes on the surface, 30 at 18 m, then ten more on the surface.
final _samples = <_S>[
  for (var t = 0; t <= 42 * 60; t += 10)
    (t: t, d: t < 2 * 60 || t > 32 * 60 ? 0.3 : 18.0),
];

GasUseWindow _underwater() =>
    gasUseWindowOf<_S>(_samples, time: (s) => s.t, depth: (s) => s.d)!;

List<PressureSample> _series(double Function(int t) bar) => [
  for (var t = 0; t <= 42 * 60; t += 10) (timestamp: t, bar: bar(t)),
];

SurfaceBreathing? _of({
  Iterable<int> switchTimes = const [],
  Iterable<List<PressureSample>> pressures = const [],
}) => surfaceBreathingOf(
  underwater: _underwater(),
  recordingStart: 0,
  recordingEnd: 42 * 60,
  switchTimes: switchTimes,
  pressures: pressures,
);

/// Breathing at the surface (issue #2930): what stretches the gas-use window
/// back over surface minutes a cylinder was breathed in.
void main() {
  test('the threshold is five bar', () {
    expect(kSurfaceBreathingMinDropBar, 5.0);
  });

  test('a switch logged on the surface stretches to the recording end', () {
    final breathing = _of(switchTimes: [0, 35 * 60])!;
    expect(breathing.from, isNull);
    expect(breathing.until, 42 * 60);
  });

  test('switches inside the window say nothing', () {
    expect(_of(switchTimes: [0, 20 * 60]), isNull);
  });

  test('a trailing fall of six bar stretches to its lowest point', () {
    // Steady through the dive's end, then 1 bar a minute from 33 to 39
    // minutes, then flat.
    double bar(int t) {
      if (t <= 33 * 60) return 120;
      if (t <= 39 * 60) return 120 - (t - 33 * 60) / 60;
      return 114;
    }

    final breathing = _of(pressures: [_series(bar)])!;
    expect(breathing.until, 39 * 60);
    expect(breathing.from, isNull);
  });

  test('a trailing fall under five bar says nothing', () {
    double bar(int t) => t <= 33 * 60 ? 120 : 117;
    expect(_of(pressures: [_series(bar)]), isNull);
  });

  test('a rise on the surface says nothing', () {
    double bar(int t) => t <= 33 * 60 ? 120 : 126;
    expect(_of(pressures: [_series(bar)]), isNull);
  });

  test('a leading fall stretches back to the last highest sample', () {
    // 210 bar until 30 s, falling to 204 by the descent at two minutes.
    double bar(int t) {
      if (t <= 30) return 210;
      if (t <= 2 * 60) return 210 - (t - 30) / 15;
      return 204;
    }

    final breathing = _of(pressures: [_series(bar)])!;
    expect(breathing.from, 30);
    expect(breathing.until, isNull);
  });

  test('the latest signal of several wins', () {
    double bar(int t) {
      if (t <= 33 * 60) return 120;
      if (t <= 36 * 60) return 120 - (t - 33 * 60) / 30;
      return 114;
    }

    final breathing = _of(switchTimes: [34 * 60], pressures: [_series(bar)])!;
    expect(breathing.until, 42 * 60);
  });

  group('gasUseWindowOf with surface breathing', () {
    test('stretches the end and averages the surface samples in', () {
      final window = gasUseWindowOf<_S>(
        _samples,
        time: (s) => s.t,
        depth: (s) => s.d,
        surfaceBreathing: const SurfaceBreathing(until: 39 * 60),
      )!;
      final underwater = _underwater();
      expect(window.startSeconds, underwater.startSeconds);
      expect(window.endSeconds, 39 * 60);
      expect(window.avgDepth, lessThan(underwater.avgDepth));
    });

    test('a stretch over the whole recording is no window', () {
      expect(
        gasUseWindowOf<_S>(
          _samples,
          time: (s) => s.t,
          depth: (s) => s.d,
          surfaceBreathing: const SurfaceBreathing(from: 0, until: 42 * 60),
        ),
        isNull,
      );
    });

    test('never shrinks the underwater window', () {
      final window = gasUseWindowOf<_S>(
        _samples,
        time: (s) => s.t,
        depth: (s) => s.d,
        surfaceBreathing: const SurfaceBreathing(from: 10 * 60, until: 60),
      )!;
      final underwater = _underwater();
      expect(window.startSeconds, underwater.startSeconds);
      expect(window.endSeconds, underwater.endSeconds);
    });
  });
}
