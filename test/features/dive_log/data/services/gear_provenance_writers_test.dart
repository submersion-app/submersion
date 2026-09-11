import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/bulk_dive_edit_service.dart';
import 'package:submersion/features/dive_log/domain/entities/bulk_edit_request.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';

import '../../../../helpers/test_database.dart';

/// Writers that rebuild junction rows must copy provenance, not drop it
/// (issue #1487). Bulk-edit undo is the one with its own service; the
/// consolidation and computer-merge copies are covered by their suites.
void main() {
  late AppDatabase db;
  late DiveRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = DiveRepository();
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd1',
            name: 'd1',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    for (final id in ['reg', 'hose', 'mask']) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: 'regulator',
              createdAt: 1,
              updatedAt: 1,
              diverId: const Value('d1'),
            ),
          );
    }
    await db
        .into(db.equipmentSets)
        .insert(
          EquipmentSetsCompanion.insert(
            id: 'winter',
            name: 'Winter',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await repo.createDive(
      domain.Dive(id: 'dv', dateTime: DateTime(2026, 1, 1)),
    );
    await repo.replaceGearRows('dv', const [
      GearProvenance(equipmentId: 'reg', viaSetId: 'winter'),
      GearProvenance(
        equipmentId: 'hose',
        viaEquipmentId: 'reg',
        viaSetId: 'winter',
      ),
    ]);
  });

  tearDown(tearDownTestDatabase);

  Future<Map<String, DiveEquipmentData>> rowsOf(String diveId) async => {
    for (final r in await (db.select(
      db.diveEquipment,
    )..where((t) => t.diveId.equals(diveId))).get())
      r.equipmentId: r,
  };

  test('bulk edit undo restores provenance exactly', () async {
    final service = BulkDiveEditService(
      repo,
      BuddyRepository(),
      SpeciesRepository(),
    );
    final snapshot = await service.apply(
      const BulkEditRequest(
        diveIds: ['dv'],
        ops: [
          EquipmentOp(mode: BulkCollectionMode.add, equipmentIds: ['mask']),
        ],
      ),
    );
    expect((await rowsOf('dv')).keys, containsAll(['reg', 'hose', 'mask']));

    await service.undo(snapshot);

    final rows = await rowsOf('dv');
    expect(rows.keys, unorderedEquals(['reg', 'hose']));
    expect(rows['hose']!.viaEquipmentId, 'reg');
    expect(rows['hose']!.viaSetId, 'winter');
    expect(rows['reg']!.viaSetId, 'winter');
  });
}
