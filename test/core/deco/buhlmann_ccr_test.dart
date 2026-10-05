import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/ascent/ccr_loop_ascent_gas.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/entities/breathing_config.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';

void main() {
  group('CCR tissue loading', () {
    test('CCR at setpoint loads less inert gas than OC diluent at 40 m', () {
      final oc = BuhlmannAlgorithm(gfLow: 0.5, gfHigh: 0.8);
      final ccr = BuhlmannAlgorithm(gfLow: 0.5, gfHigh: 0.8);

      oc.calculateSegment(
        depthMeters: 40,
        durationSeconds: 20 * 60,
        fN2: 0.37,
        fHe: 0.45,
      );
      ccr.calculateSegment(
        depthMeters: 40,
        durationSeconds: 20 * 60,
        breathing: const ClosedCircuit(
          setpoint: 1.3,
          diluentFO2: 0.18,
          diluentFHe: 0.45,
        ),
      );

      final ocInert = oc.compartments
          .map((c) => c.totalInertGas)
          .reduce((a, b) => a + b);
      final ccrInert = ccr.compartments
          .map((c) => c.totalInertGas)
          .reduce((a, b) => a + b);
      expect(ccrInert, lessThan(ocInert));
    });

    test('CCR NDL at setpoint is longer than OC NDL on the diluent', () {
      final algo = BuhlmannAlgorithm(gfLow: 0.5, gfHigh: 0.8);
      final ndlOc = algo.calculateNdl(depthMeters: 30, fN2: 0.7902, fHe: 0.0);
      final ndlCcr = algo.calculateNdl(
        depthMeters: 30,
        breathing: const ClosedCircuit(setpoint: 1.3, diluentFO2: 0.21),
      );
      expect(ndlCcr, greaterThan(ndlOc));
    });

    test('breathing parameter takes precedence over fN2/fHe', () {
      final a = BuhlmannAlgorithm();
      final b = BuhlmannAlgorithm();
      a.calculateSegment(
        depthMeters: 30,
        durationSeconds: 600,
        fN2: 0.5,
        fHe: 0.4,
        breathing: const OpenCircuit(fO2: 0.2098),
      );
      b.calculateSegment(
        depthMeters: 30,
        durationSeconds: 600,
        fN2: 0.7902,
        fHe: 0.0,
      );
      expect(a.compartments, b.compartments);
    });

    test('processProfileWithGasSegments honors segment setpoints', () {
      final depths = [0.0, 30.0, 30.0, 30.0, 0.0];
      final times = [0, 120, 600, 1200, 1500];

      final ocStatuses = BuhlmannAlgorithm(gfLow: 0.5, gfHigh: 0.8)
          .processProfileWithGasSegments(
            depths: depths,
            timestamps: times,
            gasSegments: [
              const ProfileGasSegment(startTimestamp: 0, fN2: 0.7902),
            ],
          );
      final ccrStatuses = BuhlmannAlgorithm(gfLow: 0.5, gfHigh: 0.8)
          .processProfileWithGasSegments(
            depths: depths,
            timestamps: times,
            gasSegments: [
              const ProfileGasSegment(
                startTimestamp: 0,
                fN2: 0.7902,
                setpoint: 1.3,
              ),
            ],
          );

      // At the last bottom sample the CCR diver has less N2 loaded.
      final ocN2 = ocStatuses[3].compartments.first.currentPN2;
      final ccrN2 = ccrStatuses[3].compartments.first.currentPN2;
      expect(ccrN2, lessThan(ocN2));
    });
  });

  group('CCR loop ascent plan (issue #455)', () {
    // Square profile deep/long enough to be in deco at the last bottom sample.
    const depths = [0.0, 45.0, 45.0, 45.0, 45.0, 0.0];
    const times = [0, 180, 600, 1200, 2400, 2700];

    const loopSegments = [
      ProfileGasSegment(startTimestamp: 0, fN2: 0.79, setpoint: 1.3),
    ];

    BuhlmannAlgorithm algo() => BuhlmannAlgorithm(gfLow: 0.45, gfHigh: 0.75);

    /// Deco status at sample [index], tissues loaded on [segments], with the
    /// ascent forced onto [plan]. A loop sample always ascends on the loop
    /// in processProfileWithGasSegments (issue #577), so an explicit plan
    /// for one is applied through getDecoStatus.
    DecoStatus statusWithPlan(
      List<ProfileGasSegment> segments,
      int index,
      AscentGasPlan plan,
    ) {
      final engine = algo()
        ..processProfileWithGasSegments(
          depths: depths.sublist(0, index + 1),
          timestamps: times.sublist(0, index + 1),
          gasSegments: segments,
        );
      final gas = segments.lastWhere((s) => s.startTimestamp <= times[index]);
      return engine.getDecoStatus(
        currentDepth: depths[index],
        fN2: gas.fN2,
        fHe: gas.fHe,
        ascentGas: plan,
        breathing: ClosedCircuit(
          setpoint: gas.setpoint!,
          diluentFO2: 1.0 - gas.fN2 - gas.fHe,
          diluentFHe: gas.fHe,
        ),
      );
    }

    CcrLoopAscentGas plan(double sp) => CcrLoopAscentGas(
      environment: DiveEnvironment.standard,
      setpointLow: sp,
      setpointHigh: sp,
      switchDepth: 0.0,
      diluentFO2: 0.21,
      diluentFHe: 0.0,
    );

    test('derived loop plan matches an explicit CcrLoopAscentGas', () {
      final derived = algo().processProfileWithGasSegments(
        depths: depths,
        timestamps: times,
        gasSegments: loopSegments,
      );
      for (var i = 0; i < depths.length; i++) {
        final explicit = statusWithPlan(loopSegments, i, plan(1.3));
        expect(derived[i].ttsSeconds, explicit.ttsSeconds, reason: 'tts $i');
        expect(
          derived[i].ceilingMeters,
          explicit.ceilingMeters,
          reason: 'ceiling $i',
        );
      }
    });

    test('loop TTS is shorter than breathing the diluent open-circuit on the '
        'ascent (setpoint held through stops)', () {
      // Same loading for both (segments identical); only the ascent plan
      // differs: derived loop plan vs the diluent as a fixed OC ascent gas.
      final loop = algo().processProfileWithGasSegments(
        depths: depths,
        timestamps: times,
        gasSegments: loopSegments,
      );
      final ocAscent = statusWithPlan(
        loopSegments,
        4,
        FixedAscentGas(fN2: 0.79),
      );
      // In deco at the last bottom sample; the O2-rich loop clears stops faster.
      expect(loop[4].ndlSeconds, -1);
      expect(loop[4].ttsSeconds, lessThan(ocAscent.ttsSeconds));
    });

    test('ascent plan follows the ACTIVE segment setpoint per sample', () {
      const twoSetpoints = [
        ProfileGasSegment(startTimestamp: 0, fN2: 0.79, setpoint: 0.7),
        ProfileGasSegment(startTimestamp: 900, fN2: 0.79, setpoint: 1.3),
      ];
      final derived = algo().processProfileWithGasSegments(
        depths: depths,
        timestamps: times,
        gasSegments: twoSetpoints,
      );
      // Sample index 2 (t=600) is in the 0.7 segment; index 4 (t=2400) in 1.3.
      expect(
        derived[2].ttsSeconds,
        statusWithPlan(twoSetpoints, 2, plan(0.7)).ttsSeconds,
      );
      expect(
        derived[4].ttsSeconds,
        statusWithPlan(twoSetpoints, 4, plan(1.3)).ttsSeconds,
      );
      // The two setpoints must give different ascents, or the check above
      // cannot tell which segment the plan followed.
      expect(
        statusWithPlan(twoSetpoints, 4, plan(0.7)).ttsSeconds,
        isNot(derived[4].ttsSeconds),
      );
    });
  });
}
