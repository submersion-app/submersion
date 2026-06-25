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

void main() {
  late BulkDiveEditService service;
  late DiveRepository diveRepo;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    diveRepo = DiveRepository();
    service = BulkDiveEditService(
      diveRepo,
      BuddyRepository(),
      SpeciesRepository(),
    );
  });
  tearDown(() async => tearDownTestDatabase());

  Future<List<String>> typesOf(String id) async =>
      (await diveRepo.getDiveById(id))!.diveTypeIds.toList()..sort();

  Future<void> seed(String id, List<String> t) => diveRepo.createDive(
    domain.Dive(id: id, dateTime: DateTime(2026, 1, 1), diveTypeIds: t),
  );

  test('DiveTypesOp add unions across multiple dives', () async {
    await seed('d1', ['shore']);
    await seed('d2', ['boat']);
    await service.apply(
      const BulkEditRequest(
        diveIds: ['d1', 'd2'],
        ops: [
          DiveTypesOp(mode: BulkCollectionMode.add, diveTypeIds: ['night']),
        ],
      ),
    );
    expect(await typesOf('d1'), ['night', 'shore']);
    expect(await typesOf('d2'), ['boat', 'night']);
  });

  test('DiveTypesOp remove that empties falls back to recreational', () async {
    await seed('d1', ['shore']);
    await service.apply(
      const BulkEditRequest(
        diveIds: ['d1'],
        ops: [
          DiveTypesOp(mode: BulkCollectionMode.remove, diveTypeIds: ['shore']),
        ],
      ),
    );
    expect(await typesOf('d1'), ['recreational']);
  });

  test('undo restores prior dive-type membership', () async {
    await seed('d1', ['shore', 'wreck']);
    final snapshot = await service.apply(
      const BulkEditRequest(
        diveIds: ['d1'],
        ops: [
          DiveTypesOp(mode: BulkCollectionMode.replace, diveTypeIds: ['cave']),
        ],
      ),
    );
    expect(await typesOf('d1'), ['cave']);

    await service.undo(snapshot);
    expect(await typesOf('d1'), ['shore', 'wreck']);
  });

  test(
    'undo restores a legacy dive (no junction rows) from the column',
    () async {
      await seed('d1', ['shore', 'wreck']); // representative = 'shore'
      // Make it a legacy/old-version dive: drop the junction rows, keep the
      // dives.dive_type representative.
      await (db.delete(
        db.diveDiveTypes,
      )..where((t) => t.diveId.equals('d1'))).go();

      final snapshot = await service.apply(
        const BulkEditRequest(
          diveIds: ['d1'],
          ops: [
            DiveTypesOp(
              mode: BulkCollectionMode.replace,
              diveTypeIds: ['cave'],
            ),
          ],
        ),
      );
      expect(await typesOf('d1'), ['cave']);

      await service.undo(snapshot);
      // Seeded from the representative 'shore', not reset to recreational.
      expect(await typesOf('d1'), ['shore']);
    },
  );
}
