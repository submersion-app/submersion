import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../helpers/test_database.dart';

void main() {
  late DiveRepository diveRepo;
  late TankPressureRepository tankRepo;

  setUp(() async {
    await setUpTestDatabase();
    diveRepo = DiveRepository();
    tankRepo = TankPressureRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<void> seed() async {
    await diveRepo.createDive(
      domain.Dive(
        id: 'd1',
        dateTime: DateTime.utc(2026, 7, 1, 10),
        tanks: [
          const domain.DiveTank(
            id: 'tA',
            gasMix: domain.GasMix(o2: 21, he: 0),
            order: 0,
            startPressure: 60,
            endPressure: 200,
          ),
          const domain.DiveTank(
            id: 'tB',
            gasMix: domain.GasMix(o2: 50, he: 0),
            order: 1,
          ),
        ],
      ),
    );
    await tankRepo.insertTankPressures('d1', {
      'tA': [
        (timestamp: 0, pressure: 200.0),
        (timestamp: 600, pressure: 150.0),
      ],
      'tB': [(timestamp: 0, pressure: 220.0)],
    });
  }

  test('swapTankPressureSeries exchanges the two series', () async {
    await seed();
    await tankRepo.swapTankPressureSeries(
      diveId: 'd1',
      tankIdA: 'tA',
      tankIdB: 'tB',
    );
    final byTank = await tankRepo.getTankPressuresForDive('d1');
    expect(byTank['tB']!.map((p) => p.pressure), [200.0, 150.0]);
    expect(byTank['tA']!.map((p) => p.pressure), [220.0]);
  });

  test(
    'swap moves a populated series onto an empty tank (guards no-op)',
    () async {
      // Only tA has pressure rows; tB has none. The swap should move tA's series
      // to tB (aIds non-empty) while the empty bIds branch is skipped.
      await diveRepo.createDive(
        domain.Dive(
          id: 'd2',
          dateTime: DateTime.utc(2026, 7, 2, 10),
          tanks: [
            const domain.DiveTank(
              id: 'tA',
              gasMix: domain.GasMix(o2: 21, he: 0),
              order: 0,
            ),
            const domain.DiveTank(
              id: 'tB',
              gasMix: domain.GasMix(o2: 32, he: 0),
              order: 1,
            ),
          ],
        ),
      );
      await tankRepo.insertTankPressures('d2', {
        'tA': [
          (timestamp: 0, pressure: 210.0),
          (timestamp: 300, pressure: 120.0),
        ],
      });

      await tankRepo.swapTankPressureSeries(
        diveId: 'd2',
        tankIdA: 'tA',
        tankIdB: 'tB',
      );

      final byTank = await tankRepo.getTankPressuresForDive('d2');
      expect(byTank.containsKey('tA'), isFalse); // aIds moved off tA
      expect(byTank['tB']!.map((p) => p.pressure), [210.0, 120.0]);
    },
  );

  test('reassignTankPressureSeries moves one series', () async {
    await seed();
    await tankRepo.reassignTankPressureSeries(
      diveId: 'd1',
      fromTankId: 'tB',
      toTankId: 'tA',
    );
    final byTank = await tankRepo.getTankPressuresForDive('d1');
    expect(byTank.containsKey('tB'), isFalse);
    expect(byTank['tA']!, hasLength(3));
  });

  test('updateTankRecordPressures swaps start/end on the record', () async {
    await seed();
    await diveRepo.updateTankRecordPressures(
      diveId: 'd1',
      tankId: 'tA',
      startPressure: 200,
      endPressure: 60,
    );
    final dive = (await diveRepo.getDiveById('d1'))!;
    final tA = dive.tanks.firstWhere((t) => t.id == 'tA');
    expect(tA.startPressure, 200);
    expect(tA.endPressure, 60);
  });
}
