import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_import/data/services/dive_reimport_service.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';

import '../../../../helpers/test_database.dart';

/// A resync gives a stored cylinder the transmitter serial its file now
/// yields, so a Shearwater Cloud import from before #4388 can be repaired
/// from its stored file, and the diver's setup for that transmitter follows.
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

  Future<void> seedTank(String id, int order, {String? serial}) => db
      .into(db.diveTanks)
      .insert(
        DiveTanksCompanion.insert(
          id: id,
          diveId: diveId,
          tankOrder: Value(order),
          startPressure: const Value(200),
          transmitterSerial: Value(serial),
        ),
      );

  Future<void> resync(List<Map<String, dynamic>> tanks) =>
      service.applyReimport(
        diveId: diveId,
        diveData: {'tanks': tanks},
        now: DateTime(2026, 11, 9),
      );

  Future<DiveTank> row(String id) =>
      (db.select(db.diveTanks)..where((t) => t.id.equals(id))).getSingle();

  test('fills the serial a stored cylinder lacks', () async {
    await seedTank('tank-a', 0);

    await resync([
      {'order': 0, 'startPressure': 200.0, 'transmitterSerial': '76287'},
    ]);

    expect((await row('tank-a')).transmitterSerial, '76287');
  });

  test(
    'a cylinder paired only by position must agree on start pressure',
    () async {
      // The diver removed a cylinder, so the file's first tank now pairs by
      // position with what was its second.
      await db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion.insert(
              id: 'tank-b',
              diveId: diveId,
              tankOrder: const Value(0),
              startPressure: const Value(150),
            ),
          );

      await resync([
        {'startPressure': 200.0, 'transmitterSerial': '76287'},
        {'startPressure': 150.0, 'transmitterSerial': '76290'},
      ]);

      expect((await row('tank-b')).transmitterSerial, isNull);
    },
  );

  test('a serial the diver has never seen gets its Transmitter item '
      '(#3676)', () async {
    await seedTank('tank-a', 0);

    await resync([
      {'order': 0, 'startPressure': 200.0, 'transmitterSerial': '76287'},
    ]);

    final rows = await db.select(db.transmitters).get();
    expect(rows.single.transmitterSerial, '76287');
    expect(rows.single.isConfigured, isFalse);
  });

  test('keeps a serial the cylinder already has', () async {
    await seedTank('tank-a', 0, serial: '11111');

    await resync([
      {'order': 0, 'startPressure': 200.0, 'transmitterSerial': '76287'},
    ]);

    expect((await row('tank-a')).transmitterSerial, '11111');
  });

  test('a cylinder the file gained arrives with its serial', () async {
    await seedTank('tank-a', 0);

    await resync([
      {'order': 0, 'startPressure': 200.0},
      {'order': 1, 'startPressure': 190.0, 'transmitterSerial': '76290'},
    ]);

    final added = await (db.select(
      db.diveTanks,
    )..where((t) => t.tankOrder.equals(1))).getSingle();
    expect(added.transmitterSerial, '76290');
  });

  test('the setup of a transmitter the diver set up follows', () async {
    await TransmitterRepository().create(
      Transmitter(
        id: 'tx',
        diverId: 'diver1',
        transmitterSerial: '76287',
        label: 'T2',
        role: TankRole.sidemountLeft,
        volumeL: 10,
        createdAt: DateTime.utc(2026, 11, 1),
        updatedAt: DateTime.utc(2026, 11, 1),
      ),
    );
    await seedTank('tank-a', 0);

    await resync([
      {'order': 0, 'startPressure': 200.0, 'transmitterSerial': '76287'},
    ]);

    final tank = await row('tank-a');
    expect(tank.tankRole, 'sidemountLeft');
    expect(tank.volume, 10);
    expect(tank.tankName, 'T2');
  });
}
