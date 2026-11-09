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

  // Issue #165: a cylinder that starts again was left for another one when
  // its breathing before stopped.
  group('cylinderBreathTurns', () {
    test('a first start after a hold has no earlier breathing', () {
      final turns = cylinderBreathTurns(
        _series(2400, (t) => t < 1200 ? 200 : 200 - (t - 1200) * _rate),
      ).starts;

      expect(turns.single.previousEnd, isNull);
    });

    test('each later turn ends where the one before stopped', () {
      final turns = cylinderBreathTurns(
        _series(
          480 + 960 * 3,
          _turns(lead: 480, turn: 480, rest: 480, count: 3),
        ),
      ).starts;

      expect(turns, hasLength(3));
      expect(turns[0].previousEnd, isNull);
      // The first turn stops at 960 and the second at 1920.
      expect(turns[1].previousEnd, inInclusiveRange(930, 962));
      expect(turns[2].previousEnd, inInclusiveRange(1890, 1922));
    });

    test('breathing from the first reading counts as earlier breathing', () {
      // The dive began on this cylinder: breathed to 10:00, then held.
      final turns = cylinderBreathTurns(
        _series(3000, (t) {
          if (t <= 600) return 200 - t * _rate;
          if (t <= 1500) return 200 - 600 * _rate;
          return 200 - 600 * _rate - (t - 1500) * _rate;
        }),
      ).starts;

      expect(turns.single.t, inInclusiveRange(1502, 1530));
      expect(turns.single.previousEnd, inInclusiveRange(570, 602));
    });

    test('a cylinder breathed from its first reading is from the start', () {
      // The cylinder a sidemount dive began on (issue #4335).
      final turns = cylinderBreathTurns(
        _series(3000, (t) {
          if (t <= 900) return 200 - t * _rate;
          return 200 - 900 * _rate;
        }),
      );

      expect(turns.fromStart, isTrue);
      expect(turns.starts, isEmpty);
    });

    test('a cylinder held at first is not from the start', () {
      final turns = cylinderBreathTurns(
        _series(3000, (t) => t < 900 ? 200 : 200 - (t - 900) * _rate),
      );

      expect(turns.fromStart, isFalse);
      expect(turns.starts, hasLength(1));
    });

    test('a hose filling at the start is not breathing from the start', () {
      // Opening the valve drops the reading 3 bar, then it holds.
      final turns = cylinderBreathTurns(
        _series(3000, (t) => t < 20 ? 200 : 197),
      );

      expect(turns.fromStart, isFalse);
    });

    test('a 565 bar first reading does not hide the start', () {
      final series = _series(3000, (t) {
        if (t <= 900) return 200 - t * _rate;
        return 200 - 900 * _rate;
      });
      final turns = cylinderBreathTurns([
        (t: 0, bar: 564.7),
        ...series.skip(1),
      ]);

      expect(turns.fromStart, isTrue);
    });

    test('a dip between turns is not breathing', () {
      final turns = cylinderBreathTurns(
        _series(3000, (t) {
          final base = _turns(lead: 480, turn: 480, rest: 1200, count: 2)(t);
          // A hose filling at 20:00 that recovers.
          return t > 1200 && t < 1240 ? base - 8 : base;
        }),
      ).starts;

      expect(turns, hasLength(2));
      expect(turns[1].previousEnd, inInclusiveRange(930, 962));
    });

    test('a cylinder left for good is held from where it stopped', () {
      // Breathed from 20:00 to 30:00, then held to the end of the readings.
      final turns = cylinderBreathTurns(
        _series(3000, (t) {
          if (t <= 1200) return 200;
          if (t <= 1800) return 200 - (t - 1200) * _rate;
          return 200 - 600 * _rate;
        }),
      );

      expect(turns.starts, hasLength(1));
      expect(turns.heldFrom, inInclusiveRange(1770, 1802));
    });

    test('one breathed from its first reading and left is held too', () {
      final turns = cylinderBreathTurns(
        _series(3000, (t) => t <= 600 ? 200 - t * _rate : 200 - 600 * _rate),
      );

      expect(turns.starts, isEmpty);
      expect(turns.heldFrom, inInclusiveRange(570, 602));
    });

    test('one breathed to the end of its readings is not held', () {
      expect(
        cylinderBreathTurns(
          _series(2400, (t) => t < 1200 ? 200 : 200 - (t - 1200) * _rate),
        ).heldFrom,
        isNull,
      );
    });

    test('a hold too short to judge is not held', () {
      // Breathing stops 60 s before the readings do.
      expect(
        cylinderBreathTurns(
          _series(1860, (t) {
            if (t <= 1200) return 200;
            if (t <= 1800) return 200 - (t - 1200) * _rate;
            return 200 - 600 * _rate;
          }),
        ).heldFrom,
        isNull,
      );
    });

    test('its starts are the ones cylinderBreathStarts gives', () {
      final readings = _series(
        480 + 960 * 3,
        _turns(lead: 480, turn: 480, rest: 480, count: 3),
      );

      expect([
        for (final turn in cylinderBreathTurns(readings).starts) turn.t,
      ], cylinderBreathStarts(readings));
    });
  });

  group('cylinderBreathedFromStart', () {
    // Breathed from the first reading to 15:00, then held.
    final falling = _series(
      2400,
      (t) => t <= 900 ? 200 - t * _rate : 200 - 900 * _rate,
    );
    // Held to 15:00, then breathed.
    final held = _series(2400, (t) => t < 900 ? 200 : 200 - (t - 900) * _rate);

    String? startOf(
      Map<String, List<PressureReading>> readingsById, {
      List<String> ids = const ['a', 'b'],
    }) => cylinderBreathedFromStart(
      cylinderIds: ids,
      readingsById: readingsById,
      turnsById: {
        for (final MapEntry(:key, :value) in readingsById.entries)
          key: cylinderBreathTurns(value),
      },
      diveStart: 0,
    );

    test('names the one cylinder breathed from the start', () {
      expect(startOf({'a': held, 'b': falling}), 'b');
    });

    test('two cylinders both falling from the start name none', () {
      expect(startOf({'a': falling, 'b': falling}), isNull);
    });

    test('a transmitter that paired late says nothing about the start', () {
      final late = [for (final r in falling) (t: r.t + 600, bar: r.bar)];
      expect(startOf({'b': late}), isNull);
    });

    test('a lone cylinder held at the start puts the diver on the other', () {
      expect(startOf({'a': held}), 'b');
    });

    test('with three cylinders a lone held one names none', () {
      expect(startOf({'a': held}, ids: const ['a', 'b', 'c']), isNull);
    });

    test('both held at the start name none', () {
      expect(startOf({'a': held, 'b': held}), isNull);
    });
  });
}
