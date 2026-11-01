import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/profile/tank_pressure_glitches.dart';
import 'package:submersion/features/dive_log/domain/services/cylinder_breath_starts.dart';

const _rate = 3.4 / 60; // bar a second: 15 L/min at 6 m from a 7 L bottle.

/// A reading every 2 seconds for [seconds], rounded to whole bar the way a
/// transmitter reports them.
List<PressureReading> _series(
  int seconds,
  double Function(int t) bar, {
  bool round = true,
}) => [
  for (var t = 0; t < seconds; t += 2)
    (t: t, bar: round ? bar(t).roundToDouble() : bar(t)),
];

/// Held at 200 bar, then breathed in turns of [turn] seconds separated by
/// holds of [rest] seconds, starting at [lead]. [drift] is bar a second lost
/// during a hold.
double Function(int) _turns({
  required int lead,
  required int turn,
  required int rest,
  required int count,
  double drift = 0,
}) => (t) {
  var bar = 200.0;
  var at = 0;
  void hold(int seconds) {
    bar -= drift * math.min(seconds, math.max(0, t - at));
    at += seconds;
  }

  hold(lead);
  for (var i = 0; i < count; i++) {
    bar -= _rate * math.min(turn, math.max(0, t - at));
    at += turn;
    hold(rest);
  }
  return bar;
};

void main() {
  group('cylinderBreathStarts', () {
    test('finds the turn after a hold, shortly after it began', () {
      final starts = cylinderBreathStarts(
        _series(2400, (t) => t < 1200 ? 200 : 200 - (t - 1200) * _rate),
      );

      expect(starts, hasLength(1));
      expect(starts.single, inInclusiveRange(1202, 1230));
    });

    test('a cylinder falling from its first reading gives no start', () {
      expect(
        cylinderBreathStarts(_series(2400, (t) => 200 - t * _rate)),
        isEmpty,
      );
    });

    test('a sidemount rotation gives one start a turn', () {
      final starts = cylinderBreathStarts(
        _series(
          480 + 960 * 3,
          _turns(lead: 480, turn: 480, rest: 480, count: 3),
        ),
      );

      expect(starts, hasLength(3));
      expect(starts[0], inInclusiveRange(482, 510));
      expect(starts[1], inInclusiveRange(1442, 1470));
      expect(starts[2], inInclusiveRange(2402, 2430));
    });

    test('slow drift for a whole dive gives no start', () {
      expect(
        cylinderBreathStarts(_series(3600, (t) => 200 - t * 0.5 / 60)),
        isEmpty,
      );
    });

    test('drift during the holds does not hide the turns', () {
      final starts = cylinderBreathStarts(
        _series(
          600 + 900 * 3,
          _turns(lead: 600, turn: 600, rest: 300, count: 3, drift: 0.5 / 60),
        ),
      );

      expect(starts, hasLength(3));
    });

    test('a dip that recovers gives no start', () {
      expect(
        cylinderBreathStarts(
          _series(2400, (t) => t > 1200 && t < 1220 ? 195.5 : 200),
        ),
        isEmpty,
      );
      expect(
        cylinderBreathStarts(
          _series(2400, (t) => t > 1200 && t < 1240 ? 192 : 200),
        ),
        isEmpty,
      );
    });

    test('a two-reading dropout gives no start', () {
      expect(
        cylinderBreathStarts(
          _series(2400, (t) => t > 1200 && t <= 1204 ? 3 : 200),
        ),
        isEmpty,
      );
    });

    test('a hose filling gives no start', () {
      expect(
        cylinderBreathStarts(_series(2400, (t) => t < 1200 ? 200 : 197)),
        isEmpty,
      );
      expect(
        cylinderBreathStarts(
          _series(2400, (t) => t < 1200 ? 200 : 197 - (t - 1200) * 0.5 / 60),
        ),
        isEmpty,
      );
    });

    test('cooling after a hold gives no start', () {
      const loss = 200 * 10 / 300;
      expect(
        cylinderBreathStarts(
          _series(
            3000,
            (t) =>
                t < 900 ? 200 : 200 - loss * (1 - math.exp(-(t - 900) / 240)),
          ),
        ),
        isEmpty,
      );
    });

    test('a turn under about four minutes gives no start', () {
      double turnOf(int t, int minutes) => t < 1200
          ? 200
          : t < 1200 + minutes * 60
          ? 200 - (t - 1200) * _rate
          : 200 - minutes * 60 * _rate;

      expect(cylinderBreathStarts(_series(3000, (t) => turnOf(t, 3))), isEmpty);
      expect(
        cylinderBreathStarts(_series(3000, (t) => turnOf(t, 5))),
        hasLength(1),
      );
    });

    test('a fall hidden in a gap in the readings gives no start', () {
      final readings = [
        for (var t = 0; t < 1200; t += 2) (t: t, bar: 200.0),
        for (var t = 1500; t < 2400; t += 2)
          (t: t, bar: (190 - (t - 1500) * _rate).roundToDouble()),
      ];

      expect(cylinderBreathStarts(readings), isEmpty);
    });

    test('a series ending mid-turn still gives its start', () {
      expect(
        cylinderBreathStarts(
          _series(1200 + 360, (t) => t < 1200 ? 200 : 200 - (t - 1200) * _rate),
        ),
        hasLength(1),
      );
    });

    test('reads the series in time order however it arrives', () {
      final ordered = _series(
        2400,
        (t) => t < 1200 ? 200 : 200 - (t - 1200) * _rate,
      );

      expect(
        cylinderBreathStarts(ordered.reversed.toList()),
        cylinderBreathStarts(ordered),
      );
    });

    test('too few readings give no start', () {
      expect(cylinderBreathStarts(const []), isEmpty);
      expect(cylinderBreathStarts(const [(t: 0, bar: 200.0)]), isEmpty);
    });
  });
}
