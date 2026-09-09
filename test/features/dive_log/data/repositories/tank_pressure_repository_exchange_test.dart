import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/services/tank_source_index.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository diveRepo;
  late TankPressureRepository tankRepo;

  setUp(() async {
    await setUpTestDatabase();
    diveRepo = DiveRepository();
    tankRepo = TankPressureRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<void> seed({bool withSourceIndex = true}) async {
    await diveRepo.createDive(
      domain.Dive(
        id: 'd1',
        dateTime: DateTime.utc(2026, 7, 1, 10),
        tanks: [
          domain.DiveTank(
            id: 'tA',
            name: 'O2',
            gasMix: const domain.GasMix(o2: 100, he: 0),
            order: 0,
            startPressure: 200,
            endPressure: 170,
            transmitterSerial: '111',
            sourceTankIndex: withSourceIndex ? 0 : null,
          ),
          domain.DiveTank(
            id: 'tB',
            name: 'Dil',
            gasMix: const domain.GasMix(o2: 21, he: 0),
            order: 1,
            startPressure: 210,
            endPressure: 120,
            transmitterSerial: '222',
            sourceTankIndex: withSourceIndex ? 1 : null,
          ),
          const domain.DiveTank(
            id: 'tC',
            name: 'Stage',
            gasMix: domain.GasMix(o2: 50, he: 0),
            order: 2,
            startPressure: 200,
          ),
        ],
      ),
    );
    await tankRepo.insertTankPressures('d1', {
      'tA': [
        (timestamp: 0, pressure: 200.0),
        (timestamp: 600, pressure: 170.0),
      ],
      'tB': [(timestamp: 0, pressure: 210.0)],
    });
  }

  Future<Map<String, dynamic>> row(String id) async {
    final db = DatabaseService.instance.database;
    final r = await (db.select(
      db.diveTanks,
    )..where((t) => t.id.equals(id))).getSingle();
    return {
      'src': r.sourceTankIndex,
      'serial': r.transmitterSerial,
      'start': r.startPressure,
      'end': r.endPressure,
      'name': r.tankName,
    };
  }

  test(
    'swap exchanges the computer bundle and the series, not the names',
    () async {
      await seed();
      await tankRepo.exchangeTankSources(
        diveId: 'd1',
        tankIdA: 'tA',
        tankIdB: 'tB',
      );

      expect(await row('tA'), {
        'src': 1,
        'serial': '222',
        'start': 210.0,
        'end': 120.0,
        'name': 'O2',
      });
      expect(await row('tB'), {
        'src': 0,
        'serial': '111',
        'start': 200.0,
        'end': 170.0,
        'name': 'Dil',
      });
      final byTank = await tankRepo.getTankPressuresForDive('d1');
      expect(byTank['tA']!.map((p) => p.pressure), [210.0]);
      expect(byTank['tB']!.map((p) => p.pressure), [200.0, 170.0]);
    },
  );

  test('legacy rows without a source index get explicit ones', () async {
    await seed(withSourceIndex: false);
    await tankRepo.exchangeTankSources(
      diveId: 'd1',
      tankIdA: 'tA',
      tankIdB: 'tB',
    );

    expect((await row('tA'))['src'], 1);
    expect((await row('tB'))['src'], 0);
  });

  test(
    'moving onto a manual tank leaves the source with no parsed tank',
    () async {
      await seed();
      await tankRepo.exchangeTankSources(
        diveId: 'd1',
        tankIdA: 'tB',
        tankIdB: 'tC',
      );

      expect((await row('tC'))['src'], 1);
      expect((await row('tC'))['serial'], '222');
      expect((await row('tB'))['src'], kNoSourceTankIndex);
      expect((await row('tB'))['serial'], isNull);
      expect((await row('tB'))['start'], 200.0, reason: 'tC had a manual fill');
      final byTank = await tankRepo.getTankPressuresForDive('d1');
      expect(byTank.containsKey('tB'), isFalse);
      expect(byTank['tC'], hasLength(1));
    },
  );

  test('refuses a tank from another dive', () async {
    await seed();
    await diveRepo.createDive(
      domain.Dive(
        id: 'd2',
        dateTime: DateTime.utc(2026, 7, 2, 10),
        tanks: const [
          domain.DiveTank(
            id: 'other',
            gasMix: domain.GasMix(o2: 21, he: 0),
            order: 0,
          ),
        ],
      ),
    );

    await expectLater(
      tankRepo.exchangeTankSources(
        diveId: 'd1',
        tankIdA: 'tA',
        tankIdB: 'other',
      ),
      throwsA(isA<StateError>()),
    );
    expect((await row('tA'))['serial'], '111', reason: 'nothing written');
  });

  test('exchange is its own inverse', () async {
    await seed();
    await tankRepo.exchangeTankSources(
      diveId: 'd1',
      tankIdA: 'tA',
      tankIdB: 'tB',
    );
    await tankRepo.exchangeTankSources(
      diveId: 'd1',
      tankIdA: 'tA',
      tankIdB: 'tB',
    );

    expect((await row('tA'))['serial'], '111');
    expect((await row('tB'))['serial'], '222');
    final byTank = await tankRepo.getTankPressuresForDive('d1');
    expect(byTank['tA'], hasLength(2));
  });
}
