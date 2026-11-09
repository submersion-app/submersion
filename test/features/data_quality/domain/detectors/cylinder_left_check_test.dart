import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/profile/tank_pressure_glitches.dart';
import 'package:submersion/features/data_quality/domain/detectors/cylinder_left_check.dart';
import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';

/// A reading every 10 s to [end], losing [barPerMinute] bar a minute at [t].
List<PressureReading> series(int end, double Function(int t) barPerMinute) {
  final out = <PressureReading>[];
  var bar = 200.0;
  for (var t = 0; t <= end; t += 10) {
    if (t > 0) bar -= barPerMinute(t) * 10 / 60;
    out.add((t: t, bar: bar));
  }
  return out;
}

List<QualitySample> profile(int end, double Function(int t) depthAt) => [
  for (var t = 0; t <= end; t += 10) QualitySample(t: t, depth: depthAt(t)),
];

/// Issue #165: a pause in a cylinder's fall is a hand-over only when the
/// cylinder stopped being breathed, not when a shallower depth slowed it.
void main() {
  // 30 m to 40:00, then a stop at 5 m.
  final samples = profile(2800, (t) => t <= 2400 ? 30 : 5);

  test('a cylinder that stops losing pressure was left', () {
    expect(
      cylinderLeftBetween(
        series: series(2800, (t) => t <= 2400 ? 3 : 0),
        samples: samples,
        from: 2400,
        to: 2800,
      ),
      isTrue,
    );
  });

  test('one breathed at the same rate for its depth was not left', () {
    // 3 bar a minute at 4 bar ambient is 1.1 bar a minute at 1.5 bar.
    expect(
      cylinderLeftBetween(
        series: series(2800, (t) => t <= 2400 ? 3 : 1.1),
        samples: samples,
        from: 2400,
        to: 2800,
      ),
      isFalse,
    );
  });

  test('a cylinder warming back up after it was left was left', () {
    expect(
      cylinderLeftBetween(
        series: series(2800, (t) => t <= 2400 ? 3 : -0.2),
        samples: samples,
        from: 2400,
        to: 2800,
      ),
      isTrue,
    );
  });

  test('nothing to compare against says nothing was left', () {
    final flat = series(2800, (_) => 0);
    expect(
      cylinderLeftBetween(series: flat, samples: samples, from: 2400, to: 2800),
      isFalse,
    );
    expect(
      cylinderLeftBetween(
        series: const [],
        samples: samples,
        from: 2400,
        to: 2800,
      ),
      isFalse,
    );
    expect(
      cylinderLeftBetween(
        series: series(2800, (_) => 3),
        samples: samples,
        from: 0,
        to: 600,
      ),
      isFalse,
    );
  });
}
