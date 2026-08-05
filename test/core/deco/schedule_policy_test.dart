import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
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

  group('ascent-rate bands and descent rate', () {
    test('null bands: ascentRateForDepth always returns the single rate', () {
      const policy = SchedulePolicy(ascentRate: 9);
      expect(policy.ascentRateForDepth(35, 40), 9);
      expect(policy.ascentRateForDepth(3, 40), 9);
    });

    test('four bands select by fraction of mean depth then last 6m', () {
      const policy = SchedulePolicy(
        ascentRate: 9,
        ascentRateBands: [6, 7, 8, 3],
      );
      // Mean depth 40 m: 75% = 30 m, 50% = 20 m.
      expect(policy.ascentRateForDepth(35, 40), 6); // below 75% mean
      expect(policy.ascentRateForDepth(25, 40), 7); // 75%-50%
      expect(policy.ascentRateForDepth(10, 40), 8); // 50%-to-6m
      expect(policy.ascentRateForDepth(4, 40), 3); // last 6 m
    });

    test('descent rate defaults to 18 and is configurable', () {
      expect(const SchedulePolicy().descentRate, 18);
      expect(const SchedulePolicy(descentRate: 24).descentRate, 24);
    });
  });
}
