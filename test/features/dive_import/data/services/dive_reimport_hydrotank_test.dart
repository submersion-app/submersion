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
