import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/features/dive_log/data/services/estimated_tank_pressure_synthesizer.dart';
import 'package:submersion/features/dive_log/data/services/gas_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/services/ccr_bailout_timeline.dart';
import 'package:submersion/features/dive_log/domain/services/ccr_cylinder_use.dart';
import 'package:submersion/features/dive_log/domain/services/ccr_gas_schedule.dart';

/// A suit inflation bottle is not breathing gas (issue #4243): no cylinder
/// SAC, no loop gas use, no bailout, no estimated pressure curve.
void main() {
  const service = GasAnalysisService();

  // A flat 20 m dive, one sample every 10 s for an hour.
  final profile = [
    for (var t = 0; t <= 3600; t += 10)
      DiveProfilePoint(timestamp: t, depth: 20.0),
  ];

  Dive dive(List<DiveTank> tanks, {DiveMode mode = DiveMode.oc}) => Dive(
    id: 'dive-1',
    dateTime: DateTime(2026, 3, 28, 10),
    runtime: const Duration(minutes: 60),
    avgDepth: 20.0,
    diveMode: mode,
    tanks: tanks,
    profile: profile,
  );

  const suit = DiveTank(
    id: 'suit',
    volume: 0.85,
    startPressure: 200,
    endPressure: 120,
    gasMix: GasMix(o2: 21),
    role: TankRole.suitInflation,
    usageDuration: Duration(minutes: 60),
  );
  const back = DiveTank(
    id: 'back',
    volume: 11.1,
    startPressure: 200,
    endPressure: 100,
    gasMix: GasMix(o2: 32),
    role: TankRole.backGas,
  );
  const diluent = DiveTank(
    id: 'dil',
    volume: 3,
    startPressure: 200,
    endPressure: 150,
    gasMix: GasMix(o2: 21),
    role: TankRole.diluent,
  );
  const oxygen = DiveTank(
    id: 'o2',
    volume: 3,
    startPressure: 200,
    endPressure: 140,
    gasMix: GasMix(o2: 100),
    role: TankRole.oxygenSupply,
  );

  GasSwitchWithTank switchTo(DiveTank tank, int t) => GasSwitchWithTank(
    gasSwitch: GasSwitch(
      id: 'gs-${tank.id}-$t',
      diveId: 'dive-1',
      timestamp: t,
      tankId: tank.id,
      createdAt: DateTime(2026),
    ),
    tankName: tank.id,
    gasMix: tank.gasMix.name,
    o2Fraction: tank.gasMix.o2 / 100,
    heFraction: tank.gasMix.he / 100,
  );

  group('cylinder SAC', () {
    test('open circuit: no row for the bottle, the rest unchanged', () {
      final withSuit = service.calculateCylinderSac(
        dive: dive(const [suit, back]),
        profile: profile,
      );
      final without = service.calculateCylinderSac(
        dive: dive(const [back]),
        profile: profile,
      );

      expect(withSuit.map((r) => r.tankId), ['back']);
      expect(withSuit, without);
    });

    test('rebreather: no row for the bottle', () {
      final rows = service.calculateCylinderSac(
        dive: dive(const [suit, diluent, oxygen], mode: DiveMode.ccr),
        profile: profile,
      );

      expect(rows.map((r) => r.tankId), isNot(contains('suit')));
    });
  });

  group('gas switch segments', () {
    test('a switch only to a bottle on no breathing mix gives none', () {
      // The air bottle's switch has no breathing cylinder to land on
      // beside EAN32 back gas, so it is dropped and nothing is left.
      expect(
        service.calculateGasSwitchSegments(
          profile: profile,
          tanks: const [suit, back],
          gasSwitches: [switchTo(suit, 1200)],
        ),
        isNull,
      );
    });

    test('a dive whose only cylinder is the bottle has none', () {
      // A stale switch (a tank id a re-import left behind) must not fall
      // back onto the bottle and give it a SAC.
      const gone = DiveTank(id: 'gone', gasMix: GasMix(o2: 32));
      expect(
        service.calculateGasSwitchSegments(
          profile: profile,
          tanks: const [suit],
          gasSwitches: [switchTo(gone, 1200)],
        ),
        isNull,
      );
    });
  });

  test('phase segments read a dropped bottle switch as no switch', () {
    // No backmount cylinder, so the stage's window comes from the fallback,
    // which must see the switch to the air bottle dropped, as it is for
    // every other reading (no breathing cylinder is on air).
    const stage = DiveTank(
      id: 'stage',
      volume: 11.1,
      startPressure: 200,
      endPressure: 100,
      gasMix: GasMix(o2: 32),
      role: TankRole.stage,
    );
    const deco = DiveTank(
      id: 'deco',
      volume: 7,
      gasMix: GasMix(o2: 50),
      role: TankRole.deco,
      order: 1,
    );
    List<double?>? sacs(List<DiveTank> tanks, List<GasSwitchWithTank> sw) =>
        service
            .calculatePhaseSegments(
              profile: profile,
              tanks: tanks,
              gasSwitches: sw,
            )
            ?.map((s) => s.sacRate)
            .toList();

    final without = sacs(const [stage, deco], const []);
    expect(without, isNotEmpty);
    expect(sacs(const [stage, deco, suit], [switchTo(suit, 1200)]), without);
  });

  group('rebreather gas use', () {
    CcrDiveUse use(List<DiveTank> tanks) => ccrDiveUse(
      tanks: tanks,
      gasSwitches: const [],
      tankPressures: null,
      diveEnd: 3600,
      gasModel: GasModel.ideal,
    );

    test('an argon pressure drop is not diluent use', () {
      expect(
        use(const [suit, diluent, oxygen]).diluentRate,
        use(const [diluent, oxygen]).diluentRate,
      );
      expect(
        use(const [suit, diluent, oxygen]).o2Rate,
        use(const [diluent, oxygen]).o2Rate,
      );
    });

    test('a switch to an air bottle is a diluent change, not a bailout', () {
      final changes = classifyCcrGasChanges(
        [switchTo(suit, 1200)],
        const [diluent, oxygen, suit],
      );

      expect(changes.single.kind, CcrGasChangeKind.diluent);
    });

    test('a bottle on no breathing mix is no change at all', () {
      const argonish = DiveTank(
        id: 'suit',
        gasMix: GasMix(o2: 40),
        role: TankRole.suitInflation,
      );

      expect(
        classifyCcrGasChanges(
          [switchTo(argonish, 1200)],
          const [diluent, oxygen, argonish],
        ),
        isEmpty,
      );
    });

    test('a breathed cylinder never takes the suit inflation role', () {
      expect(openCircuitTargetRole('suitInflation'), TankRole.bailout);
      expect(openCircuitTargetRole('deco'), TankRole.deco);
    });
  });

  test('no estimated pressure curve for the bottle', () {
    final estimated = synthesizeEstimatedTankPressures(
      existing: const {},
      tanks: const [suit, back],
      gasSwitches: const [],
      diveDurationSeconds: 3600,
    );

    expect(estimated.pressures.keys, ['back']);
  });
}
