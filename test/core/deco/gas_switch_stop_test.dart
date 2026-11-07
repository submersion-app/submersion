import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/core/deco/schedule_policy.dart';

/// Issue #4160: the "Gas switch stop" is held at the depth where the gas is
/// switched, not added to whichever deco stop happens to come next.

/// Air back gas, EAN50 switching at its seawater MOD (21.86 m, which is not
/// on the 3 m stop grid) and O2 at 6 m.
AscentGasPlan _airEan50O2() => OptimalOcAscentGas(
  maxPpO2: 1.6,
  gases: const [
    AvailableGas(fN2: 0.79, fHe: 0.0, maxPpO2Mod: 66.0),
    AvailableGas(fN2: 0.5, fHe: 0.0, maxPpO2Mod: 21.86),
    AvailableGas(fN2: 0.0, fHe: 0.0, maxPpO2Mod: 6.0),
  ],
);

AscentGasPlan _airEan50() => OptimalOcAscentGas(
  maxPpO2: 1.6,
  gases: const [
    AvailableGas(fN2: 0.79, fHe: 0.0, maxPpO2Mod: 66.0),
    AvailableGas(fN2: 0.5, fHe: 0.0, maxPpO2Mod: 21.86),
  ],
);

BuhlmannAlgorithm _dive(double depth, int minutes) {
  final algo = BuhlmannAlgorithm(gfLow: 0.4, gfHigh: 0.8);
  algo.calculateSegment(depthMeters: depth, durationSeconds: minutes * 60);
  return algo;
}

DecoStop? _stopAt(List<DecoStop> stops, double depth) =>
    stops.where((s) => s.depthMeters == depth).firstOrNull;

void main() {
  group('a switch before the first deco stop', () {
    // The issue's plan: 40 m for 12 minutes on air at GF 40/80.
    const switchSeconds = 5 * 60;

    test('gets its own stop at the stop level where the new gas is '
        'breathed', () {
      final stops = _dive(40, 12).calculateDecoSchedule(
        currentDepth: 40,
        ascentGas: _airEan50O2(),
        policy: const SchedulePolicy(gasSwitchStopSeconds: switchSeconds),
      );

      final switchStop = _stopAt(stops, 21);
      expect(switchStop, isNotNull, reason: 'EAN50 is switched to at 21 m');
      expect(switchStop!.durationSeconds, switchSeconds);
      expect(switchStop.isGasSwitchOnly, isTrue);
      expect(switchStop.isDeepStop, isFalse);
    });

    test('does not lengthen any stop where nothing is switched', () {
      // A longer bottom time, so the schedule has deco stops between the two
      // switches as well as at them.
      final baseline = _dive(
        40,
        25,
      ).calculateDecoSchedule(currentDepth: 40, ascentGas: _airEan50O2());
      final unswitched = baseline.where(
        (s) => s.depthMeters != 21 && s.depthMeters != 6,
      );
      expect(unswitched, isNotEmpty, reason: 'precondition');

      final stops = _dive(40, 25).calculateDecoSchedule(
        currentDepth: 40,
        ascentGas: _airEan50O2(),
        policy: const SchedulePolicy(gasSwitchStopSeconds: switchSeconds),
      );
      for (final before in unswitched) {
        final after = _stopAt(stops, before.depthMeters);
        // Time on EAN50 at 21 m can only shorten what is owed further up.
        expect(
          after?.durationSeconds ?? 0,
          lessThanOrEqualTo(before.durationSeconds),
          reason: 'nothing is switched at ${before.depthMeters} m',
        );
        expect(after?.isGasSwitchOnly ?? false, isFalse);
      }
    });

    test('a switch at a deco stop raises that stop to at least the floor, '
        'not on top of it', () {
      final stops = _dive(40, 12).calculateDecoSchedule(
        currentDepth: 40,
        ascentGas: _airEan50O2(),
        policy: const SchedulePolicy(gasSwitchStopSeconds: switchSeconds),
      );
      final o2Stop = _stopAt(stops, 6)!;
      expect(o2Stop.durationSeconds, greaterThanOrEqualTo(switchSeconds));
      expect(o2Stop.durationSeconds, lessThan(2 * switchSeconds));
    });
  });

  group('a dive that owes no decompression', () {
    test('keeps no stops when the switch stop is 0', () {
      expect(
        _dive(
          30,
          10,
        ).calculateDecoSchedule(currentDepth: 30, ascentGas: _airEan50O2()),
        isEmpty,
      );
    });

    test('still holds a stop at every gas switch', () {
      final stops = _dive(30, 10).calculateDecoSchedule(
        currentDepth: 30,
        ascentGas: _airEan50O2(),
        policy: const SchedulePolicy(gasSwitchStopSeconds: 60),
      );
      expect(stops.map((s) => s.depthMeters), [21.0, 6.0]);
      expect(stops.map((s) => s.durationSeconds), [60, 60]);
      expect(stops.every((s) => s.isGasSwitchOnly), isTrue);
    });

    test('holds a switch stop of any number of seconds, unsnapped', () {
      final stops = _dive(30, 10).calculateDecoSchedule(
        currentDepth: 30,
        ascentGas: _airEan50(),
        policy: const SchedulePolicy(
          gasSwitchStopSeconds: 30,
          snapStopsToWholeMinutes: true,
        ),
      );
      expect(stops.single.depthMeters, 21.0);
      expect(stops.single.durationSeconds, 30);
    });

    test('times the ascent at the working rate through the switch stops', () {
      // A switch-only stop is not a deco stop: travel after it must not drop
      // to the slow between-stops or last-stop rates.
      const policy = SchedulePolicy(
        ascentRate: 9,
        intermediateAscentRate: 6,
        shallowAscentRate: 3,
        finalAscentRate: 1,
        gasSwitchStopSeconds: 60,
      );
      final tts = _dive(30, 10).calculateTts(
        currentDepth: 30,
        ascentGas: _airEan50O2(),
        policy: policy,
      );
      // 30 m at 9 m/min is 200 s, plus two one-minute switch stops.
      expect(tts, 200 + 120);
    });
  });

  test('a dive that only just has a ceiling gets no stop for a switch made '
      'deeper', () {
    // The shortest air bottom time at 30 m that owes a stop.
    var minutes = 1;
    while (_dive(30, minutes).calculateCeiling() <= 0) {
      minutes++;
    }
    const switchSeconds = 5 * 60;
    final stops = _dive(30, minutes).calculateDecoSchedule(
      currentDepth: 30,
      ascentGas: _airEan50(),
      policy: const SchedulePolicy(gasSwitchStopSeconds: switchSeconds),
    );
    expect(_stopAt(stops, 21)?.durationSeconds, switchSeconds);
    for (final stop in stops.where((s) => s.depthMeters != 21)) {
      expect(
        stop.durationSeconds,
        lessThan(switchSeconds),
        reason: 'nothing is switched at ${stop.depthMeters} m',
      );
      expect(stop.isGasSwitchOnly, isFalse);
    }
  });

  group('SchedulePolicy.ascentLegs', () {
    const policy = SchedulePolicy(
      ascentRate: 9,
      intermediateAscentRate: 6,
      shallowAscentRate: 3,
      finalAscentRate: 1,
    );

    test('stays on the working ascent past a switch-only stop', () {
      final legs = policy.ascentLegs(
        fromDepth: 30,
        stopDepths: const [21],
        gasSwitchOnlyDepths: {21.0},
      );
      expect(legs.map((l) => l.seconds), [60, 140]);
    });

    test('a switch-only stop before the first deco stop leaves the next leg '
        'on the working ascent', () {
      final legs = policy.ascentLegs(
        fromDepth: 39,
        stopDepths: const [21, 12, 3],
        gasSwitchOnlyDepths: {21.0},
      );
      // 39 to 21 and 21 to 12 at 9 m/min, 12 to 3 at 6 m/min, 3 to 0 at 1.
      expect(legs.map((l) => l.seconds), [120, 60, 90, 180]);
    });
  });

  group('AscentPhase.afterStop', () {
    test('moves to the between-stops phase after a deco stop', () {
      expect(AscentPhase.toFirstStop.afterStop(), AscentPhase.betweenStops);
    });

    test('keeps the phase after a switch-only stop', () {
      expect(
        AscentPhase.toFirstStop.afterStop(gasSwitchOnly: true),
        AscentPhase.toFirstStop,
      );
      expect(
        AscentPhase.betweenStops.afterStop(gasSwitchOnly: true),
        AscentPhase.betweenStops,
      );
    });
  });
}
