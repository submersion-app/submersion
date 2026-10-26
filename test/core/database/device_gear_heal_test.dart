import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/device_gear_heal.dart';
import 'package:submersion/core/database/dive_computer_gear_identity.dart';

import '../../helpers/test_database.dart';

/// Every registered dive computer and transmitter row gets the Equipment item
/// that is its one entry (issue #3676).
void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  const t = 1000;

  Future<void> computer(
    String id, {
    String? equipmentId,
    String manufacturer = 'Shearwater',
    String model = 'Teric',
    String? serial,
    String name = 'Shearwater Teric',
  }) => db
      .into(db.diveComputers)
      .insert(
        DiveComputersCompanion.insert(
          id: id,
          name: name,
          manufacturer: Value(manufacturer),
          model: Value(model),
          serialNumber: Value(serial),
          equipmentId: Value(equipmentId),
          createdAt: t,
          updatedAt: t,
        ),
      );

  Future<void> item(
    String id, {
    String type = 'computer',
    String? brand = 'Shearwater',
    String? model = 'Teric',
    String? serial,
    String status = 'active',
  }) => db
      .into(db.equipment)
      .insert(
        EquipmentCompanion.insert(
          id: id,
          name: id,
          type: type,
          brand: Value(brand),
          model: Value(model),
          serialNumber: Value(serial),
          status: Value(status),
          createdAt: t,
          updatedAt: t,
        ),
      );

  Future<void> tombstone(String id) => db
      .into(db.deletionLog)
      .insert(
        DeletionLogCompanion.insert(
          id: 'del-$id',
          entityType: 'equipment',
          recordId: id,
          deletedAt: t,
        ),
      );

  Future<void> transmitter(
    String id, {
    String? serial,
    String label = 'Back gas',
    String? itemId,
  }) => db
      .into(db.transmitters)
      .insert(
        TransmittersCompanion.insert(
          id: id,
          label: label,
          tankRole: 'backGas',
          transmitterSerial: Value(serial),
          transmitterEquipmentId: Value(itemId),
          createdAt: t,
          updatedAt: t,
        ),
      );

  Future<String?> linkOf(String computerId) async => (await (db.select(
    db.diveComputers,
  )..where((r) => r.id.equals(computerId))).getSingle()).equipmentId;

  Future<String?> itemOfTransmitter(String id) async => (await (db.select(
    db.transmitters,
  )..where((r) => r.id.equals(id))).getSingle()).transmitterEquipmentId;

  group('computers', () {
    test('links a computer whose twin was deleted to the one matching '
        'blank-serial item', () async {
      await item('hand-added');
      await computer('c1', serial: '3A1F22');

      await ensureDeviceGearLinks(db);

      expect(await linkOf('c1'), 'hand-added');
      final adopted = await (db.select(
        db.equipment,
      )..where((r) => r.id.equals('hand-added'))).getSingle();
      expect(adopted.serialNumber, '3A1F22');
    });

    test('mints an item for a computer with nothing to match and links its '
        'dives', () async {
      await computer('c1', serial: '3A1F22');
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: 'dive1',
              computerId: const Value('c1'),
              diveDateTime: t,
              createdAt: t,
              updatedAt: t,
            ),
          );

      final result = await ensureDeviceGearLinks(db);

      final itemId = await linkOf('c1');
      expect(itemId, diveComputerGearId('c1'));
      expect(result.computerItemsMinted, 1);
      final minted = await (db.select(
        db.equipment,
      )..where((r) => r.id.equals(itemId!))).getSingle();
      expect(minted.type, 'computer');
      expect(minted.name, 'Shearwater Teric');
      expect(minted.serialNumber, '3A1F22');
      final links = await (db.select(
        db.diveEquipment,
      )..where((r) => r.diveId.equals('dive1'))).get();
      expect(links.map((l) => l.equipmentId), [itemId]);
    });

    test('never mints at a tombstoned id', () async {
      await computer('c1');
      await tombstone(diveComputerGearId('c1'));

      await ensureDeviceGearLinks(db);

      expect(
        await linkOf('c1'),
        nextGearRemintId('c1', diveComputerGearId('c1')),
      );
    });

    test(
      'an older peer deleting the re-minted item leads to the next id',
      () async {
        final second = nextGearRemintId('c1', diveComputerGearId('c1'));
        await computer('c1');
        await tombstone(diveComputerGearId('c1'));
        await tombstone(second);

        await ensureDeviceGearLinks(db);

        expect(await linkOf('c1'), nextGearRemintId('c1', second));
      },
    );

    test(
      'two databases heal the same unlinked computer to the same id',
      () async {
        final other = createTestDatabase();
        addTearDown(other.close);
        await computer('c1');
        await other
            .into(other.diveComputers)
            .insert(
              DiveComputersCompanion.insert(
                id: 'c1',
                name: 'Shearwater Teric',
                manufacturer: const Value('Shearwater'),
                model: const Value('Teric'),
                createdAt: t,
                updatedAt: t,
              ),
            );

        await ensureDeviceGearLinks(db);
        await ensureDeviceGearLinks(other);

        final otherLink = (await (other.select(
          other.diveComputers,
        )..where((r) => r.id.equals('c1'))).getSingle()).equipmentId;
        expect(await linkOf('c1'), otherLink);
      },
    );

    test('a Retired item is adopted and a Wanted one is not', () async {
      await item('retired', status: 'retired', model: 'Teric');
      await item('wanted', status: 'wanted', model: 'Perdix');
      await computer('c1', model: 'Teric');
      await computer('c2', model: 'Perdix', name: 'Shearwater Perdix');

      await ensureDeviceGearLinks(db);

      expect(await linkOf('c1'), 'retired');
      expect(await linkOf('c2'), diveComputerGearId('c2'));
    });

    test(
      'an item already linked to another computer is not adopted by name',
      () async {
        await item('owned');
        await computer('c0', equipmentId: 'owned');
        await computer('c1');

        await ensureDeviceGearLinks(db);

        expect(await linkOf('c1'), diveComputerGearId('c1'));
      },
    );

    test('a second registration of the same serial shares its item', () async {
      await item('owned', serial: '3A1F22');
      await computer('c0', equipmentId: 'owned', serial: '3A1F22');
      await computer('c1', serial: '3A1F22');

      await ensureDeviceGearLinks(db);

      expect(await linkOf('c1'), 'owned');
    });

    test('a computer whose live item exists is left alone', () async {
      await item('mine', model: 'Perdix');
      await computer('c1', equipmentId: 'mine');

      final result = await ensureDeviceGearLinks(db);

      expect(await linkOf('c1'), 'mine');
      expect(result.computersLinked, 0);
    });
  });

  test('liveGearId follows the chain past two deletions', () async {
    final first = diveComputerGearId('c1');
    final second = nextGearRemintId('c1', first);
    await tombstone(first);
    await tombstone(second);

    expect(
      await liveGearId(db, first, 'c1', type: 'computer'),
      nextGearRemintId('c1', second),
    );
  });

  group('wrong-type links (review)', () {
    test(
      'a computer whose twin was retyped gets a computer item again',
      () async {
        // A v175 twin at the derived id, retyped by the diver before v316
        // locked the type: the computer would drop out of every list.
        await item(
          diveComputerGearId('c1'),
          type: 'instrument',
          model: 'Perdix',
        );
        await computer('c1', equipmentId: diveComputerGearId('c1'));

        await ensureDeviceGearLinks(db);

        final linked = await linkOf('c1');
        expect(linked, isNot(diveComputerGearId('c1')));
        final row = await (db.select(
          db.equipment,
        )..where((r) => r.id.equals(linked!))).getSingle();
        expect(row.type, 'computer');
        final retyped = await (db.select(
          db.equipment,
        )..where((r) => r.id.equals(diveComputerGearId('c1')))).getSingle();
        expect(
          retyped.type,
          'instrument',
          reason: "the diver's item is left alone",
        );
      },
    );

    test('a transmitter row linked to an item of another type gets its own '
        'item', () async {
      await item('cyl', type: 'tank');
      await transmitter('tx1', serial: '4A21F', itemId: 'cyl');

      await ensureDeviceGearLinks(db);

      final linked = await itemOfTransmitter('tx1');
      final row = await (db.select(
        db.equipment,
      )..where((r) => r.id.equals(linked!))).getSingle();
      expect(row.type, 'transmitter');
    });
  });

  group('transmitters', () {
    test('a row with no item adopts the one same-serial item, through '
        'normalization', () async {
      await item('tx-gear', type: 'transmitter', serial: ' 4A21F ');
      await transmitter('tx1', serial: '4A21F');

      await ensureDeviceGearLinks(db);

      expect(await itemOfTransmitter('tx1'), 'tx-gear');
    });

    test(
      'a row with no item mints one carrying its serial and label',
      () async {
        await transmitter('tx1', serial: '4A21F', label: 'Back gas AL80');

        final result = await ensureDeviceGearLinks(db);

        final itemId = await itemOfTransmitter('tx1');
        expect(itemId, transmitterGearSeedId(null, '4A21F'));
        expect(result.transmitterItemsMinted, 1);
        final minted = await (db.select(
          db.equipment,
        )..where((r) => r.id.equals(itemId!))).getSingle();
        expect(minted.type, 'transmitter');
        expect(minted.name, 'Back gas AL80');
        expect(minted.serialNumber, '4A21F');
      },
    );

    test('a minted item joins the dives whose tanks carry its serial, as a '
        'minted computer item joins its dives (review)', () async {
      for (final (dive, serial) in [('dive1', ' 4A21F '), ('dive2', '9Z9')]) {
        await db
            .into(db.dives)
            .insert(
              DivesCompanion.insert(
                id: dive,
                diveDateTime: t,
                createdAt: t,
                updatedAt: t,
              ),
            );
        await db
            .into(db.diveTanks)
            .insert(
              DiveTanksCompanion.insert(
                id: 'tank-$dive',
                diveId: dive,
                transmitterSerial: Value(serial),
              ),
            );
      }
      await transmitter('tx1', serial: '4A21F');

      await ensureDeviceGearLinks(db);

      final links = await db.select(db.diveEquipment).get();
      expect(
        [for (final l in links) (l.diveId, l.equipmentId)],
        [('dive1', transmitterGearSeedId(null, '4A21F'))],
      );
    });

    test('a row without a serial still gets its own item', () async {
      await transmitter('tx1', label: 'Channel 2');

      await ensureDeviceGearLinks(db);

      expect(await itemOfTransmitter('tx1'), isNotNull);
    });

    test('an item with a blank serial gets the row serial', () async {
      await item('tx-gear', type: 'transmitter', serial: null);
      await transmitter('tx1', serial: '4A21F', itemId: 'tx-gear');
      await (db.delete(
        db.equipment,
      )..where((r) => r.id.equals('tx-gear'))).go();
      await item(
        transmitterGearSeedId(null, '4A21F'),
        type: 'transmitter',
        serial: null,
      );

      await ensureDeviceGearLinks(db);

      final adopted =
          await (db.select(db.equipment)..where(
                (r) => r.id.equals(transmitterGearSeedId(null, '4A21F')),
              ))
              .getSingle();
      expect(adopted.serialNumber, '4A21F');
    });
  });

  test('running twice changes nothing the second time', () async {
    await computer('c1');
    await transmitter('tx1', serial: '4A21F');

    await ensureDeviceGearLinks(db);
    final second = await ensureDeviceGearLinks(db);

    expect(second.computersLinked, 0);
    expect(second.computerItemsMinted, 0);
    expect(second.transmittersLinked, 0);
    expect(second.transmitterItemsMinted, 0);
  });

  test('leaves every row it changes for the next sync to publish, so a '
      'fleet that healed from different states converges (review)', () async {
    await item('hand-added');
    await computer('c1', serial: '3A1F22');
    await computer('c2', model: 'Perdix', name: 'Shearwater Perdix');
    await transmitter('tx1', serial: '4A21F');
    for (final table in ['dive_computers', 'transmitters', 'equipment']) {
      await db.customStatement("UPDATE $table SET hlc = 'old-clock'");
    }

    await ensureDeviceGearLinks(db);

    Future<String?> hlcOf(String table, String id) async =>
        (await db
                .customSelect(
                  'SELECT hlc FROM $table WHERE id = ?',
                  variables: [Variable<String>(id)],
                )
                .getSingle())
            .read<String?>('hlc');
    expect(await hlcOf('dive_computers', 'c1'), isNull);
    expect(await hlcOf('dive_computers', 'c2'), isNull);
    expect(await hlcOf('transmitters', 'tx1'), isNull);
    expect(
      await hlcOf('equipment', 'hand-added'),
      isNull,
      reason: 'its serial was filled',
    );
    expect(await hlcOf('equipment', diveComputerGearId('c2')), isNull);

    await SyncRepository(database: db).backfillMissingHlc();

    final pending = await db.select(db.syncRecords).get();
    expect(
      pending.map((r) => '${r.entityType}/${r.recordId}').toSet(),
      containsAll([
        'diveComputers/c1',
        'diveComputers/c2',
        'transmitters/tx1',
        'equipment/hand-added',
        'equipment/${diveComputerGearId('c2')}',
      ]),
    );
  });
}
