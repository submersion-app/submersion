import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_import/data/services/dive_reimport_service.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';

import '../../../../helpers/test_database.dart';

/// A resync gives an Avelo dive imported from Shearwater Cloud before the
/// Hydrotank role (issue #4657) its Hydrotank, by the rule re-parse uses
/// (issue #4665): the stored database is re-read, and its Hydrotank tag
/// replaces a stored back gas.
void main() {
  late AppDatabase db;
  late DiveReimportService service;
  const diveId = 'dive-1';

  setUp(() async {
    db = await setUpTestDatabase();
    service = DiveReimportService(db: db);
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('diver1', 'A', 1, 1)",
    );
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: diveId,
            diveDateTime: 1000,
            createdAt: 1000,
            updatedAt: 1000,
          ).copyWith(diverId: const Value('diver1')),
        );
  });

  tearDown(tearDownTestDatabase);

  Future<void> seedTank({required String role, String? roleSource}) => db
      .into(db.diveTanks)
      .insert(
        DiveTanksCompanion.insert(
          id: 'tank-a',
          diveId: diveId,
          tankOrder: const Value(0),
          startPressure: const Value(200),
          tankRole: Value(role),
          roleSource: Value(roleSource),
        ),
      );

  Future<void> resync(List<Map<String, dynamic>> tanks) =>
      service.applyReimport(
        diveId: diveId,
        diveData: {'tanks': tanks},
        now: DateTime(2026, 11, 27),
      );

  Future<DiveTank> stored() => (db.select(
    db.diveTanks,
  )..where((t) => t.id.equals('tank-a'))).getSingle();

  Future<DiveTank> gained() => (db.select(
    db.diveTanks,
  )..where((t) => t.tankOrder.equals(1))).getSingle();

  test(
    'a stored back gas the file tags as the Hydrotank becomes one',
    () async {
      await seedTank(role: 'backGas');

      await resync([
        {'order': 0, 'startPressure': 200.0, 'role': 'hydrotank'},
      ]);

      final tank = await stored();
      expect(tank.tankRole, 'hydrotank');
      expect(tank.roleSource, isNull);
    },
  );

  test('another stored role stays', () async {
    await seedTank(role: 'pony');

    await resync([
      {'order': 0, 'startPressure': 200.0, 'role': 'hydrotank'},
    ]);

    expect((await stored()).tankRole, 'pony');
  });

  test(
    'a cylinder paired only by position must be the same cylinder',
    () async {
      // The diver removed the Hydrotank, so the file's Hydrotank (Shearwater
      // Cloud tanks carry no order) pairs by position with the pony.
      await db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion.insert(
              id: 'pony',
              diveId: diveId,
              tankOrder: const Value(1),
              startPressure: const Value(150),
            ),
          );

      await resync([
        {'startPressure': 200.0, 'role': 'hydrotank'},
        {'startPressure': 150.0},
      ]);

      final pony = await (db.select(
        db.diveTanks,
      )..where((t) => t.id.equals('pony'))).getSingle();
      expect(pony.tankRole, 'backGas');
    },
  );

  test(
    'a start pressure the import deglitched still names the cylinder',
    () async {
      // The file's start pressure is a 0 bar lead-in reading, which the
      // import replaced with the series' first reading while it took the
      // Hydrotank for back gas; resync reads the file's own value.
      await seedTank(role: 'backGas');

      await service.applyReimport(
        diveId: diveId,
        diveData: {
          'tanks': [
            {'startPressure': 0.0, 'endPressure': 185.0, 'role': 'hydrotank'},
          ],
          'profile': [
            for (final (t, bar) in [(0, 200.0), (60, 195.0), (1200, 185.0)])
              {
                'timestamp': t,
                'depth': 10.0,
                'allTankPressures': [
                  {'tankIndex': 0, 'pressure': bar},
                ],
              },
          ],
        },
        now: DateTime(2026, 11, 27),
      );

      expect((await stored()).tankRole, 'hydrotank');
    },
  );

  test('equal counts do not make a different cylinder the same one', () async {
    // The diver removed the Hydrotank and added another cylinder, so the
    // dive still holds two and the pony now sits where the Hydrotank was.
    for (final (id, order, bar) in [('pony', 0, 150), ('added', 1, 230)]) {
      await db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion.insert(
              id: id,
              diveId: diveId,
              tankOrder: Value(order),
              startPressure: Value(bar.toDouble()),
            ),
          );
    }

    await resync([
      {'startPressure': 200.0, 'role': 'hydrotank'},
      {'startPressure': 150.0},
    ]);

    final pony = await (db.select(
      db.diveTanks,
    )..where((t) => t.id.equals('pony'))).getSingle();
    expect(pony.tankRole, 'backGas');
  });

  Future<void> seedAt(String id, int order, double bar) => db
      .into(db.diveTanks)
      .insert(
        DiveTanksCompanion.insert(
          id: id,
          diveId: diveId,
          tankOrder: Value(order),
          startPressure: Value(bar),
        ),
      );

  Future<String> roleOf(String id) async => (await (db.select(
    db.diveTanks,
  )..where((t) => t.id.equals(id))).getSingle()).tankRole;

  test('a start pressure another cylinder shares names neither', () async {
    // The Hydrotank and the pony were both filled to 200 bar, and the diver
    // removed the Hydrotank: the pony's 200 bar matches both of the file's
    // tanks, so nothing says it is the Hydrotank.
    await seedAt('pony', 1, 200);

    await resync([
      {'startPressure': 200.0, 'role': 'hydrotank'},
      {'startPressure': 200.0},
    ]);

    expect(await roleOf('pony'), 'backGas');
  });

  test('cylinders sharing a pressure pair in order when all line up', () async {
    // Nothing was removed or added, and every pair agrees: the order settles
    // two cylinders filled to the same pressure, as Cloud import pairs them.
    await seedAt('first', 0, 200);
    await seedAt('second', 1, 200);

    await resync([
      {'startPressure': 200.0, 'role': 'hydrotank'},
      {'startPressure': 200.0},
    ]);

    expect(await roleOf('first'), 'hydrotank');
    expect(await roleOf('second'), 'backGas');
  });

  test('a stored serial names the cylinder whatever its pressure', () async {
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 'tank-a',
            diveId: diveId,
            tankOrder: const Value(0),
            startPressure: const Value(180),
            transmitterSerial: const Value('76287'),
          ),
        );

    await resync([
      {
        'startPressure': 200.0,
        'transmitterSerial': '76287',
        'role': 'hydrotank',
      },
    ]);

    expect((await stored()).tankRole, 'hydrotank');
  });

  test('a name-derived back gas is left to its own rule', () async {
    await seedTank(role: 'backGas', roleSource: 'transmitterName');

    await resync([
      {'order': 0, 'startPressure': 200.0, 'role': 'hydrotank'},
    ]);

    expect((await stored()).tankRole, 'backGas');
  });

  test('a file without a Hydrotank changes nothing', () async {
    await seedTank(role: 'backGas');

    await resync([
      {'order': 0, 'startPressure': 200.0, 'role': 'backGas'},
    ]);
    expect((await stored()).tankRole, 'backGas');

    await resync([
      {'order': 0, 'startPressure': 200.0},
    ]);
    expect((await stored()).tankRole, 'backGas');
  });

  test('a cylinder the file gained takes the file\'s role', () async {
    await seedTank(role: 'backGas');

    await resync([
      {'order': 0, 'startPressure': 200.0},
      {'order': 1, 'startPressure': 190.0, 'role': TankRole.hydrotank},
    ]);

    expect((await gained()).tankRole, 'hydrotank');
  });

  test('a cylinder the file gained with an unknown role is back gas', () async {
    await seedTank(role: 'backGas');

    await resync([
      {'order': 0, 'startPressure': 200.0},
      {'order': 1, 'startPressure': 190.0, 'role': 'futureRole'},
    ]);

    expect((await gained()).tankRole, 'backGas');
  });

  test('a transmitter the diver set up does not undo the Hydrotank', () async {
    await TransmitterRepository().create(
      Transmitter(
        id: 'tx',
        diverId: 'diver1',
        transmitterSerial: '76287',
        label: 'T1',
        role: TankRole.sidemountLeft,
        volumeL: 10,
        createdAt: DateTime.utc(2026, 11, 1),
        updatedAt: DateTime.utc(2026, 11, 1),
      ),
    );
    await seedTank(role: 'backGas');

    await resync([
      {
        'order': 0,
        'startPressure': 200.0,
        'transmitterSerial': '76287',
        'role': 'hydrotank',
      },
    ]);

    expect((await stored()).tankRole, 'hydrotank');
  });
}
