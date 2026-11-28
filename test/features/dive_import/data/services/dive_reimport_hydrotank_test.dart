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

  /// Resyncs one Hydrotank whose file start is [start], with [series] as
  /// its pressure readings (seconds, bar).
  Future<void> resyncWithSeries({
    required double start,
    required List<(int, double)> series,
  }) => service.applyReimport(
    diveId: diveId,
    diveData: {
      'tanks': [
        {
          'startPressure': start,
          'endPressure': series.last.$2,
          'role': 'hydrotank',
        },
      ],
      'profile': [
        for (final (t, bar) in series)
          {
            'timestamp': t,
            'depth': 10.0,
            'allTankPressures': [
              {'tankIndex': 0, 'pressure': bar},
            ],
          },
      ],
    },
    now: DateTime(2026, 11, 28),
  );

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
    'a start pressure the import deglitched as back gas names the cylinder',
    () async {
      // The diver's first pump-in reads as a lead-in 50 bar below the next
      // reading. The import, taking the Hydrotank for back gas, replaced
      // that start with 200 bar; resync, reading it as the Hydrotank, keeps
      // the real 150 bar, so only the back-gas view matches what is stored.
      await seedTank(role: 'backGas');

      await resyncWithSeries(
        start: 150,
        series: [
          (0, 150.0),
          (30, 150.0),
          (150, 200.0),
          (300, 199.0),
          (600, 198.0),
          (900, 197.0),
          (1200, 185.0),
        ],
      );

      final tank = await stored();
      expect(tank.tankRole, 'hydrotank');
      expect(tank.startPressure, 150.0);
    },
  );

  test('a raw start pressure the import stored names the cylinder', () async {
    // An import from before the pressure clean-up (issue #2441) stored
    // the file's 0 bar header start as it was; resync cleans it to 200 bar.
    await seedAt('tank-a', 0, 0);

    await resyncWithSeries(
      start: 0,
      series: [(0, 200.0), (60, 195.0), (1200, 185.0)],
    );

    expect((await stored()).tankRole, 'hydrotank');
  });

  test('slot order does not hold where serials say the order is off', () async {
    // The diver reordered the cylinders: the Hydrotank, whose serial is
    // stored, now sits second, and the pony first with no serial.
    await seedAt('pony', 0, 200);
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 'hydro',
            diveId: diveId,
            tankOrder: const Value(1),
            startPressure: const Value(200),
            transmitterSerial: const Value('222'),
          ),
        );

    await resync([
      {'startPressure': 200.0, 'transmitterSerial': '222', 'role': 'hydrotank'},
      {'startPressure': 200.0, 'transmitterSerial': '111'},
    ]);

    expect(await roleOf('pony'), 'backGas');
  });

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
