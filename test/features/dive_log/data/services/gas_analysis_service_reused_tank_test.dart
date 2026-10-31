import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/features/dive_log/data/services/gas_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/cylinder_sac.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';

/// SAC for a cylinder the diver returns to after breathing another (issue
/// #3900): every breathing period counts, not just the first.
void main() {
  const service = GasAnalysisService(gasModel: GasModel.ideal);

  List<DiveProfilePoint> flatProfile(int seconds, {double depth = 20}) => [
    for (var t = 0; t <= seconds; t += 60)
      DiveProfilePoint(timestamp: t, depth: depth),
  ];

  Dive makeDive(
    List<DiveTank> tanks, {
    int seconds = 2400,
    List<DiveProfilePoint>? profile,
  }) {
    return Dive(
      id: 'dive-1',
      dateTime: DateTime(2026, 10, 1, 10),
      runtime: Duration(seconds: seconds),
      avgDepth: 20,
      tanks: tanks,
      profile: profile ?? flatProfile(seconds),
      gear: looseGear(const []),
      notes: '',
      photoIds: const [],
      sightings: const [],
      weights: const [],
      tags: const [],
    );
  }

  GasSwitchWithTank switchTo(String tankId, int timestamp) {
    return GasSwitchWithTank(
      gasSwitch: GasSwitch(
        id: 'gs-$tankId-$timestamp',
        diveId: 'dive-1',
        timestamp: timestamp,
        tankId: tankId,
        createdAt: DateTime(2026),
      ),
      tankName: tankId,
      gasMix: 'mix',
      o2Fraction: 0.21,
    );
  }

  const left = DiveTank(
    id: 'left',
    volume: 12,
    startPressure: 200,
    endPressure: 100,
    role: TankRole.sidemountLeft,
  );
  const right = DiveTank(
    id: 'right',
    volume: 12,
    startPressure: 200,
    endPressure: 100,
    role: TankRole.sidemountRight,
    order: 1,
  );

  final alternating = [
    switchTo('left', 0),
    switchTo('right', 600),
    switchTo('left', 1200),
    switchTo('right', 1800),
  ];

  CylinderSac sacOf(List<CylinderSac> results, String tankId) =>
      results.firstWhere((r) => r.tankId == tankId);

  group('calculateCylinderSac', () {
    test('sums every breathing period of a pair breathed in turns', () {
      final dive = makeDive(const [left, right]);

      final results = service.calculateCylinderSac(
        dive: dive,
        profile: dive.profile,
        gasSwitches: alternating,
      );

      for (final tankId in ['left', 'right']) {
        final cylinder = sacOf(results, tankId);
        expect(cylinder.usageDuration, const Duration(seconds: 1200));
        // 100 bar / 20 min / 3 bar ambient.
        expect(cylinder.sacRate, closeTo(100 / 20 / 3, 1e-9));
        expect(cylinder.rmv, closeTo(20, 1e-9));
      }
    });

    test('counts a deco gas on both sides of an air break', () {
      // Back gas to 30:00, oxygen to 35:00, back gas for the air break to
      // 40:00, oxygen to 50:00, then back gas to the surface at 55:00.
      const backGas = DiveTank(
        id: 'back',
        volume: 12,
        startPressure: 200,
        endPressure: 80,
        role: TankRole.backGas,
      );
      const oxygen = DiveTank(
        id: 'o2',
        volume: 7,
        startPressure: 200,
        endPressure: 170,
        role: TankRole.deco,
        gasMix: GasMix(o2: 100, he: 0),
        order: 1,
      );
      final dive = makeDive(const [backGas, oxygen], seconds: 3300);

      final results = service.calculateCylinderSac(
        dive: dive,
        profile: dive.profile,
        gasSwitches: [
          switchTo('o2', 1800),
          switchTo('back', 2100),
          switchTo('o2', 2400),
          switchTo('back', 3000),
        ],
      );

      final deco = sacOf(results, 'o2');
      expect(deco.usageDuration, const Duration(minutes: 15));
      expect(deco.sacRate, closeTo(30 / 15 / 3, 1e-9));

      final back = sacOf(results, 'back');
      expect(back.usageDuration, const Duration(minutes: 40));
      expect(back.sacRate, closeTo(120 / 40 / 3, 1e-9));
    });

    test('averages the depth of every breathing period', () {
      // Left at 10 m for its first period and 30 m for its second, right at
      // 40 m. Samples sit on the switches, so each boundary sample at 40 m
      // joins left's two periods as well: 10 at 10 m, 10 at 30 m, 2 at 40 m.
      double depthAt(int t) {
        if (t < 600) return 10;
        if (t >= 1200 && t < 1800) return 30;
        return 40;
      }

      final profile = [
        for (var t = 0; t <= 2400; t += 60)
          DiveProfilePoint(timestamp: t, depth: depthAt(t)),
      ];
      final dive = makeDive(const [left, right], profile: profile);

      final results = service.calculateCylinderSac(
        dive: dive,
        profile: profile,
        gasSwitches: alternating,
      );

      expect(
        sacOf(results, 'left').avgDepthDuringUse,
        closeTo((10 * 10 + 10 * 30 + 2 * 40) / 22, 1e-9),
      );
    });

    test('takes the whole drop of a transmitter series across its periods', () {
      // Left drops 30 bar in its first ten minutes, holds while right is on
      // the regulator, then drops 70 bar in its second ten minutes.
      TankPressurePoint point(int t, double bar) =>
          TankPressurePoint(tankId: 'left', timestamp: t, pressure: bar);
      final dive = makeDive(const [left, right]);

      final results = service.calculateCylinderSac(
        dive: dive,
        profile: dive.profile,
        gasSwitches: alternating,
        tankPressures: {
          'left': [
            point(0, 200),
            point(600, 170),
            point(1200, 170),
            point(1800, 100),
            point(2400, 100),
          ],
        },
      );

      final cylinder = sacOf(results, 'left');
      expect(cylinder.hasTimeSeriesData, isTrue);
      expect(cylinder.usageDuration, const Duration(seconds: 1200));
      expect(cylinder.sacRate, closeTo(100 / 20 / 3, 1e-9));
    });

    test('leaves a cylinder breathed once on its single period', () {
      const backGas = DiveTank(
        id: 'back',
        volume: 12,
        startPressure: 200,
        endPressure: 100,
        role: TankRole.backGas,
      );
      const stage = DiveTank(
        id: 'stage',
        volume: 7,
        startPressure: 200,
        endPressure: 150,
        role: TankRole.stage,
        order: 1,
      );
      final dive = makeDive(const [backGas, stage]);

      final results = service.calculateCylinderSac(
        dive: dive,
        profile: dive.profile,
        gasSwitches: [switchTo('stage', 1800)],
      );

      expect(
        sacOf(results, 'back').usageDuration,
        const Duration(seconds: 1800),
      );
      final stageSac = sacOf(results, 'stage');
      expect(stageSac.usageDuration, const Duration(seconds: 600));
      expect(stageSac.sacRate, closeTo(50 / 10 / 3, 1e-9));
    });
  });

  group('calculateGasSwitchSegments', () {
    test('spreads a cylinder across all of its periods', () {
      final dive = makeDive(const [left, right]);

      final segments = service.calculateGasSwitchSegments(
        profile: dive.profile,
        tanks: dive.tanks,
        gasSwitches: alternating,
      );

      expect(segments, hasLength(4));
      for (final segment in segments!) {
        // Each ten-minute period carries half of its cylinder's 100 bar.
        expect(segment.sacRate, closeTo(50 / 10 / 3, 1e-9));
      }
      for (final tankId in ['left', 'right']) {
        final consumed = segments
            .where((s) => s.tankId == tankId)
            .fold<double>(0, (sum, s) => sum + s.gasConsumed);
        expect(consumed, closeTo(100, 1e-9), reason: 'charged exactly once');
      }
    });
  });

  group('calculatePhaseSegments', () {
    test('charges a phase only for the time its cylinder was breathed', () {
      // A flat profile is one bottom phase, attributed to the cylinder on the
      // regulator as it starts, which is left for half of the phase. A drop
      // small enough to stay above 0 bar keeps gasVolume from clamping an
      // overcharged estimate back onto the right answer.
      const lightlyUsed = DiveTank(
        id: 'left',
        volume: 12,
        startPressure: 200,
        endPressure: 150,
        role: TankRole.sidemountLeft,
      );
      final dive = makeDive(const [lightlyUsed, right]);

      final segments = service.calculatePhaseSegments(
        profile: dive.profile,
        tanks: dive.tanks,
        gasSwitches: alternating,
      );

      expect(segments, hasLength(1));
      expect(segments!.single.tankId, 'left');
      expect(segments.single.sacRate, closeTo(50 / 20 / 3, 1e-9));
    });

    test('keeps a phase in a later period on its share of the drop', () {
      // A bottom phase across left's two periods, then an ascent inside the
      // second: thirty minutes breathed in all, so every rate is the same
      // 100 bar / 30 min at that segment's own depth.
      final profile = [
        for (var t = 0; t <= 2400; t += 60)
          DiveProfilePoint(
            timestamp: t,
            depth: t <= 2100 ? 30 : 30 - (t - 2100) / 15,
          ),
      ];
      final dive = makeDive(const [left, right], profile: profile);

      final segments = service.calculatePhaseSegments(
        profile: profile,
        tanks: dive.tanks,
        gasSwitches: [
          switchTo('left', 0),
          switchTo('right', 600),
          switchTo('left', 1200),
        ],
      );

      expect(segments, hasLength(2));
      for (final segment in segments!) {
        expect(segment.tankId, 'left');
        expect(
          segment.sacRate,
          closeTo(100 / 30 / (segment.avgDepth / 10 + 1), 1e-9),
        );
      }
    });
  });
}
