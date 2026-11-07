import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/bulk_dive_edit_service.dart';
import 'package:submersion/features/dive_log/domain/entities/bulk_edit_request.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';

import '../../../../helpers/test_database.dart';

/// Equipment sets in bulk edit (#4284): gear a set switched on is tagged
/// with it, a set can be taken off by what it brought, and undo puts the
/// gear back with its provenance.
void main() {
  late AppDatabase db;
  late BulkDiveEditService service;
  late DiveRepository diveRepo;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
    diveRepo = DiveRepository();
    service = BulkDiveEditService(
      diveRepo,
      BuddyRepository(),
      SpeciesRepository(),
    );
    for (final id in ['d1', 'd2']) {
      await diveRepo.createDive(
        domain.Dive(id: id, dateTime: DateTime(2026, 1, 1), notes: ''),
      );
    }
    // A set's items name real gear: the set rows are read through it, to
    // leave wishlist members out.
    await db.customStatement(
      'INSERT INTO equipment (id, name, type, created_at, updated_at) '
      "VALUES ('bcd', 'BCD', 'bcd', 0, 0), ('reg', 'Reg', 'regulator', 0, 0), "
      "('lamp', 'Lamp', 'light', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO equipment_set_items (set_id, equipment_id) '
      "VALUES ('warm', 'bcd'), ('warm', 'reg')",
    );
  });

  tearDown(tearDownTestDatabase);

  /// Each dive's gear as `id:set`, `-` for none.
  Future<List<String>> gearOf(String diveId) async => [
    for (final r
        in await db
            .customSelect(
              "SELECT equipment_id || ':' || COALESCE(via_set_id, '-') AS g "
              "FROM dive_equipment WHERE dive_id = '$diveId' ORDER BY equipment_id",
            )
            .get())
      r.read<String>('g'),
  ];

  test('an equipment add from a set carries the set', () async {
    await service.apply(
      const BulkEditRequest(
        diveIds: ['d1'],
        ops: [
          EquipmentOp(
            mode: BulkCollectionMode.add,
            equipmentIds: ['bcd'],
            viaSetId: 'warm',
          ),
          EquipmentOp(mode: BulkCollectionMode.add, equipmentIds: ['lamp']),
        ],
      ),
    );

    expect(await gearOf('d1'), ['bcd:warm', 'lamp:-']);
  });

  test(
    'removing a set takes only what it brought, and undo restores it',
    () async {
      await diveRepo.bulkAddEquipment(['d1', 'd2'], ['lamp']);
      await diveRepo.bulkAddEquipmentSets(['d1', 'd2'], ['warm']);

      final snap = await service.apply(
        const BulkEditRequest(
          diveIds: ['d1', 'd2'],
          ops: [
            EquipmentSetsOp(mode: BulkCollectionMode.remove, setIds: ['warm']),
          ],
        ),
      );
      expect(await gearOf('d1'), ['lamp:-']);
      expect(await gearOf('d2'), ['lamp:-']);

      await service.undo(snap);
      expect(await gearOf('d1'), ['bcd:warm', 'lamp:-', 'reg:warm']);
    },
  );

  test('adding a set by id tags its items', () async {
    await service.apply(
      const BulkEditRequest(
        diveIds: ['d1'],
        ops: [
          EquipmentSetsOp(mode: BulkCollectionMode.add, setIds: ['warm']),
        ],
      ),
    );

    expect(await gearOf('d1'), ['bcd:warm', 'reg:warm']);
  });

  test(
    'a set removal before an add of a sharing set keeps the shared item',
    () async {
      await db.customStatement(
        'INSERT INTO equipment_set_items (set_id, equipment_id) '
        "VALUES ('cold', 'reg')",
      );
      await diveRepo.bulkAddEquipmentSets(['d1'], ['warm']);

      await service.apply(
        const BulkEditRequest(
          diveIds: ['d1'],
          ops: [
            EquipmentSetsOp(mode: BulkCollectionMode.remove, setIds: ['warm']),
            EquipmentOp(
              mode: BulkCollectionMode.add,
              equipmentIds: ['reg'],
              viaSetId: 'cold',
            ),
          ],
        ),
      );

      expect(await gearOf('d1'), ['reg:cold']);
    },
  );

  test('a set op rejects replace and update', () async {
    for (final mode in [
      BulkCollectionMode.replace,
      BulkCollectionMode.update,
    ]) {
      await expectLater(
        service.apply(
          BulkEditRequest(
            diveIds: const ['d1'],
            ops: [
              EquipmentSetsOp(mode: mode, setIds: const ['warm']),
            ],
          ),
        ),
        throwsUnsupportedError,
      );
    }
  });
}
