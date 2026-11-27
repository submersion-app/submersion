import 'package:drift/drift.dart' hide isNull, isNotNull;
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

/// Bulk edit and the table editor mark the computer-written values they set,
/// as the dive page's Save does, so a re-parse keeps them (issue #4909).
void main() {
  late AppDatabase db;
  late BulkDiveEditService service;
  late DiveRepository diveRepo;

  setUp(() async {
    db = await setUpTestDatabase();
    diveRepo = DiveRepository();
    service = BulkDiveEditService(
      diveRepo,
      BuddyRepository(),
      SpeciesRepository(),
    );
    for (final (id, gfLow) in [('d1', 30), ('d2', 40)]) {
      await diveRepo.createDive(
        domain.Dive(
          id: id,
          dateTime: DateTime(2026, 1, 1),
          gradientFactorLow: gfLow,
        ),
      );
    }
  });

  tearDown(tearDownTestDatabase);

  Future<Map<String, String?>> marks() async => {
    for (final row in await db.select(db.dives).get())
      row.id: row.handSetFields,
  };

  test('marks a set value on the dives it changed', () async {
    await service.apply(
      const BulkEditRequest(
        diveIds: ['d1', 'd2'],
        scalars: DivesCompanion(gradientFactorLow: Value(40)),
      ),
    );
    expect(await marks(), {'d1': '["gradientFactorLow"]', 'd2': null});
  });

  test('a value that is not computer-written marks nothing', () async {
    await service.apply(
      const BulkEditRequest(
        diveIds: ['d1'],
        scalars: DivesCompanion(rating: Value(4)),
      ),
    );
    expect(await marks(), {'d1': null, 'd2': null});
  });

  test('undo takes the mark back', () async {
    final snapshot = await service.apply(
      const BulkEditRequest(
        diveIds: ['d1'],
        scalars: DivesCompanion(gradientFactorLow: Value(50)),
      ),
    );
    await service.undo(snapshot);
    expect(await marks(), {'d1': null, 'd2': null});
  });
}
