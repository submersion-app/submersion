import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/core/deco/schedule_policy.dart';

/// Loads a deco-obligated dive: air, 45 m for 25 min.
BuhlmannAlgorithm _loadedAlgo() {
  final algo = BuhlmannAlgorithm(gfLow: 0.4, gfHigh: 0.8);
  algo.calculateSegment(depthMeters: 45, durationSeconds: 25 * 60);
  return algo;
}

AscentGasPlan _airPlusO2() => OptimalOcAscentGas(
  maxPpO2: 1.6,
  gases: const [
    AvailableGas(fN2: 0.7902, fHe: 0.0, maxPpO2Mod: 66.0),
    AvailableGas(fN2: 0.0, fHe: 0.0, maxPpO2Mod: 6.0), // pure O2
  ],
);

void main() {
  group('AscentPhase.surfacingAfter', () {
    test('is the working ascent when no stop was ever held', () {
      // A dive that owes nothing never leaves the leg it started on, so the
      // slow final rate - which describes crawling off a last stop - must not
      // apply to it.
      expect(
        AscentPhase.surfacingAfter(AscentPhase.toFirstStop),
        AscentPhase.toFirstStop,
      );
    });

    test('is the final stretch once the stop walk has begun', () {
      expect(
        AscentPhase.surfacingAfter(AscentPhase.betweenStops),
        AscentPhase.fromLastStop,
      );
    });
  });

  test('null policy reproduces legacy schedule exactly', () {
    final a = _loadedAlgo();
    final b = _loadedAlgo();
    final legacy = a.calculateDecoSchedule(currentDepth: 45);
    final viaPolicy = b.calculateDecoSchedule(
      currentDepth: 45,
      policy: const SchedulePolicy(),
    );
    expect(viaPolicy.length, legacy.length);
    for (int i = 0; i < legacy.length; i++) {
      expect(viaPolicy[i].depthMeters, legacy[i].depthMeters);
      expect(viaPolicy[i].durationSeconds, legacy[i].durationSeconds);
    }
  });

  group('snapStopsToWholeMinutes', () {
    // Seconds on the ascent clock at which each stop ends, timing the legs
    // the way calculateTts does: unsplit, one rounding per leg.
    List<int> stopEnds(List<DecoStop> stops, SchedulePolicy p, double from) {
      final ends = <int>[];
      var elapsed = 0;
      var depth = from;
      var phase = AscentPhase.toFirstStop;
      for (final s in stops) {
        elapsed += p.ascentSeconds(
          fromDepth: depth,
          toDepth: s.depthMeters,
          phase: phase,
        );
        elapsed += s.durationSeconds;
        ends.add(elapsed);
        depth = s.depthMeters;
        phase = AscentPhase.betweenStops;
      }
      return ends;
    }

    test('off by default: stops keep their exact clearance times', () {
      final stops = _loadedAlgo().calculateDecoSchedule(currentDepth: 45);
      // 45 m at 9 m/min to the first stop is not a whole number of minutes,
      // so an unsnapped schedule's stops end at odd seconds.
      expect(stops, isNotEmpty);
      expect(
        stopEnds(stops, const SchedulePolicy(), 45).any((e) => e % 60 != 0),
        isTrue,
      );
    });

    test('on: every stop ends on a whole minute of the ascent clock', () {
      const p = SchedulePolicy(
        intermediateAscentRate: 6,
        shallowAscentRate: 3,
        finalAscentRate: 1,
        snapStopsToWholeMinutes: true,
      );
      final stops = _loadedAlgo().calculateDecoSchedule(
        currentDepth: 45,
        policy: p,
      );
      expect(stops, isNotEmpty);
      for (final end in stopEnds(stops, p, 45)) {
        expect(end % 60, 0, reason: 'a stop ended at $end s');
      }
    });

    test('snapping only ever lengthens a stop, by under a minute', () {
      const off = SchedulePolicy(
        intermediateAscentRate: 6,
        shallowAscentRate: 3,
        finalAscentRate: 1,
      );
      const on = SchedulePolicy(
        intermediateAscentRate: 6,
        shallowAscentRate: 3,
        finalAscentRate: 1,
        snapStopsToWholeMinutes: true,
      );
      final exact = _loadedAlgo().calculateDecoSchedule(
        currentDepth: 45,
        policy: off,
      );
      final snapped = _loadedAlgo().calculateDecoSchedule(
        currentDepth: 45,
        policy: on,
      );
      // Extra seconds at a deeper stop off-gas the tissues a little more, so
      // a later stop may clear a minute sooner; compare where the depths
      // still line up and check the total never shrinks.
      expect(
        snapped.map((s) => s.depthMeters),
        exact.map((s) => s.depthMeters),
      );
      var totalExact = 0;
      var totalSnapped = 0;
      for (var i = 0; i < exact.length; i++) {
        totalExact += exact[i].durationSeconds;
        totalSnapped += snapped[i].durationSeconds;
      }
      expect(totalSnapped, greaterThanOrEqualTo(totalExact));
      expect(totalSnapped - totalExact, lessThan(60 * exact.length));
    });
  });

  group('last stop off the grid', () {
    test('a 4 m last stop follows the 3 m grid down to 6 m, then 4 m', () {
      final stops = _loadedAlgo().calculateDecoSchedule(
        currentDepth: 45,
        policy: const SchedulePolicy(lastStopDepth: 4.0),
      );
      expect(stops.last.depthMeters, 4.0);
      expect(stops.every((s) => s.depthMeters >= 4.0), isTrue);
      final deeper = stops.where((s) => s.depthMeters > 4.0);
      expect(deeper.every((s) => s.depthMeters % 3 == 0), isTrue);
      expect(deeper.any((s) => s.depthMeters == 6.0), isTrue);
    });

    test('a 5 m last stop lands on 5 m, never 3 m', () {
      final stops = _loadedAlgo().calculateDecoSchedule(
        currentDepth: 45,
        policy: const SchedulePolicy(lastStopDepth: 5.0),
      );
      expect(stops.last.depthMeters, 5.0);
      expect(stops.any((s) => s.depthMeters == 3.0), isFalse);
    });

    test('a ceiling shallower than the last stop still stops there', () {
      // Air, 21 m for 30 min: a ceiling around 5.5 m, shallower than a 6 m
      // last stop. Asserted rather than assumed, because the case only exists
      // while the ceiling stays between the grid's 3 m level and 6 m.
      final algo = BuhlmannAlgorithm(gfLow: 0.4, gfHigh: 0.8);
      algo.calculateSegment(depthMeters: 21, durationSeconds: 30 * 60);
      expect(algo.calculateCeiling(), greaterThan(3));
      expect(algo.calculateCeiling(), lessThan(6));

      // On the 3 m grid that diver holds at 3 m. Asked to finish at 6 m they
      // hold at 6 m instead - not nothing, because the level the grid would
      // otherwise give them is below where they chose to stop.
      expect(
        algo.calculateDecoSchedule(currentDepth: 21).single.depthMeters,
        3.0,
      );
      final stops = algo.calculateDecoSchedule(
        currentDepth: 21,
        policy: const SchedulePolicy(lastStopDepth: 6.0),
      );
      expect(stops.single.depthMeters, 6.0);
    });
  });

  test('last stop at 6 m removes the 3 m stop', () {
    final algo = _loadedAlgo();
    final stops = algo.calculateDecoSchedule(
      currentDepth: 45,
      policy: const SchedulePolicy(lastStopDepth: 6.0),
    );
    expect(stops.every((s) => s.depthMeters >= 6.0), isTrue);
    expect(stops.last.depthMeters, 6.0);
  });

  test('gas-switch stop time enforces a minimum stop at the switch', () {
    final algo = _loadedAlgo();
    final plan = _airPlusO2();
    final stops = algo.calculateDecoSchedule(
      currentDepth: 45,
      ascentGas: plan,
      policy: const SchedulePolicy(gasSwitchStopSeconds: 120),
    );
    // The first stop at or above 6 m (the O2 switch) lasts >= 120 s.
    final switchStop = stops.firstWhere((s) => s.depthMeters <= 6.0);
    expect(switchStop.durationSeconds, greaterThanOrEqualTo(120));
  });

  test('air breaks lengthen O2 stops and are annotated', () {
    int totalDeco(SchedulePolicy policy) {
      final algo = BuhlmannAlgorithm(gfLow: 0.4, gfHigh: 0.8);
      algo.calculateSegment(depthMeters: 45, durationSeconds: 45 * 60);
      final stops = algo.calculateDecoSchedule(
        currentDepth: 45,
        ascentGas: _airPlusO2(),
        policy: policy,
      );
      return stops.fold(0, (sum, s) => sum + s.durationSeconds);
    }

    const withBreaks = SchedulePolicy(
      airBreaks: AirBreakPolicy(o2Seconds: 12 * 60, breakSeconds: 6 * 60),
    );
    final baseline = totalDeco(const SchedulePolicy());
    final broken = totalDeco(withBreaks);
    // Breathing back gas during breaks off-gasses slower -> longer deco.
    expect(broken, greaterThan(baseline));

    final algo = BuhlmannAlgorithm(gfLow: 0.4, gfHigh: 0.8);
    algo.calculateSegment(depthMeters: 45, durationSeconds: 45 * 60);
    final stops = algo.calculateDecoSchedule(
      currentDepth: 45,
      ascentGas: _airPlusO2(),
      policy: withBreaks,
    );
    // Breaks land on whichever O2 stop exceeds the 12-min threshold
    // (typically the long 3 m stop, not the short 6 m one).
    final o2Stops = stops.where((s) => s.depthMeters <= 6.0).toList();
    final totalBreaks = o2Stops.fold<int>(
      0,
      (sum, s) => sum + s.airBreakSeconds,
    );
    expect(totalBreaks, greaterThan(0));
    final annotated = o2Stops.firstWhere((s) => s.airBreakSeconds > 0);
    expect(annotated.airBreakSeconds, lessThan(annotated.durationSeconds));
  });

  test('air-break annotation reflects a gas-switch-extended O2 stop', () {
    // A large gas-switch minimum forces the O2 switch stop far past its natural
    // clearance. airBreakSeconds must be computed over that final, extended
    // duration -- not the shorter pre-extension search result -- so breaks that
    // fall inside the extension are counted.
    const o2Seconds = 12 * 60;
    const breakSeconds = 6 * 60;
    const gasSwitchStopSeconds = 30 * 60;
    const policy = SchedulePolicy(
      gasSwitchStopSeconds: gasSwitchStopSeconds,
      airBreaks: AirBreakPolicy(
        o2Seconds: o2Seconds,
        breakSeconds: breakSeconds,
      ),
    );
    final stops = _loadedAlgo().calculateDecoSchedule(
      currentDepth: 45,
      ascentGas: _airPlusO2(),
      policy: policy,
    );

    // The 6 m O2 switch stop is the deepest stop at or above 6 m.
    final switchStop = stops.firstWhere((s) => s.depthMeters <= 6.0);
    expect(
      switchStop.durationSeconds,
      greaterThanOrEqualTo(gasSwitchStopSeconds),
      reason: 'gas-switch minimum should extend the O2 stop',
    );

    // Independently walk the air-break cycle over the FINAL duration; each whole
    // minute (and any sub-minute remainder) is O2 for the first o2Seconds of the
    // cycle, then break gas.
    int expectedBreakSeconds(int stopSeconds) {
      const cycle = o2Seconds + breakSeconds;
      var total = 0;
      for (var t = 0; t < stopSeconds; t += 60) {
        final chunk = (stopSeconds - t) < 60 ? stopSeconds - t : 60;
        if (t % cycle >= o2Seconds) total += chunk;
      }
      return total;
    }

    expect(switchStop.airBreakSeconds, greaterThan(0));
    expect(
      switchStop.airBreakSeconds,
      expectedBreakSeconds(switchStop.durationSeconds),
    );
  });

  test('breakGasForDepth: OptimalOcAscentGas offers a non-O2 gas', () {
    final plan = _airPlusO2();
    final atSix = plan.breakGasForDepth(6.0);
    expect(atSix, isNotNull);
    expect(atSix!.fN2, closeTo(0.7902, 1e-9));
    // FixedAscentGas has no alternative gas.
    expect(FixedAscentGas(fN2: 0.7902).breakGasForDepth(6.0), isNull);
  });

  group('ascent rates', () {
    // Four rates, per TDI's decompression procedures. They are named after
    // the PHASE of the ascent, not a depth: the leg off the bottom is a
    // working ascent whether the first stop is at 21 m or 6 m, and a dive
    // that owes nothing ascends at that one rate the whole way. Only travel
    // between stops needs a depth, to tell intermediate from shallow.
    const tdi = SchedulePolicy(
      ascentRate: 9,
      intermediateAscentRate: 6,
      shallowAscentRate: 3,
      finalAscentRate: 1,
    );

    test('the deco rates all default to the single ascent rate', () {
      // Everything that is not the planner passes only ascentRate, and must
      // keep behaving as though there were one rate, in every phase.
      const flat = SchedulePolicy(ascentRate: 9);
      expect(flat.intermediateAscentRate, 9);
      expect(flat.shallowAscentRate, 9);
      expect(flat.finalAscentRate, 9);
      for (final phase in AscentPhase.values) {
        expect(
          flat.ascentSeconds(fromDepth: 30, toDepth: 0, phase: phase),
          200,
          reason: phase.name,
        );
      }
    });

    test('bottom to the first stop uses the working rate at any depth', () {
      // 29 m at 9 m/min.
      expect(tdi.ascentSeconds(fromDepth: 50, toDepth: 21), 193);
      // Still the working rate even though this leg ends shallower than the
      // shallow-stop boundary: it is the phase that picks the rate, and a
      // diver leaving the bottom for a 6 m first stop is leaving the bottom.
      expect(tdi.ascentSeconds(fromDepth: 30, toDepth: 6), 160);
    });

    test('a dive that owes nothing ascends at the working rate throughout', () {
      // The whole point of phases over depth bands: none of the slower deco
      // rates apply to a no-deco ascent, so 18 m takes 2 min, not 6.
      expect(tdi.ascentSeconds(fromDepth: 18, toDepth: 0), 120);
      expect(tdi.ascentTravelSeconds(fromDepth: 18, stopDepths: const []), 120);
    });

    test('between intermediate stops uses the intermediate rate', () {
      // Deeper than 9 m: 3 m at 6 m/min = 30 s.
      const phase = AscentPhase.betweenStops;
      expect(tdi.ascentSeconds(fromDepth: 21, toDepth: 18, phase: phase), 30);
      expect(tdi.ascentSeconds(fromDepth: 12, toDepth: 9, phase: phase), 30);
    });

    test('between shallow stops uses the shallow rate', () {
      // At or above 9 m: 3 m at 3 m/min = 60 s.
      const phase = AscentPhase.betweenStops;
      expect(tdi.ascentSeconds(fromDepth: 9, toDepth: 6, phase: phase), 60);
      expect(tdi.ascentSeconds(fromDepth: 6, toDepth: 3, phase: phase), 60);
    });

    test('the last stop to the surface crawls', () {
      expect(
        tdi.ascentSeconds(
          fromDepth: 3,
          toDepth: 0,
          phase: AscentPhase.fromLastStop,
        ),
        180,
      );
      // A 6 m last stop crawls the whole 6 m.
      expect(
        tdi.ascentSeconds(
          fromDepth: 6,
          toDepth: 0,
          phase: AscentPhase.fromLastStop,
        ),
        360,
      );
    });

    test('ascentRateFor names the rate for each phase', () {
      expect(tdi.ascentRateFor(AscentPhase.toFirstStop, fromDepth: 50), 9);
      expect(tdi.ascentRateFor(AscentPhase.betweenStops, fromDepth: 12), 6);
      expect(tdi.ascentRateFor(AscentPhase.betweenStops, fromDepth: 9), 3);
      expect(tdi.ascentRateFor(AscentPhase.fromLastStop, fromDepth: 3), 1);
    });

    test('a whole deco ascent totals the same as its legs', () {
      // ascentTravelSeconds is the total the schedule reports; it must not be
      // able to disagree with the per-leg numbers the profile is built from.
      const stops = [21.0, 18.0, 15.0, 12.0, 9.0, 6.0, 3.0];
      var byLeg = tdi.ascentSeconds(fromDepth: 50, toDepth: stops.first);
      for (var i = 1; i < stops.length; i++) {
        byLeg += tdi.ascentSeconds(
          fromDepth: stops[i - 1],
          toDepth: stops[i],
          phase: AscentPhase.betweenStops,
        );
      }
      byLeg += tdi.ascentSeconds(
        fromDepth: stops.last,
        toDepth: 0,
        phase: AscentPhase.fromLastStop,
      );

      expect(tdi.ascentTravelSeconds(fromDepth: 50, stopDepths: stops), byLeg);
      // 29 m at 9, four intermediate legs at 6, two shallow at 3, then the
      // crawl off the 3 m stop: 193 + 4x30 + 2x60 + 180.
      expect(byLeg, 193 + 120 + 120 + 180);
    });

    test('a descending or zero-length leg takes no time', () {
      expect(tdi.ascentSeconds(fromDepth: 10, toDepth: 10), 0);
      expect(tdi.ascentSeconds(fromDepth: 10, toDepth: 20), 0);
    });

    test('descent rate defaults to 18 and is configurable', () {
      expect(const SchedulePolicy().descentRate, 18);
      expect(const SchedulePolicy(descentRate: 24).descentRate, 24);
    });
  });
}
