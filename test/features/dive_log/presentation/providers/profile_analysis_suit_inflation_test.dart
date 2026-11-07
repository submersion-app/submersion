import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// A suit inflation bottle is not breathing gas (issue #4243): the deco
/// model, oxygen exposure and the ascent never load or plan on it.
void main() {
  Dive dive(List<DiveTank> tanks, {DiveMode mode = DiveMode.oc}) => Dive(
    id: 'd1',
    dateTime: DateTime.utc(2026, 1, 1),
    diveMode: mode,
    tanks: tanks,
  );

  const suit = DiveTank(
    id: 'suit',
    volume: 0.85,
    gasMix: GasMix(o2: 21),
    role: TankRole.suitInflation,
  );
  const left = DiveTank(
    id: 'l',
    gasMix: GasMix(o2: 32),
    role: TankRole.sidemountLeft,
  );
  const right = DiveTank(
    id: 'r',
    gasMix: GasMix(o2: 32),
    role: TankRole.sidemountRight,
  );
  const air = DiveTank(id: 'b', gasMix: GasMix(o2: 21), role: TankRole.backGas);
  const ean50 = DiveTank(
    id: 'deco',
    gasMix: GasMix(o2: 50),
    role: TankRole.deco,
  );

  GasSwitchWithTank switchTo(DiveTank tank, int t) => GasSwitchWithTank(
    gasSwitch: GasSwitch(
      id: 'gs-${tank.id}-$t',
      diveId: 'd1',
      timestamp: t,
      tankId: tank.id,
      createdAt: DateTime(2026),
    ),
    tankName: tank.id,
    gasMix: tank.gasMix.name,
    o2Fraction: tank.gasMix.o2 / 100,
    heFraction: tank.gasMix.he / 100,
  );

  group('deco gas schedule', () {
    test('a sidemount dive with the bottle first starts on the pair', () {
      final segments = buildProfileGasSegments(
        dive(const [suit, left, right]),
        const [],
      );

      expect(segments.single.fN2, closeTo(0.68, 1e-9));
    });

    test('a switch to the air bottle after EAN50 is back on air', () {
      final segments = buildProfileGasSegments(dive(const [air, ean50, suit]), [
        switchTo(ean50, 1200),
        switchTo(suit, 1800),
      ]);

      expect(segments.map((s) => s.startTimestamp), [0, 1200, 1800]);
      expect(segments.last.fN2, airN2Fraction);
    });

    test('a switch to a bottle on no breathing mix is dropped', () {
      const odd = DiveTank(
        id: 'suit',
        gasMix: GasMix(o2: 40),
        role: TankRole.suitInflation,
      );
      final segments = buildProfileGasSegments(dive(const [air, odd]), [
        switchTo(odd, 1800),
      ]);

      expect(segments, hasLength(1));
    });
  });

  test('the bottle is no ascent gas', () {
    final gases = buildAvailableGases(
      dive(const [air, ean50, suit]),
      maxPpO2: 1.6,
      gasSet: AscentGasSet.allCarried,
    );
    final without = buildAvailableGases(
      dive(const [air, ean50]),
      maxPpO2: 1.6,
      gasSet: AscentGasSet.allCarried,
    );
    expect(gases.length, without.length);

    const rich = DiveTank(
      id: 'suit',
      gasMix: GasMix(o2: 40),
      role: TankRole.suitInflation,
    );
    expect(
      buildAvailableGases(
        dive(const [air, rich]),
        maxPpO2: 1.6,
        gasSet: AscentGasSet.allCarried,
      ),
      hasLength(1),
    );
  });

  test('a rebreather never runs its loop on the bottle', () {
    const rich = DiveTank(
      id: 'suit',
      gasMix: GasMix(o2: 40),
      role: TankRole.suitInflation,
    );
    const bailout = DiveTank(
      id: 'bo',
      gasMix: GasMix(o2: 32),
      role: TankRole.bailout,
    );

    expect(
      resolveCcrDiluentMix(dive(const [rich, bailout], mode: DiveMode.ccr)),
      const GasMix(),
    );
  });

  test('the bottle\'s pressure never joins the SAC curve', () {
    final pressures = {
      'b': const [
        TankPressurePoint(tankId: 'b', timestamp: 0, pressure: 200),
        TankPressurePoint(tankId: 'b', timestamp: 60, pressure: 190),
      ],
      'suit': const [
        TankPressurePoint(tankId: 'suit', timestamp: 0, pressure: 200),
        TankPressurePoint(tankId: 'suit', timestamp: 60, pressure: 100),
      ],
    };

    expect(
      combineMultiTankPressures(
        timestamps: const [0, 60],
        tankPressures: pressures,
        tanks: const [suit, air],
      ),
      combineMultiTankPressures(
        timestamps: const [0, 60],
        tankPressures: {'b': pressures['b']!},
        tanks: const [air],
      ),
    );
  });
}
