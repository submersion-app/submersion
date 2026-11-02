import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/features/dive_log/data/services/gas_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/cylinder_sac.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';

const _service = GasAnalysisService(gasModel: GasModel.ideal);

const _left = DiveTank(
  id: 'left',
  volume: 7,
  startPressure: 221,
  endPressure: 220,
  gasMix: GasMix(o2: 21),
  role: TankRole.sidemountLeft,
  order: 0,
);
const _right = DiveTank(
  id: 'right',
  volume: 7,
  startPressure: 216,
  endPressure: 163,
  gasMix: GasMix(o2: 21),
  role: TankRole.sidemountRight,
  order: 1,
);
const _o2 = DiveTank(
  id: 'o2',
  volume: 1.5,
  startPressure: 174,
  endPressure: 102,
  gasMix: GasMix(o2: 100),
  role: TankRole.oxygenSupply,
  order: 2,
);

Dive _dive({
  DiveMode diveMode = DiveMode.ccr,
  List<DiveTank> tanks = const [_left, _right, _o2],
  Duration? runtime = const Duration(minutes: 60),
}) => Dive(
  id: 'dive',
  diveNumber: 1,
  dateTime: DateTime(2026, 10, 1, 10),
  maxDepth: 30,
  avgDepth: 20,
  runtime: runtime,
  diveMode: diveMode,
  tanks: tanks,
);

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
  group('calculateCylinderSac on a CCR dive', () {
    test('gives every cylinder a row, in tank order', () {
      final rows = _service.calculateCylinderSac(
        dive: _dive(),
        profile: const [],
      );
      expect(rows.map((r) => r.tankId), ['left', 'right', 'o2']);
    });

    test('loop figures carry no SAC and are not depth corrected', () {
      final rows = _service.calculateCylinderSac(
        dive: _dive(),
        profile: const [],
      );
      final o2 = _row(rows, 'o2');
      expect(o2.loopRate, closeTo(1.8, 1e-9));
      expect(o2.sacRate, isNull);
      expect(o2.hasValidSac, isFalse);
      expect(o2.gasUsedLiters, closeTo(108, 1e-9));
    });

    test('a cylinder under the minimum keeps its pressures and no rate', () {
      final rows = _service.calculateCylinderSac(
        dive: _dive(),
        profile: const [],
      );
      final left = _row(rows, 'left');
      expect(left.loopRate, isNull);
      expect(left.sacRate, isNull);
      expect(left.gasUsedLiters, closeTo(7, 1e-9));
    });

    test('a bailout reads as ordinary SAC and RMV over the bailout', () {
      final dive = _dive(tanks: const [_right]);
      final rows = _service.calculateCylinderSac(
        dive: dive,
        profile: const [
          DiveProfilePoint(timestamp: 0, depth: 15),
          DiveProfilePoint(timestamp: 3600, depth: 15),
        ],
        gasSwitches: [_switchTo('right', 3000)],
        tankPressures: const {
          'right': [
            TankPressurePoint(tankId: 'right', timestamp: 0, pressure: 216),
            TankPressurePoint(tankId: 'right', timestamp: 3000, pressure: 180),
            TankPressurePoint(tankId: 'right', timestamp: 3600, pressure: 163),
          ],
        },
      );
      final right = rows.single;
      final ambient = dive.environment.pressureAtDepth(15);
      expect(right.loopRate, closeTo(36 * 7 / 50, 1e-9));
      expect(right.rmv, closeTo(17 * 7 / 10 / ambient, 1e-6));
      expect(right.usageDuration, const Duration(minutes: 10));
      expect(right.avgDepthDuringUse, closeTo(15, 1e-9));
    });

    test('a bailout with no size falls back to a pressure rate', () {
      final dive = _dive(
        tanks: const [
          DiveTank(
            id: 'right',
            startPressure: 216,
            endPressure: 163,
            gasMix: GasMix(o2: 21),
            role: TankRole.bailout,
          ),
        ],
      );
      final rows = _service.calculateCylinderSac(
        dive: dive,
        profile: const [],
        gasSwitches: [_switchTo('right', 3000)],
      );
      final ambient = dive.environment.pressureAtDepth(20);
      expect(rows.single.sacRate, closeTo(53 / 10 / ambient, 1e-6));
      expect(rows.single.rmv, isNull);
    });

    test('a dive with no runtime still lists its cylinders', () {
      final rows = _service.calculateCylinderSac(
        dive: _dive(runtime: null),
        profile: const [],
      );
      expect(rows, hasLength(3));
      expect(rows.every((r) => r.loopRate == null), isTrue);
      expect(_row(rows, 'o2').gasUsedLiters, closeTo(108, 1e-9));
    });

    test('pressures come from the series when none were logged', () {
      final rows = _service.calculateCylinderSac(
        dive: _dive(
          tanks: const [DiveTank(id: 'd', volume: 3, role: TankRole.diluent)],
        ),
        profile: const [],
        tankPressures: const {
          'd': [
            TankPressurePoint(tankId: 'd', timestamp: 0, pressure: 200),
            TankPressurePoint(tankId: 'd', timestamp: 3600, pressure: 150),
          ],
        },
      );
      expect(rows.single.startPressure, 200);
      expect(rows.single.endPressure, 150);
      expect(rows.single.hasTimeSeriesData, isTrue);
    });
  });

  group('calculateCylinderSac on other dive modes', () {
    test('an open-circuit dive has no loop rate', () {
      final rows = _service.calculateCylinderSac(
        dive: _dive(diveMode: DiveMode.oc),
        profile: const [],
      );
      expect(rows.every((r) => r.loopRate == null), isTrue);
      expect(rows.map((r) => r.tankId), ['left', 'right']);
      expect(_row(rows, 'right').sacRate, isNotNull);
    });

    test('an SCR dive has no loop rate', () {
      final rows = _service.calculateCylinderSac(
        dive: _dive(diveMode: DiveMode.scr),
        profile: const [],
      );
      expect(rows.every((r) => r.loopRate == null), isTrue);
      expect(rows.map((r) => r.tankId), ['left', 'right']);
    });
  });
}
