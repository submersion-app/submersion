import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_merge_repository.dart';

import '../../../../helpers/test_database.dart';

/// Merging duplicate computers keeps their channel-only transmitter keys,
/// on the surviving record (issue #3676).
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
    for (final id in ['survivor', 'duplicate']) {
      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion.insert(
              id: id,
              diverId: const Value('d1'),
              name: id,
              createdAt: 0,
              updatedAt: 0,
            ),
          );
    }
  });
  tearDown(tearDownTestDatabase);

  Future<void> channelRow(String id, String computerId, int channel) => db
      .into(db.transmitters)
      .insert(
        TransmittersCompanion.insert(
          id: id,
          diverId: const Value('d1'),
          label: id,
          tankRole: 'backGas',
          diveComputerId: Value(computerId),
          channelIndex: Value(channel),
          createdAt: 0,
          updatedAt: 0,
        ),
      );

  test('merging moves channel rows to the survivor', () async {
    await channelRow('moves', 'duplicate', 2);

    await DiveComputerMergeRepository().mergeComputers(
      survivorId: 'survivor',
      duplicateIds: ['duplicate'],
    );

    final row = await (db.select(
      db.transmitters,
    )..where((t) => t.id.equals('moves'))).getSingle();
    expect(row.diveComputerId, 'survivor');
    expect(row.channelIndex, 2);
  });

  test('a colliding channel row is deleted on merge', () async {
    await channelRow('kept', 'survivor', 1);
    await channelRow('clash', 'duplicate', 1);

    await DiveComputerMergeRepository().mergeComputers(
      survivorId: 'survivor',
      duplicateIds: ['duplicate'],
    );

    final rows = await db.select(db.transmitters).get();
    expect(rows.map((r) => r.id), ['kept']);
    final tombstones = await db.select(db.deletionLog).get();
    expect(
      tombstones.map((t) => (t.entityType, t.recordId)),
      contains(('transmitters', 'clash')),
    );
  });

  test('a colliding row whose serial is only zeros counts as channel-only, '
      'as a computer delete treats it (review)', () async {
    await channelRow('kept', 'survivor', 1);
    await channelRow('clash', 'duplicate', 1);
    await (db.update(db.transmitters)..where((t) => t.id.equals('clash')))
        .write(const TransmittersCompanion(transmitterSerial: Value('000')));

    await DiveComputerMergeRepository().mergeComputers(
      survivorId: 'survivor',
      duplicateIds: ['duplicate'],
    );

    final rows = await db.select(db.transmitters).get();
    expect(rows.map((r) => r.id), ['kept']);
  });

  test("the duplicate's item is folded into the survivor's, so one computer "
      'shows once (issue #3676)', () async {
    for (final id in ['survivor-gear', 'duplicate-gear']) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              diverId: const Value('d1'),
              name: id,
              type: 'computer',
              createdAt: 0,
              updatedAt: 0,
            ),
          );
    }
    for (final (computer, gear) in [
      ('survivor', 'survivor-gear'),
      ('duplicate', 'duplicate-gear'),
    ]) {
      await (db.update(db.diveComputers)..where((t) => t.id.equals(computer)))
          .write(DiveComputersCompanion(equipmentId: Value(gear)));
    }
    await db
        .into(db.serviceRecords)
        .insert(
          ServiceRecordsCompanion.insert(
            id: 'battery-swap',
            equipmentId: 'duplicate-gear',
            serviceCategory: 'battery',
            serviceDate: 1,
            createdAt: 0,
            updatedAt: 0,
          ),
        );

    await DiveComputerMergeRepository().mergeComputers(
      survivorId: 'survivor',
      duplicateIds: ['duplicate'],
    );

    final items = await (db.select(
      db.equipment,
    )..where((t) => t.type.equals('computer'))).get();
    expect(items.map((e) => e.id), ['survivor-gear']);
    final record = await (db.select(
      db.serviceRecords,
    )..where((t) => t.id.equals('battery-swap'))).getSingle();
    expect(record.equipmentId, 'survivor-gear');
  });
}
