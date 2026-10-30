import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/dive_computer_gear_identity.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/data/services/transmitter_auto_registrar.dart';
import 'package:submersion/features/transmitters/data/services/transmitter_gear_linker.dart';

import '../../../../helpers/test_database.dart';

/// A download that turns up a transmitter serial nobody registered creates
/// its Transmitter item and a registry row the diver has not configured yet
/// (issue #3676).
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd1',
            name: 'd1',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  TransmitterAutoRegistrar registrar() =>
      TransmitterAutoRegistrar(nameFor: (serial) => 'Transmitter $serial');

  Future<void> diveWithSerial(String diveId, String serial) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: diveId,
            diverId: const Value('d1'),
            diveDateTime: 0,
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 'tank-$diveId',
            diveId: diveId,
            transmitterSerial: Value(serial),
            tankRole: const Value('stage'),
          ),
        );
  }

  group('registerNewSerials', () {
    test('creates one item and one unconfigured row per new serial', () async {
      await diveWithSerial('dive1', '7C0B19');

      final created = await registrar().registerNewSerials([
        '7C0B19',
        '7C0B19',
      ], diverId: 'd1');

      expect(created, {'7C0B19'});
      final rows = await TransmitterRepository().getForDiver('d1');
      expect(rows, hasLength(1));
      final row = rows.single;
      expect(row.id, autoTransmitterRowId('d1', '7C0B19'));
      expect(row.isConfigured, isFalse);
      expect(row.label, 'Transmitter 7C0B19');
      expect(row.role.name, 'stage');
      final item = await (db.select(
        db.equipment,
      )..where((r) => r.id.equals(row.transmitterEquipmentId!))).getSingle();
      expect(item.type, 'transmitter');
      expect(item.name, 'Transmitter 7C0B19');
      expect(item.serialNumber, '7C0B19');
      expect(item.diverId, 'd1');
    });

    test('treats a serial padded with whitespace as the same serial', () async {
      await registrar().registerNewSerials(['7C0B19'], diverId: 'd1');

      final created = await registrar().registerNewSerials([
        ' 7C0B19 ',
      ], diverId: 'd1');

      expect(created, isEmpty);
      expect(await TransmitterRepository().getForDiver('d1'), hasLength(1));
    });

    test('adopts the single existing same-serial transmitter item', () async {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: 'tx-gear',
              diverId: const Value('d1'),
              name: 'My transmitter',
              type: 'transmitter',
              serialNumber: const Value('7C0B19'),
              createdAt: 0,
              updatedAt: 0,
            ),
          );

      await registrar().registerNewSerials(['7C0B19'], diverId: 'd1');

      final row = (await TransmitterRepository().getForDiver('d1')).single;
      expect(row.transmitterEquipmentId, 'tx-gear');
    });

    test('skips a serial that already has a row', () async {
      await db
          .into(db.transmitters)
          .insert(
            TransmittersCompanion.insert(
              id: 'mine',
              diverId: const Value('d1'),
              label: 'Back gas',
              tankRole: 'backGas',
              transmitterSerial: const Value('7C0B19'),
              createdAt: 0,
              updatedAt: 0,
            ),
          );

      final created = await registrar().registerNewSerials([
        '7C0B19',
      ], diverId: 'd1');

      expect(created, isEmpty);
    });

    test('stages the new row and item for sync', () async {
      await registrar().registerNewSerials(['7C0B19'], diverId: 'd1');

      final pending = await db.select(db.syncRecords).get();
      expect(
        pending.map((r) => r.entityType).toSet(),
        containsAll(['transmitters', 'equipment']),
      );
    });
  });

  test('linkSerials puts the item on every dive carrying the serial and no '
      'others', () async {
    await diveWithSerial('dive1', '7C0B19');
    await diveWithSerial('dive2', ' 7C0B19');
    await diveWithSerial('dive3', '9D0001');
    await registrar().registerNewSerials(['7C0B19'], diverId: 'd1');
    final itemId = (await TransmitterRepository().getForDiver(
      'd1',
    )).single.transmitterEquipmentId!;

    await TransmitterGearLinker().linkSerials(['7C0B19'], diverId: 'd1');

    final links = await db.select(db.diveEquipment).get();
    expect(links.map((l) => (l.diveId, l.equipmentId)).toSet(), {
      ('dive1', itemId),
      ('dive2', itemId),
    });
  });

  test('serialsNeedingSetup names unconfigured rows and rows with no '
      'cylinder', () async {
    await registrar().registerNewSerials(['7C0B19'], diverId: 'd1');
    final repo = TransmitterRepository();
    for (final (id, serial, volume) in [
      ('bare', '4A21F', null),
      ('sized', '5B0000', 11.1),
    ]) {
      await db
          .into(db.transmitters)
          .insert(
            TransmittersCompanion.insert(
              id: id,
              diverId: const Value('d1'),
              label: id,
              tankRole: 'backGas',
              transmitterSerial: Value(serial),
              volumeL: Value(volume),
              createdAt: 0,
              updatedAt: 0,
            ),
          );
    }

    expect(await repo.serialsNeedingSetup('d1'), {'7C0B19', '4A21F'});
  });

  test('itemIdForSerial finds the item through normalization', () async {
    await registrar().registerNewSerials(['7C0B19'], diverId: 'd1');

    expect(
      await TransmitterRepository().itemIdForSerial(' 7C0B19 ', diverId: 'd1'),
      transmitterGearSeedId('d1', '7C0B19'),
    );
    expect(DatabaseService.instance.database, same(db));
  });

  test('registerTransmittersForDives registers and links the serials on just '
      'those dives (#3676)', () async {
    await diveWithSerial('dive1', '7C0B19');
    await diveWithSerial('dive2', '4A21F');

    await registerTransmittersForDives(
      ['dive1'],
      registrar: registrar(),
      linker: TransmitterGearLinker(),
    );

    final rows = await TransmitterRepository().getForDiver('d1');
    expect(rows.map((r) => r.transmitterSerial), ['7C0B19']);
    final links = await db.select(db.diveEquipment).get();
    expect(links.map((l) => (l.diveId, l.equipmentId)), [
      ('dive1', rows.single.transmitterEquipmentId),
    ]);
  });
}
