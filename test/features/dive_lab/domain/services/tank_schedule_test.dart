import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_request.dart';
import 'package:submersion/features/dive_lab/domain/services/tank_schedule.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

const back = DiveTank(
  id: 'back',
  volume: 24,
  startPressure: 200,
  gasMix: GasMix(o2: 21),
  role: TankRole.backGas,
);
const deco50 = DiveTank(
  id: 'deco50',
  volume: 11.1,
  startPressure: 200,
  gasMix: GasMix(o2: 50),
  role: TankRole.deco,
);
const o2 = DiveTank(
  id: 'o2',
  volume: 7,
  startPressure: 200,
  gasMix: GasMix(o2: 100),
  role: TankRole.deco,
);

void main() {
  group('TankSchedule.fromDive', () {
    test('starts on the back gas and follows switches in time order', () {
      final s = TankSchedule.fromDive(
        tanks: const [deco50, back],
        switches: const [
          ScenarioGasSwitch(timestamp: 1800, tankId: 'deco50'),
          ScenarioGasSwitch(timestamp: 1500, tankId: 'back'), // no-op
        ],
      );
      expect(s.tankIdAt(0), 'back');
      expect(s.tankIdAt(1799), 'back');
      expect(s.tankIdAt(1800), 'deco50');
      expect(s.intervals, hasLength(2));
    });

    test('no tanks yields an air schedule', () {
      final s = TankSchedule.fromDive(tanks: const [], switches: const []);
      expect(s.tankIdAt(100), isNull);
      expect(s.mixAt(100).isAir, isTrue);
      expect(s.toGasSegments().single.fN2, airN2Fraction);
    });

    test('gas segments mirror the schedule', () {
      final s = TankSchedule.fromDive(
        tanks: const [back, deco50],
        switches: const [ScenarioGasSwitch(timestamp: 1800, tankId: 'deco50')],
      );
      final segs = s.toGasSegments();
      expect(segs[0].startTimestamp, 0);
      expect(segs[0].fN2, airN2Fraction);
      expect(segs[1].startTimestamp, 1800);
      expect(segs[1].fN2, closeTo(0.5, 1e-9));
    });

    test('switchedTo inserts an interval at T and keeps later switches', () {
      final s = TankSchedule.fromDive(
        tanks: const [back, deco50, o2],
        switches: const [
          ScenarioGasSwitch(timestamp: 1800, tankId: 'deco50'),
          ScenarioGasSwitch(timestamp: 2400, tankId: 'o2'),
        ],
      );
      final r = s.switchedTo('deco50', fromTimestamp: 1600);
      expect(r.tankIdAt(1599), 'back');
      expect(r.tankIdAt(1600), 'deco50');
      expect(r.tankIdAt(1800), 'deco50');
      expect(r.tankIdAt(2400), 'o2');
      // Consecutive identical intervals collapse.
      expect(r.intervals.map((i) => i.tankId), ['back', 'deco50', 'o2']);
    });
  });

  group('bestTankForDepth', () {
    test('prefers the richest eligible mix at the deco ppO2', () {
      expect(
        bestTankForDepth(const [back, deco50, o2], 21.0, maxPpO2: 1.6)?.id,
        'deco50',
      );
      expect(
        bestTankForDepth(const [back, deco50, o2], 6.0, maxPpO2: 1.6)?.id,
        'o2',
      );
      expect(
        bestTankForDepth(const [back, deco50, o2], 30.0, maxPpO2: 1.6)?.id,
        'back',
      );
    });

    test('falls back to back gas when nothing is eligible', () {
      expect(
        bestTankForDepth(const [deco50, back], 80.0, maxPpO2: 1.6)?.id,
        'back',
      );
      expect(bestTankForDepth(const [], 10.0, maxPpO2: 1.6), isNull);
    });
  });

  group('substituteTankByDepth', () {
    test('replaces the lost tank after T with the best remaining gas', () {
      // 10 s samples: 21 m from 1800 to 2100, then 6 m from 2100 to 2400.
      final timestamps = <int>[];
      final depths = <double>[];
      for (var t = 0; t <= 2400; t += 10) {
        timestamps.add(t);
        depths.add(t < 1800 ? 40.0 : (t < 2100 ? 21.0 : 6.0));
      }
      final s = TankSchedule.fromDive(
        tanks: const [back, deco50, o2],
        switches: const [ScenarioGasSwitch(timestamp: 1800, tankId: 'deco50')],
      );
      final r = substituteTankByDepth(
        s,
        lostTankId: 'deco50',
        fromTimestamp: 1700,
        timestamps: timestamps,
        depths: depths,
        maxPpO2: 1.6,
      );
      expect(r.tanks.map((t) => t.id), isNot(contains('deco50')));
      expect(r.tankIdAt(1800), 'back'); // 21 m: O2 not eligible, 50% gone
      expect(r.tankIdAt(2100), 'o2'); // 6 m: O2 eligible
    });
  });
}
