import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/core/deco/entities/breathing_config.dart';
import 'package:submersion/core/deco/schedule_policy.dart';
import 'package:submersion/core/deco/vpm_b.dart';
import 'package:submersion/core/deco/vpm_b_algorithm.dart';

/// Validates the VpmB DecoModel wrapper: that its restore/step/capture bridge
/// reproduces the golden-validated whole-dive algorithm, and that it satisfies
/// the DecoModel contract (surface state, ceiling, NDL, schedule).
void main() {
  const air = VpmGasMix(fN2: 0.79, fHe: 0.0);

  List<List<int>> pairs(List<VpmStop> stops) => [
    for (final s in stops) [s.depth, s.time],
  ];

  group('VpmBAlgorithm incremental API', () {
    test(
      'applyDepthChange + applyConstantDepth + runAscent == computeDive',
      () {
        final settings = VpmBSettings.forConservatism(3);

        // Whole-dive reference path (this is the golden-validated one).
        final whole = VpmBAlgorithm(settings).computeDive(
          gasMixes: [air],
          profile: [
            const VpmDepthChangeSegment(
              startingDepth: 0,
              endingDepth: 50,
              rate: 18,
              mixNumber: 1,
            ),
            const VpmConstantSegment(
              depth: 50,
              runTimeAtEndOfSegment: 25,
              mixNumber: 1,
            ),
          ],
          ascentChanges: [
            const VpmAscentChange(
              startingDepth: 50,
              mixNumber: 1,
              rate: -10,
              stepSize: 3,
            ),
          ],
        );

        // Incremental path with a full capture -> restore round trip between
        // every step, exactly as the DecoModel wrapper drives it.
        final algo = VpmBAlgorithm(settings);
        algo.initializeToSurface();

        var he = List<double>.of(algo.heliumPressure);
        var n2 = List<double>.of(algo.nitrogenPressure);
        var che = List<double>.of(algo.maxCrushingPressureHe);
        var cn2 = List<double>.of(algo.maxCrushingPressureN2);
        var rt = algo.runTime;

        void restore() => algo.loadState(
          heliumPressure: he,
          nitrogenPressure: n2,
          maxCrushingPressureHe: che,
          maxCrushingPressureN2: cn2,
          runTime: rt,
        );
        void capture() {
          he = List<double>.of(algo.heliumPressure);
          n2 = List<double>.of(algo.nitrogenPressure);
          che = List<double>.of(algo.maxCrushingPressureHe);
          cn2 = List<double>.of(algo.maxCrushingPressureN2);
          rt = algo.runTime;
        }

        restore();
        algo.applyDepthChange(0, 50, 18, air);
        capture();

        restore();
        algo.applyConstantDepth(50, 25, air);
        capture();

        restore();
        final incremental = algo.runAscent(
          [air],
          [
            const VpmAscentChange(
              startingDepth: 50,
              mixNumber: 1,
              rate: -10,
              stepSize: 3,
            ),
          ],
        );

        expect(pairs(incremental), equals(pairs(whole)));
      },
    );
  });

  group('VpmB DecoModel wrapper', () {
    // A descent whose integer-second duration yields an exact rate (3000/180 =
    // 16.667 msw/min), so the wrapper (which derives rate from duration) can be
    // checked bit-for-bit against the algorithm fed that same rate.
    const descentSeconds = 180; // 0 -> 50 m
    const bottomSeconds = 1320; // 22 min at 50 m -> runtime 25 min
    const derivedRate = 50 / (descentSeconds / 60.0);

    DecoSchedule wrapperSchedule(int conservatism) {
      final model = VpmB(
        conservatism: conservatism,
        policy: const SchedulePolicy(ascentRate: 10.0, stopIncrement: 3.0),
      );
      var state = model.initial();
      state = model.applySegment(
        state,
        const DecoSegment(
          startDepth: 0,
          endDepth: 50,
          durationSeconds: descentSeconds,
        ),
        const OpenCircuit(fO2: 0.21),
      );
      state = model.applySegment(
        state,
        const DecoSegment(
          startDepth: 50,
          endDepth: 50,
          durationSeconds: bottomSeconds,
        ),
        const OpenCircuit(fO2: 0.21),
      );
      return model.schedule(
        state,
        currentDepth: 50,
        gases: FixedAscentGas(fN2: 0.79),
      );
    }

    List<VpmStop> algorithmSchedule(int conservatism) {
      return VpmBAlgorithm(
        VpmBSettings.forConservatism(conservatism),
      ).computeDive(
        gasMixes: [air],
        profile: [
          const VpmDepthChangeSegment(
            startingDepth: 0,
            endingDepth: 50,
            rate: derivedRate,
            mixNumber: 1,
          ),
          const VpmConstantSegment(
            depth: 50,
            runTimeAtEndOfSegment: 25,
            mixNumber: 1,
          ),
        ],
        ascentChanges: [
          const VpmAscentChange(
            startingDepth: 50,
            mixNumber: 1,
            rate: -10,
            stepSize: 3,
          ),
        ],
      );
    }

    test('schedule() matches the algorithm fed the wrapper-derived rate', () {
      final sched = wrapperSchedule(3);
      final expected = algorithmSchedule(3);

      final actual = [
        for (final s in sched.stops)
          [s.depthMeters.toInt(), s.durationSeconds ~/ 60],
      ];
      expect(actual, equals(pairs(expected)));
      expect(sched.stops, isNotEmpty);
      expect(sched.ttsSeconds, greaterThan(0));
    });

    test('deeper conservatism yields more total stop time', () {
      final light = wrapperSchedule(0);
      final heavy = wrapperSchedule(4);
      final lightTotal = light.stops.fold<int>(
        0,
        (a, s) => a + s.durationSeconds,
      );
      final heavyTotal = heavy.stops.fold<int>(
        0,
        (a, s) => a + s.durationSeconds,
      );
      expect(heavyTotal, greaterThan(lightTotal));
    });

    test('initial() is surface-equilibrated: no ceiling, no obligation', () {
      final model = VpmB();
      final state = model.initial();
      expect(model.ceilingMeters(state), 0.0);
      expect(
        model.ndlSeconds(
          state,
          depthMeters: 0,
          breathing: const OpenCircuit(fO2: 0.21),
        ),
        greaterThan(0),
      );
    });

    test('a short shallow dive stays within NDL (no deco stops)', () {
      final model = VpmB(
        policy: const SchedulePolicy(ascentRate: 10.0, stopIncrement: 3.0),
      );
      var state = model.initial();
      state = model.applySegment(
        state,
        const DecoSegment(startDepth: 0, endDepth: 18, durationSeconds: 120),
        const OpenCircuit(fO2: 0.21),
      );
      state = model.applySegment(
        state,
        const DecoSegment(
          startDepth: 18,
          endDepth: 18,
          durationSeconds: 20 * 60,
        ),
        const OpenCircuit(fO2: 0.21),
      );
      final sched = model.schedule(
        state,
        currentDepth: 18,
        gases: FixedAscentGas(fN2: 0.79),
      );
      expect(sched.stops, isEmpty);
    });

    test('ndlSeconds returns -1 once a deco obligation exists', () {
      final model = VpmB(
        conservatism: 3,
        policy: const SchedulePolicy(ascentRate: 10.0, stopIncrement: 3.0),
      );
      var state = model.initial();
      state = model.applySegment(
        state,
        const DecoSegment(startDepth: 0, endDepth: 40, durationSeconds: 133),
        const OpenCircuit(fO2: 0.21),
      );
      state = model.applySegment(
        state,
        const DecoSegment(
          startDepth: 40,
          endDepth: 40,
          durationSeconds: 40 * 60,
        ),
        const OpenCircuit(fO2: 0.21),
      );
      final ndl = model.ndlSeconds(
        state,
        depthMeters: 40,
        breathing: const OpenCircuit(fO2: 0.21),
      );
      expect(ndl, -1);
    });
  });
}
