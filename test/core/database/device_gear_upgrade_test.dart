import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/device_gear_heal.dart';
import 'package:submersion/core/database/device_gear_upgrade.dart';
import 'package:submersion/core/database/dive_computer_gear_identity.dart';

import '../../helpers/test_database.dart';

/// The ladder-only v316 steps (issue #3676).
void main() {
  late AppDatabase db;

  setUp(() async {
    db = createTestDatabase();
    for (final id in ['d1', 'd2']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: 0,
              updatedAt: 0,
            ),
          );
    }
  });
  tearDown(() => db.close());

  Future<void> linkedPair({
    String? manufacturer,
    String? model,
    String? brand,
    String? itemModel,
    required String computerName,
    required int computerUpdated,
    required String computerNotes,
    required String itemName,
    required int itemUpdated,
    required String itemNotes,
  }) async {
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'gear',
            name: itemName,
            type: 'computer',
            brand: Value(brand),
            model: Value(itemModel),
            notes: Value(itemNotes),
            createdAt: 0,
            updatedAt: itemUpdated,
          ),
        );
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: 'c1',
            name: computerName,
            manufacturer: Value(manufacturer),
            model: Value(model),
            notes: Value(computerNotes),
            equipmentId: const Value('gear'),
            createdAt: 0,
            updatedAt: computerUpdated,
          ),
        );
  }

  Future<
    ({
      String computerName,
      String computerNotes,
      String itemName,
      String itemNotes,
    })
  >
  pair() async {
    final c = await (db.select(
      db.diveComputers,
    )..where((r) => r.id.equals('c1'))).getSingle();
    final e = await (db.select(
      db.equipment,
    )..where((r) => r.id.equals('gear'))).getSingle();
    return (
      computerName: c.name,
      computerNotes: c.notes,
      itemName: e.name,
      itemNotes: e.notes,
    );
  }

  group('alignComputerNamesAndNotes', () {
    test('a name the diver gave the item survives a later download '
        '(review, #3676)', () async {
      // Every download bumps the computer's updated_at, so a timestamp rule
      // would hand the item the device's own name back.
      await linkedPair(
        manufacturer: 'Shearwater',
        model: 'Teric',
        computerName: 'Shearwater Teric',
        computerUpdated: 50,
        computerNotes: '',
        brand: 'Shearwater',
        itemModel: 'Teric',
        itemName: 'Teric (yellow)',
        itemUpdated: 10,
        itemNotes: '',
      );

      await alignComputerNamesAndNotes(db);

      final p = await pair();
      expect(p.itemName, 'Teric (yellow)');
      expect(p.computerName, 'Teric (yellow)');
    });

    test('a name given in the old computer dialog survives an unrelated item '
        'edit (review, #3676)', () async {
      await linkedPair(
        manufacturer: 'Shearwater',
        model: 'Teric',
        computerName: 'My Teric',
        computerUpdated: 10,
        computerNotes: '',
        brand: 'Shearwater',
        itemModel: 'Teric',
        itemName: 'Shearwater Teric',
        itemUpdated: 50,
        itemNotes: '',
      );

      await alignComputerNamesAndNotes(db);

      final p = await pair();
      expect(p.itemName, 'My Teric');
      expect(p.computerName, 'My Teric');
    });

    test('when both were renamed the item keeps its name', () async {
      await linkedPair(
        manufacturer: 'Shearwater',
        model: 'Teric',
        computerName: 'Old wrist unit',
        computerUpdated: 50,
        computerNotes: '',
        brand: 'Shearwater',
        itemModel: 'Teric',
        itemName: 'Teric (yellow)',
        itemUpdated: 10,
        itemNotes: '',
      );

      await alignComputerNamesAndNotes(db);

      expect((await pair()).itemName, 'Teric (yellow)');
    });

    test('blank item notes take the computer notes', () async {
      await linkedPair(
        computerName: 'Teric',
        computerUpdated: 10,
        computerNotes: 'Left wrist.',
        itemName: 'Teric',
        itemUpdated: 10,
        itemNotes: '',
      );

      await alignComputerNamesAndNotes(db);

      final p = await pair();
      expect(p.itemNotes, 'Left wrist.');
      expect(p.computerNotes, 'Left wrist.');
    });

    test('differing notes are both kept, the computer notes below', () async {
      await linkedPair(
        computerName: 'Teric',
        computerUpdated: 10,
        computerNotes: 'Left wrist.',
        itemName: 'Teric',
        itemUpdated: 10,
        itemNotes: 'Bought in Cozumel.',
      );

      await alignComputerNamesAndNotes(db);

      final p = await pair();
      expect(p.itemNotes, 'Bought in Cozumel.\n\nLeft wrist.');
      expect(p.computerNotes, p.itemNotes);
    });

    test('two registrations sharing one item both keep their notes '
        '(review)', () async {
      await linkedPair(
        computerName: 'Teric',
        computerUpdated: 10,
        computerNotes: 'Left wrist.',
        itemName: 'Teric',
        itemUpdated: 10,
        itemNotes: '',
      );
      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion.insert(
              id: 'c2',
              name: 'Teric',
              notes: const Value('Strap replaced.'),
              equipmentId: const Value('gear'),
              createdAt: 0,
              updatedAt: 10,
            ),
          );

      await alignComputerNamesAndNotes(db);

      final notes = (await pair()).itemNotes;
      expect(notes, contains('Left wrist.'));
      expect(notes, contains('Strap replaced.'));
    });

    test('equal notes are kept once', () async {
      await linkedPair(
        computerName: 'Teric',
        computerUpdated: 10,
        computerNotes: 'Left wrist.',
        itemName: 'Teric',
        itemUpdated: 10,
        itemNotes: 'Left wrist.',
      );

      await alignComputerNamesAndNotes(db);

      expect((await pair()).itemNotes, 'Left wrist.');
    });
  });

  Future<void> diveWithSerial(
    String diveId,
    String diverId,
    String serial, {
    String role = 'stage',
  }) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: diveId,
            diverId: Value(diverId),
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
            tankRole: Value(role),
          ),
        );
  }

  group('registerUnassignedSerials', () {
    test('registers a serial as a not-configured row with its item', () async {
      await diveWithSerial('dive1', 'd1', ' 7C0B19 ');

      final created = await registerUnassignedSerials(db);

      expect(created, 1);
      final row =
          await (db.select(db.transmitters)..where(
                (r) => r.id.equals(autoTransmitterRowId('d1', '7C0B19')),
              ))
              .getSingle();
      expect(row.isConfigured, isFalse);
      expect(row.transmitterSerial, '7C0B19');
      expect(row.diverId, 'd1');
      expect(row.tankRole, 'stage');
      expect(row.label, 'Transmitter 7C0B19');
      expect(row.transmitterEquipmentId, transmitterGearSeedId('d1', '7C0B19'));
      final item = await (db.select(
        db.equipment,
      )..where((r) => r.id.equals(row.transmitterEquipmentId!))).getSingle();
      expect(item.type, 'transmitter');
      expect(item.serialNumber, '7C0B19');
      expect(item.diverId, 'd1');
    });

    test('skips a serial whose row a peer already deleted', () async {
      // A peer upgraded first, registered the serial and the diver deleted
      // it there; this device applied the tombstone before it upgraded.
      await diveWithSerial('dive1', 'd1', '7C0B19');
      await db
          .into(db.deletionLog)
          .insert(
            DeletionLogCompanion.insert(
              id: 'tomb',
              entityType: 'transmitters',
              recordId: autoTransmitterRowId('d1', '7C0B19'),
              deletedAt: 1,
            ),
          );

      expect(await registerUnassignedSerials(db), 0);
      expect(await db.select(db.transmitters).get(), isEmpty);
      expect(
        await (db.select(
          db.equipment,
        )..where((e) => e.type.equals('transmitter'))).get(),
        isEmpty,
      );
    });

    test('skips a serial the diver already registered', () async {
      await diveWithSerial('dive1', 'd1', '4A21F');
      await db
          .into(db.transmitters)
          .insert(
            TransmittersCompanion.insert(
              id: 'mine',
              diverId: const Value('d1'),
              label: 'Back gas',
              tankRole: 'backGas',
              transmitterSerial: const Value('4A21F'),
              createdAt: 0,
              updatedAt: 0,
            ),
          );

      expect(await registerUnassignedSerials(db), 0);
    });

    test('a serial another diver registered is still registered for this '
        'diver', () async {
      await diveWithSerial('dive1', 'd1', '4A21F');
      await db
          .into(db.transmitters)
          .insert(
            TransmittersCompanion.insert(
              id: 'theirs',
              diverId: const Value('d2'),
              label: 'Back gas',
              tankRole: 'backGas',
              transmitterSerial: const Value('4A21F'),
              createdAt: 0,
              updatedAt: 0,
            ),
          );

      expect(await registerUnassignedSerials(db), 1);
    });

    test('adopts the one same-serial transmitter item the diver has', () async {
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
      await diveWithSerial('dive1', 'd1', '7C0B19');

      await registerUnassignedSerials(db);

      final row =
          await (db.select(db.transmitters)..where(
                (r) => r.id.equals(autoTransmitterRowId('d1', '7C0B19')),
              ))
              .getSingle();
      expect(row.transmitterEquipmentId, 'tx-gear');
    });
  });

  test('linkTransmitterGearToDives puts each item on the dives carrying its '
      'serial and no others', () async {
    await diveWithSerial('dive1', 'd1', '4A21F');
    await diveWithSerial('dive2', 'd1', '9D0001');
    await db
        .into(db.transmitters)
        .insert(
          TransmittersCompanion.insert(
            id: 'mine',
            diverId: const Value('d1'),
            label: 'Back gas',
            tankRole: 'backGas',
            transmitterSerial: const Value(' 4A21F'),
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await ensureDeviceGearLinks(db);
    final itemId = (await (db.select(
      db.transmitters,
    )..where((r) => r.id.equals('mine'))).getSingle()).transmitterEquipmentId!;

    await linkTransmitterGearToDives(db);

    final links = await db.select(db.diveEquipment).get();
    expect(links.map((l) => (l.diveId, l.equipmentId)), [('dive1', itemId)]);
  });
}
