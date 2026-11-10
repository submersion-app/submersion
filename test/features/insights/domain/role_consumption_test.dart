import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/features/dive_log/data/services/gas_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/cylinder_sac.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/insights/domain/role_consumption.dart';

/// Issue #771: one dive's per-cylinder rows folded into one figure per
/// cylinder role group, each over the time and depth that gas was breathed.

const _service = GasAnalysisService(gasModel: GasModel.real);

const _back = DiveTank(
  id: 'back',
  volume: 12,
  startPressure: 200,
  endPressure: 80,
  gasMix: GasMix(o2: 21),
  role: TankRole.backGas,
  order: 0,
);
const _deco = DiveTank(
  id: 'deco',
  volume: 7,
  startPressure: 200,
  endPressure: 140,
  gasMix: GasMix(o2: 50),
  role: TankRole.deco,
  order: 1,
);

Dive _dive(List<DiveTank> tanks, {DiveMode diveMode = DiveMode.oc}) => Dive(
  id: 'dive',
  diveNumber: 1,
  dateTime: DateTime.utc(2026, 10, 1, 10),
  maxDepth: 25,
  avgDepth: 20,
  runtime: const Duration(minutes: 60),
  diveMode: diveMode,
  tanks: tanks,
);

/// 25 m to 50 minutes, then 6 m to the end.
const _profile = [
  DiveProfilePoint(timestamp: 0, depth: 25),
  DiveProfilePoint(timestamp: 2999, depth: 25),
  DiveProfilePoint(timestamp: 3000, depth: 6),
  DiveProfilePoint(timestamp: 3600, depth: 6),
];

GasSwitchWithTank _switchTo(String tankId, int timestamp) => GasSwitchWithTank(
  gasSwitch: GasSwitch(
    id: 'sw-$tankId-$timestamp',
    diveId: 'dive',
    timestamp: timestamp,
    tankId: tankId,
    createdAt: DateTime.utc(2026),
  ),
  tankName: tankId,
  gasMix: 'Air',
  o2Fraction: 0.21,
);

CylinderSac _row(List<CylinderSac> rows, String tankId) =>
    rows.singleWhere((r) => r.tankId == tankId);

/// Surface litres behind [row]'s rate.
double _liters(CylinderSac row) =>
    row.rmv! * (row.usageDuration!.inSeconds / 60) * row.rateAmbientBar!;

({List<CylinderSac> rows, DiveRoleConsumption result}) _run(
  Dive dive, {
  List<GasSwitchWithTank>? switches,
  List<DiveProfilePoint> profile = _profile,
  Map<String, List<TankPressurePoint>>? pressures,
  bool Function(DiveTank tank)? counted,
}) {
  final rows = _service.calculateCylinderSac(
    dive: dive,
    profile: profile,
    gasSwitches: switches,
    tankPressures: pressures,
  );
  return (
    rows: rows,
    result: roleConsumptionForDive(
      dive: dive,
      cylinders: rows,
      profile: profile,
      tankPressures: pressures,
      counted: counted,
    ),
  );
}

void main() {
  group('consumptionRoleGroupOf', () {
    test('folds the primary gas roles into bottom gas', () {
      for (final role in [
        TankRole.backGas,
        TankRole.twinSet,
        TankRole.sidemountLeft,
        TankRole.sidemountRight,
      ]) {
        expect(consumptionRoleGroupOf(role), ConsumptionRoleGroup.bottomGas);
      }
    });

    test('keeps stage, deco, pony and bailout apart', () {
      expect(
        consumptionRoleGroupOf(TankRole.stage),
        ConsumptionRoleGroup.stage,
      );
      expect(consumptionRoleGroupOf(TankRole.deco), ConsumptionRoleGroup.deco);
      expect(consumptionRoleGroupOf(TankRole.pony), ConsumptionRoleGroup.pony);
      expect(
        consumptionRoleGroupOf(TankRole.bailout),
        ConsumptionRoleGroup.bailout,
      );
    });

    test('loop roles join no group', () {
      expect(consumptionRoleGroupOf(TankRole.diluent), isNull);
      expect(consumptionRoleGroupOf(TankRole.oxygenSupply), isNull);
    });

    test('a suit inflation bottle joins no group', () {
      expect(consumptionRoleGroupOf(TankRole.suitInflation), isNull);
    });
  });

  group('roleConsumptionForDive', () {
    test('a one-cylinder group equals the dive detail row', () {
      final run = _run(_dive(const [_back]));
      final row = run.rows.single;

      expect(
        run.result.rmv[ConsumptionRoleGroup.bottomGas],
        closeTo(row.rmv!, 1e-9),
      );
      expect(
        run.result.sac[ConsumptionRoleGroup.bottomGas],
        closeTo(row.sacRate!, 1e-9),
      );
    });

    test('a one-cylinder group equals the row with a pressure series', () {
      final run = _run(
        _dive(const [_back]),
        pressures: const {
          'back': [
            TankPressurePoint(tankId: 'back', timestamp: 0, pressure: 200),
            TankPressurePoint(tankId: 'back', timestamp: 3600, pressure: 90),
          ],
        },
      );
      final row = run.rows.single;

      expect(row.hasTimeSeriesData, isTrue);
      expect(
        run.result.rmv[ConsumptionRoleGroup.bottomGas],
        closeTo(row.rmv!, 1e-9),
      );
    });

    test('a one-cylinder group equals the row without a profile', () {
      final run = _run(_dive(const [_back]), profile: const []);
      final row = run.rows.single;

      expect(
        run.result.rmv[ConsumptionRoleGroup.bottomGas],
        closeTo(row.rmv!, 1e-9),
      );
    });

    test('a rate at an unknown depth gives no figure', () {
      // No profile and no stored average depth: the service divides a
      // pressure series at a stand-in 10 m, which says nothing of the dive.
      final dive = Dive(
        id: 'dive',
        diveNumber: 1,
        dateTime: DateTime.utc(2026, 10, 1, 10),
        maxDepth: 25,
        runtime: const Duration(minutes: 60),
        tanks: const [_back],
      );
      final run = _run(
        dive,
        profile: const [],
        pressures: const {
          'back': [
            TankPressurePoint(tankId: 'back', timestamp: 0, pressure: 200),
            TankPressurePoint(tankId: 'back', timestamp: 3600, pressure: 90),
          ],
        },
      );

      expect(run.rows.single.sacRate, isNotNull);
      expect(run.result.rmv, isEmpty);
      expect(run.result.sac, isEmpty);
    });

    test('a rate at a stored 0 m average depth gives no figure', () {
      final run = _run(
        _dive(const [_back]).copyWith(avgDepth: 0),
        profile: const [],
      );

      expect(run.rows.single.sacRate, isNotNull);
      expect(run.result.rmv, isEmpty);
    });

    test('back gas and deco each use their own window', () {
      final run = _run(
        _dive(const [_back, _deco]),
        switches: [_switchTo('deco', 3000)],
      );
      final back = _row(run.rows, 'back');
      final deco = _row(run.rows, 'deco');

      expect(back.usageWindows, [(start: 0, end: 3000)]);
      expect(
        run.result.rmv[ConsumptionRoleGroup.bottomGas],
        closeTo(back.rmv!, 1e-9),
      );
      expect(
        run.result.rmv[ConsumptionRoleGroup.deco],
        closeTo(deco.rmv!, 1e-9),
      );
      expect(run.result.leftOut, isFalse);
    });

    test(
      'a deco cylinder that lost gas with no switch leaves the dive out',
      () {
        final run = _run(_dive(const [_back, _deco]));

        expect(run.result.leftOut, isTrue);
        expect(run.result.rmv, isEmpty);
        expect(run.result.sac, isEmpty);
      },
    );

    test('a deco cylinder with a recorded duration and no switch leaves the '
        'dive out', () {
      final deco = _deco.copyWith(usageDuration: const Duration(minutes: 10));
      final run = _run(_dive([_back, deco]));

      expect(_row(run.rows, 'deco').usageFromRecordedDuration, isTrue);
      expect(run.result.leftOut, isTrue);
      expect(run.result.rmv, isEmpty);
    });

    group('a carried cylinder with no switch', () {
      test('dropping 12 bar from 200 was cooling, not breathing', () {
        final deco = _deco.copyWith(endPressure: 188);
        final run = _run(_dive([_back, deco]));
        final back = _row(run.rows, 'back');

        expect(run.result.leftOut, isFalse);
        expect(run.result.rmv.keys, [ConsumptionRoleGroup.bottomGas]);
        expect(
          run.result.rmv[ConsumptionRoleGroup.bottomGas],
          closeTo(back.rmv!, 1e-9),
        );
      });

      test('dropping exactly 15 bar is still carried', () {
        final pony = _deco.copyWith(role: TankRole.pony, endPressure: 185);
        final run = _run(_dive([_back, pony]));

        expect(run.result.leftOut, isFalse);
      });

      test('dropping 20 bar from a 300 bar fill is still carried', () {
        final stage = _deco.copyWith(
          role: TankRole.stage,
          startPressure: 300,
          endPressure: 280,
        );
        final run = _run(_dive([_back, stage]));

        expect(run.result.leftOut, isFalse);
      });

      test('dropping 16 bar from 200 was breathed and leaves the dive out', () {
        final deco = _deco.copyWith(endPressure: 184);
        final run = _run(_dive([_back, deco]));

        expect(run.result.leftOut, isTrue);
      });

      test('dropping 22 bar from 300 leaves the dive out', () {
        final stage = _deco.copyWith(
          role: TankRole.stage,
          startPressure: 300,
          endPressure: 278,
        );
        final run = _run(_dive([_back, stage]));

        expect(run.result.leftOut, isTrue);
      });

      test('a recorded duration says it was breathed, however small', () {
        final deco = _deco.copyWith(
          endPressure: 195,
          usageDuration: const Duration(minutes: 10),
        );
        final run = _run(_dive([_back, deco]));

        expect(run.result.leftOut, isTrue);
      });
    });

    test('a deco switch naming a stale tank id leaves the dive out', () {
      final run = _run(
        _dive(const [_back, _deco]),
        switches: [_switchTo('ghost', 3000)],
      );

      expect(run.result.leftOut, isTrue);
    });

    test('a stage that did not lose gas leaves nothing out', () {
      final stage = _deco.copyWith(role: TankRole.stage, endPressure: 200);
      final run = _run(_dive([_back, stage]));

      expect(run.result.leftOut, isFalse);
      expect(run.result.rmv.keys, [ConsumptionRoleGroup.bottomGas]);
    });

    test('a stage with end above start is ignored', () {
      final stage = _deco.copyWith(
        role: TankRole.stage,
        startPressure: 180,
        endPressure: 200,
      );
      final run = _run(_dive([_back, stage]));

      expect(run.result.leftOut, isFalse);
      expect(run.result.rmv.containsKey(ConsumptionRoleGroup.stage), isFalse);
    });

    test('a stage of unknown size drops out alone', () {
      const stage = DiveTank(
        id: 'stage',
        startPressure: 200,
        endPressure: 150,
        gasMix: GasMix(o2: 32),
        role: TankRole.stage,
        order: 1,
      );
      final run = _run(
        _dive(const [_back, stage]),
        switches: [_switchTo('stage', 1200), _switchTo('back', 1800)],
      );
      final back = _row(run.rows, 'back');

      expect(run.result.leftOut, isFalse);
      expect(run.result.rmv.containsKey(ConsumptionRoleGroup.stage), isFalse);
      expect(
        run.result.rmv[ConsumptionRoleGroup.bottomGas],
        closeTo(back.rmv!, 1e-9),
      );
    });

    test('a sidemount pair on a shared window counts its time once', () {
      const left = DiveTank(
        id: 'left',
        volume: 11,
        startPressure: 200,
        endPressure: 100,
        gasMix: GasMix(o2: 21),
        role: TankRole.sidemountLeft,
        order: 0,
      );
      final right = left.copyWith(
        id: 'right',
        role: TankRole.sidemountRight,
        endPressure: 110,
        order: 1,
      );
      final run = _run(_dive([left, right]));

      expect(
        run.result.rmv[ConsumptionRoleGroup.bottomGas],
        closeTo(
          _row(run.rows, 'left').rmv! + _row(run.rows, 'right').rmv!,
          1e-9,
        ),
      );
    });

    test('a sidemount pair timed by recorded durations takes the longer', () {
      const left = DiveTank(
        id: 'left',
        volume: 11,
        startPressure: 200,
        endPressure: 100,
        gasMix: GasMix(o2: 21),
        role: TankRole.sidemountLeft,
        order: 0,
        usageDuration: Duration(minutes: 50),
      );
      final right = left.copyWith(
        id: 'right',
        role: TankRole.sidemountRight,
        order: 1,
        usageDuration: const Duration(minutes: 55),
      );
      final run = _run(_dive([left, right]));
      final l = _row(run.rows, 'left');
      final r = _row(run.rows, 'right');

      expect(
        run.result.rmv[ConsumptionRoleGroup.bottomGas],
        closeTo((_liters(l) + _liters(r)) / 55 / l.rateAmbientBar!, 1e-9),
      );
    });

    test('a recorded pair counts surface minutes at the surface whichever '
        'cylinder holds them (#2930)', () {
      // Only the right cylinder carries the ten minutes entered for the
      // surface, and the left one comes first. The group's time gains them
      // at 0 m, so its depth blends them in whatever order the rows come.
      const left = DiveTank(
        id: 'left',
        volume: 11,
        startPressure: 200,
        endPressure: 100,
        gasMix: GasMix(o2: 21),
        role: TankRole.sidemountLeft,
        order: 0,
        usageDuration: Duration(minutes: 50),
      );
      final right = left.copyWith(
        id: 'right',
        role: TankRole.sidemountRight,
        order: 1,
        usageDuration: const Duration(minutes: 55),
        surfaceBreathingDuration: const Duration(minutes: 10),
      );
      final dive = _dive([left, right]);
      final run = _run(dive);
      final l = _row(run.rows, 'left');
      final r = _row(run.rows, 'right');
      final ambient = dive.environment.pressureAtDepth(
        l.avgDepthDuringUse! * 55 / 65,
      );

      expect(
        run.result.rmv[ConsumptionRoleGroup.bottomGas],
        closeTo((_liters(l) + _liters(r)) / 65 / ambient, 1e-9),
      );
    });

    test('two stages breathed one after the other add their time', () {
      final a = _deco.copyWith(id: 'a', role: TankRole.stage, order: 1);
      final b = _deco.copyWith(
        id: 'b',
        role: TankRole.stage,
        endPressure: 120,
        order: 2,
      );
      final dive = _dive([_back, a, b]);
      final run = _run(
        dive,
        switches: [
          _switchTo('a', 600),
          _switchTo('b', 1200),
          _switchTo('back', 1800),
        ],
      );
      final rowA = _row(run.rows, 'a');
      final rowB = _row(run.rows, 'b');

      expect(rowA.usageWindows, [(start: 600, end: 1200)]);
      expect(rowB.usageWindows, [(start: 1200, end: 1800)]);
      expect(
        run.result.rmv[ConsumptionRoleGroup.stage],
        closeTo(
          (_liters(rowA) + _liters(rowB)) /
              20 /
              dive.environment.pressureAtDepth(25),
          1e-9,
        ),
      );
    });

    test('SAC lane at real gas follows sacRate, not the raw bar drop', () {
      final run = _run(_dive(const [_back]));
      final row = run.rows.single;
      final rawBarPerMinute = 120 / 60 / row.rateAmbientBar!;

      expect(
        run.result.sac[ConsumptionRoleGroup.bottomGas],
        closeTo(row.sacRate!, 1e-9),
      );
      expect(
        run.result.sac[ConsumptionRoleGroup.bottomGas],
        isNot(closeTo(rawBarPerMinute, 1e-3)),
      );
    });

    group('on a CCR dive', () {
      const diluent = DiveTank(
        id: 'dil',
        volume: 3,
        startPressure: 200,
        endPressure: 150,
        gasMix: GasMix(o2: 21),
        role: TankRole.diluent,
        order: 0,
      );
      const oxygen = DiveTank(
        id: 'o2',
        volume: 2,
        startPressure: 200,
        endPressure: 120,
        gasMix: GasMix(o2: 100),
        role: TankRole.oxygenSupply,
        order: 1,
      );
      const bailout = DiveTank(
        id: 'bail',
        volume: 11,
        startPressure: 200,
        endPressure: 150,
        gasMix: GasMix(o2: 21),
        role: TankRole.bailout,
        order: 2,
      );

      test('only its bailout gas goes in bailout', () {
        final run = _run(
          _dive(const [diluent, oxygen, bailout], diveMode: DiveMode.ccr),
          switches: [_switchTo('bail', 2400)],
        );

        expect(run.result.rmv.keys, [ConsumptionRoleGroup.bailout]);
        expect(
          run.result.rmv[ConsumptionRoleGroup.bailout],
          closeTo(_row(run.rows, 'bail').rmv!, 1e-9),
        );
      });

      test('with no bailout it has no figures', () {
        final run = _run(
          _dive([
            diluent,
            oxygen,
            bailout.copyWith(endPressure: 200),
          ], diveMode: DiveMode.ccr),
        );

        expect(run.result.rmv, isEmpty);
        expect(run.result.leftOut, isFalse);
      });

      test('a bailout that lost gas with no switch onto it leaves the dive '
          'out', () {
        final run = _run(
          _dive(const [diluent, oxygen, bailout], diveMode: DiveMode.ccr),
        );

        expect(run.result.leftOut, isTrue);
        expect(run.result.rmv, isEmpty);
      });

      test('a second bailout with no switch leaves out a dive that bailed '
          'onto the first', () {
        final second = bailout.copyWith(id: 'bail-2', order: 3);
        final run = _run(
          _dive([diluent, oxygen, bailout, second], diveMode: DiveMode.ccr),
          switches: [_switchTo('bail', 2400)],
        );

        expect(run.result.leftOut, isTrue);
      });

      test('a bailout carried with a small drop leaves nothing out', () {
        final run = _run(
          _dive([
            diluent,
            oxygen,
            bailout.copyWith(endPressure: 188),
          ], diveMode: DiveMode.ccr),
        );

        expect(run.result.leftOut, isFalse);
      });
    });

    test('a tank not counted is ignored', () {
      final copy = _back.copyWith(id: 'copy', endPressure: 20);
      final run = _run(
        _dive([_back, copy]),
        counted: (tank) => tank.id != 'copy',
      );

      expect(
        run.result.rmv[ConsumptionRoleGroup.bottomGas],
        closeTo(_row(run.rows, 'back').rmv!, 1e-9),
      );
    });

    test('a group with no breathing time gives no figure', () {
      // Hand-built: a switch onto deco at the dive's last second.
      final dive = _dive(const [_back, _deco]);
      final rows = [
        ..._service.calculateCylinderSac(
          dive: _dive(const [_back]),
          profile: _profile,
        ),
        const CylinderSac(
          tankId: 'deco',
          gasMix: GasMix(o2: 50),
          role: TankRole.deco,
          tankVolume: 7,
          sacRate: 1,
          usageDuration: Duration.zero,
          usageWindows: [(start: 3600, end: 3600)],
          rateAmbientBar: 1.6,
          order: 1,
        ),
      ];
      final result = roleConsumptionForDive(
        dive: dive,
        cylinders: rows,
        profile: _profile,
      );

      expect(result.rmv.containsKey(ConsumptionRoleGroup.deco), isFalse);
      expect(result.rmv.values.every((v) => v.isFinite), isTrue);
      expect(result.sac.values.every((v) => v.isFinite), isTrue);
    });

    test('a window under a minute gives no figure', () {
      // A switch logged a second before the end: a real logged drop over one
      // second would plot thousands of litres a minute.
      final run = _run(
        _dive(const [_back, _deco]),
        switches: [_switchTo('deco', 3599)],
      );

      expect(_row(run.rows, 'deco').usageWindows, [(start: 3599, end: 3600)]);
      expect(run.result.rmv.containsKey(ConsumptionRoleGroup.deco), isFalse);
      expect(run.result.sac.containsKey(ConsumptionRoleGroup.deco), isFalse);
      expect(
        run.result.rmv.containsKey(ConsumptionRoleGroup.bottomGas),
        isTrue,
      );
    });

    test(
      'recorded and unrecorded cylinders of a group stay within the dive',
      () {
        // Two back gas cylinders on different gases, so not a matched pair: one
        // recorded at 45 minutes, the other spanning the whole dive.
        final a = _back.copyWith(usageDuration: const Duration(minutes: 45));
        final b = _back.copyWith(
          id: 'b',
          volume: 7,
          endPressure: 150,
          gasMix: const GasMix(o2: 32),
          order: 1,
        );
        final run = _run(_dive([a, b]));
        final rowA = _row(run.rows, 'back');
        final rowB = _row(run.rows, 'b');

        expect(rowA.usageFromRecordedDuration, isTrue);
        expect(rowB.usageDuration, const Duration(minutes: 60));
        expect(
          run.result.rmv[ConsumptionRoleGroup.bottomGas],
          closeTo(
            (_liters(rowA) + _liters(rowB)) / 60 / rowA.rateAmbientBar!,
            1e-9,
          ),
        );
      },
    );

    test('the SAC lane is in bar of the first sized cylinder', () {
      // An unsized back gas cylinder first, on a different gas from the
      // sized one, so it cannot borrow a size.
      const unsized = DiveTank(
        id: 'unsized',
        startPressure: 200,
        endPressure: 150,
        gasMix: GasMix(o2: 32),
        role: TankRole.backGas,
        order: 0,
      );
      final sized = _back.copyWith(order: 1);
      final run = _run(_dive([unsized, sized]));

      expect(
        run.result.sac[ConsumptionRoleGroup.bottomGas],
        closeTo(_row(run.rows, 'back').sacRate!, 1e-9),
      );
    });

    test('diluent and oxygen roles on an open-circuit dive join no group', () {
      final diluent = _deco.copyWith(id: 'dil', role: TankRole.diluent);
      final run = _run(_dive([_back, diluent]));

      expect(run.result.leftOut, isFalse);
      expect(run.result.rmv.keys, [ConsumptionRoleGroup.bottomGas]);
    });

    group('a suit inflation bottle (issue #4243)', () {
      // Argon, listed first and losing gas, as an import writes it.
      const suit = DiveTank(
        id: 'suit',
        volume: 0.85,
        startPressure: 200,
        endPressure: 120,
        gasMix: GasMix(o2: 21),
        role: TankRole.suitInflation,
        order: 0,
      );

      void expectSameAs(DiveRoleConsumption a, DiveRoleConsumption b) {
        expect(a.leftOut, b.leftOut);
        expect(a.rmv.keys, b.rmv.keys);
        for (final group in b.rmv.keys) {
          expect(a.rmv[group], closeTo(b.rmv[group]!, 1e-9));
          expect(a.sac[group], closeTo(b.sac[group]!, 1e-9));
        }
      }

      test('changes nothing beside back gas and a switched deco', () {
        final back = _back.copyWith(order: 1);
        final deco = _deco.copyWith(order: 2);
        final switches = [_switchTo('deco', 3000)];

        final withSuit = _run(_dive([suit, back, deco]), switches: switches);
        final without = _run(_dive([back, deco]), switches: switches);

        expect(without.result.rmv.keys, hasLength(2));
        expectSameAs(withSuit.result, without.result);
      });

      test('does not make a lone timed pony a dive to leave out', () {
        // Alone, the pony is the dive's only breathing gas and its recorded
        // time is the dive's; the bottle beside it is not a second cylinder.
        final pony = _deco.copyWith(
          id: 'pony',
          role: TankRole.pony,
          order: 1,
          usageDuration: const Duration(minutes: 40),
        );

        final withSuit = _run(_dive([suit, pony]));
        final without = _run(_dive([pony]));

        expect(without.result.rmv.keys, [ConsumptionRoleGroup.pony]);
        expectSameAs(withSuit.result, without.result);
      });
    });
  });
}
