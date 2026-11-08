import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/features/dive_log/data/services/gas_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/cylinder_sac.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';

/// Issue #771: the per-role trend rebuilds a role's rate from these rows, so
/// each row says which windows its rate covers, whether its time came from a
/// recorded duration, and the ambient pressure its rate was divided by.

const _service = GasAnalysisService(gasModel: GasModel.ideal);

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

Dive _dive({
  List<DiveTank> tanks = const [_back, _deco],
  DiveMode diveMode = DiveMode.oc,
}) => Dive(
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

void main() {
  group('calculateCylinderSac rows carry their windows', () {
    test('a switched cylinder carries its windows and ambient pressure', () {
      final dive = _dive();
      final rows = _service.calculateCylinderSac(
        dive: dive,
        profile: _profile,
        gasSwitches: [_switchTo('deco', 3000)],
      );

      final deco = _row(rows, 'deco');
      expect(deco.usageWindows, [(start: 3000, end: 3600)]);
      expect(deco.usageFromRecordedDuration, isFalse);
      expect(
        deco.rateAmbientBar,
        closeTo(
          dive.environment.pressureAtDepth(deco.avgDepthDuringUse!),
          1e-9,
        ),
      );

      final back = _row(rows, 'back');
      expect(back.usageWindows, [(start: 0, end: 3000)]);
      expect(
        back.rateAmbientBar,
        closeTo(
          dive.environment.pressureAtDepth(back.avgDepthDuringUse!),
          1e-9,
        ),
      );
    });

    test('the rate divides by the ambient pressure it carries', () {
      final rows = _service.calculateCylinderSac(
        dive: _dive(),
        profile: _profile,
        gasSwitches: [_switchTo('deco', 3000)],
      );

      final deco = _row(rows, 'deco');
      final minutes = deco.usageDuration!.inSeconds / 60;
      // Ideal gas: 60 bar of a 7 L cylinder is 420 L.
      expect(deco.rmv! * minutes * deco.rateAmbientBar!, closeTo(420, 1e-6));
    });

    test('a recorded duration without switches is flagged', () {
      final stage = _deco.copyWith(
        role: TankRole.stage,
        usageDuration: const Duration(minutes: 10),
      );
      final rows = _service.calculateCylinderSac(
        dive: _dive(tanks: [_back, stage]),
        profile: _profile,
      );

      final row = _row(rows, 'deco');
      expect(row.usageFromRecordedDuration, isTrue);
      expect(row.usageWindows, [(start: 0, end: 3600)]);
      expect(row.usageDuration, const Duration(minutes: 10));
    });

    test('a profileless dive uses its stored average depth', () {
      final dive = _dive(tanks: const [_back]);
      final rows = _service.calculateCylinderSac(dive: dive, profile: const []);

      final back = _row(rows, 'back');
      expect(back.usageWindows, [(start: 0, end: 3600)]);
      expect(
        back.rateAmbientBar,
        closeTo(dive.environment.pressureAtDepth(20), 1e-9),
      );
    });

    test('a series rate with no depth at all carries the 10 m fallback', () {
      // No profile and no stored average depth: the transmitter series rate
      // is worked out at 10 m, and the row must say so, or the role card
      // would turn it back into litres at some other depth.
      final dive = Dive(
        id: 'dive',
        diveNumber: 1,
        dateTime: DateTime.utc(2026, 10, 1, 10),
        runtime: const Duration(minutes: 60),
        tanks: const [_back],
      );
      final rows = _service.calculateCylinderSac(
        dive: dive,
        profile: const [],
        tankPressures: {
          'back': [
            for (var t = 0; t <= 3600; t += 60)
              TankPressurePoint(
                tankId: 'back',
                timestamp: t,
                pressure: 200 - 120 * t / 3600,
              ),
          ],
        },
      );

      final back = _row(rows, 'back');
      expect(back.hasTimeSeriesData, isTrue);
      expect(
        back.rateAmbientBar,
        closeTo(dive.environment.pressureAtDepth(10), 1e-9),
      );
      final minutes = back.usageDuration!.inSeconds / 60;
      // Ideal gas: 120 bar of a 12 L cylinder is 1440 L.
      expect(back.rmv! * minutes * back.rateAmbientBar!, closeTo(1440, 1e-6));
    });

    test('a row without a rate has no ambient pressure', () {
      final full = _deco.copyWith(endPressure: 200);
      final rows = _service.calculateCylinderSac(
        dive: _dive(tanks: [_back, full]),
        profile: _profile,
        gasSwitches: [_switchTo('deco', 3000)],
      );

      final row = _row(rows, 'deco');
      expect(row.sacRate, isNull);
      expect(row.rateAmbientBar, isNull);
    });

    test('a CCR bailout row carries its bailout windows', () {
      const diluent = DiveTank(
        id: 'dil',
        volume: 3,
        startPressure: 200,
        endPressure: 150,
        gasMix: GasMix(o2: 21),
        role: TankRole.diluent,
        order: 0,
      );
      const bailout = DiveTank(
        id: 'bail',
        volume: 11,
        startPressure: 200,
        endPressure: 150,
        gasMix: GasMix(o2: 21),
        role: TankRole.bailout,
        order: 1,
      );
      final dive = _dive(
        tanks: const [diluent, bailout],
        diveMode: DiveMode.ccr,
      );
      final rows = _service.calculateCylinderSac(
        dive: dive,
        profile: _profile,
        gasSwitches: [_switchTo('bail', 2400)],
      );

      final row = _row(rows, 'bail');
      expect(row.usageWindows, [(start: 2400, end: 3600)]);
      expect(row.sacRate, isNotNull);
      expect(
        row.rateAmbientBar,
        closeTo(dive.environment.pressureAtDepth(row.avgDepthDuringUse!), 1e-9),
      );
    });
  });
}
