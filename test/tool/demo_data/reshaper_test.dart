import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/demo_data/src/shape/dive_shape.dart';
import '../../../tool/demo_data/src/shape/reshaper.dart';

/// A 30 m dive: 2 min descent, 25 min at depth, a 15 m/min ascent to a 3 min
/// stop at 5 m, then up. 10 s samples, one tank with a pressure trace.
DiveShape source() {
  double depthAt(int t) {
    if (t < 120) return t / 120 * 30;
    if (t < 1620) return 30;
    if (t < 1720) return max(5, 30 - (t - 1620) / 60 * 15);
    if (t < 1900) return 5;
    return max(0, 5 - (t - 1900) / 60 * 9);
  }

  return DiveShape(
    id: 'src',
    kinds: const {ShapeKind.recreational, ShapeKind.tankPressure},
    diveMode: 'oc',
    sampleIntervalSec: 10,
    samples: [
      for (var t = 0; t <= 1940; t += 10)
        ShapeSample(t: t, depth: depthAt(t), temp: 24),
    ],
    tanks: [
      ShapeTank(
        o2: 32,
        he: 0,
        role: 'backGas',
        volumeL: 11.1,
        startBar: 200,
        endBar: 70,
        pressures: [
          for (var t = 0; t <= 1940; t += 30) (t, 200 - t / 1940 * 130),
        ],
      ),
    ],
  );
}

/// Ascent rate in m/min over 30 s windows.
double maxAscentRate(DiveShape s) {
  var worst = 0.0;
  for (var i = 0; i < s.samples.length; i++) {
    for (var j = i + 1; j < s.samples.length; j++) {
      final dt = s.samples[j].t - s.samples[i].t;
      if (dt < 30) continue;
      final rate = (s.samples[i].depth - s.samples[j].depth) / dt * 60;
      worst = max(worst, rate);
      break;
    }
  }
  return worst;
}

void main() {
  test('the reshaped profile never matches the source scale exactly', () {
    for (var seed = 0; seed < 50; seed++) {
      final out = Reshaper(Random(seed)).reshape(source());
      final depthRatio = out.maxDepth / 30;
      final timeRatio = out.durationSec / 1940;
      expect(depthRatio, isNot(inInclusiveRange(0.97, 1.03)), reason: '$seed');
      expect(timeRatio, isNot(inInclusiveRange(0.97, 1.03)), reason: '$seed');
      expect(depthRatio, inInclusiveRange(0.84, 1.16), reason: '$seed');
    }
  });

  test('a target depth is honoured, kept off the source scale', () {
    final deeper = Reshaper(Random(1)).reshape(source(), targetMaxDepth: 33);
    expect(deeper.maxDepth, closeTo(33, 0.3));

    final same = Reshaper(Random(1)).reshape(source(), targetMaxDepth: 30.2);
    expect(same.maxDepth / 30, isNot(inInclusiveRange(0.97, 1.03)));
  });

  test('a rebreather shape is squeezed to as little as 0.7 of its depth', () {
    final ccr = DiveShape(
      id: 'ccr',
      kinds: const {ShapeKind.ccr},
      diveMode: 'ccr',
      sampleIntervalSec: 10,
      samples: source().samples,
      tanks: const [],
    );
    final squeezed = Reshaper(Random(1)).reshape(ccr, targetMaxDepth: 21.5);
    expect(squeezed.maxDepth, closeTo(21.5, 0.3));

    // Open circuit still stops at 0.85.
    final oc = Reshaper(Random(1)).reshape(source(), targetMaxDepth: 21.5);
    expect(oc.maxDepth, closeTo(30 * 0.85, 0.3));
    expect(Reshaper.minDepthScale('ccr'), 0.7);
    expect(Reshaper.minDepthScale('oc'), 0.85);
  });

  test('samples stay on the source interval', () {
    final out = Reshaper(Random(3)).reshape(source());

    for (var i = 1; i < out.samples.length; i++) {
      expect(out.samples[i].t - out.samples[i - 1].t, 10);
    }
  });

  test('the ascent rate stays within 18 m/min', () {
    for (var seed = 0; seed < 50; seed++) {
      final out = Reshaper(Random(seed)).reshape(source(), targetMaxDepth: 34);
      expect(maxAscentRate(out), lessThanOrEqualTo(18.01), reason: '$seed');
    }
  });

  test('tank pressure falls monotonically and ends above 30 bar', () {
    for (var seed = 0; seed < 50; seed++) {
      final tank = Reshaper(Random(seed))
          .reshape(source(), startBar: const [210], volumesL: const [10])
          .tanks
          .single;
      expect(tank.startBar, 210);
      for (var i = 1; i < tank.pressures.length; i++) {
        expect(
          tank.pressures[i].$2,
          lessThanOrEqualTo(tank.pressures[i - 1].$2),
          reason: '$seed',
        );
      }
      expect(tank.endBar, greaterThan(30), reason: '$seed');
      expect(tank.pressures.last.$2, closeTo(tank.endBar!, 0.6));
    }
  });

  test('the same seed gives the same output, and a new id', () {
    final a = Reshaper(Random(7)).reshape(source());
    final b = Reshaper(Random(7)).reshape(source());

    expect(jsonEncode(a.toJson()), jsonEncode(b.toJson()));
    expect(a.id, isNot('src'));
  });
}
