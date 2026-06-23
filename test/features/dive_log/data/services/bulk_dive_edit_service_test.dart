import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/bulk_dive_edit_service.dart';
import 'package:submersion/features/dive_log/domain/entities/bulk_edit_request.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart' as domain;
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';

import '../../../../helpers/test_database.dart';

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
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> seed(String id) => diveRepo.createDive(
    domain.Dive(id: id, dateTime: DateTime(2026, 1, 1), notes: ''),
  );

  test('apply writes scalars + notes-append + a tag op and returns a snapshot', () async {
    await seed('d1');
    await seed('d2');

    final snap = await service.apply(
      BulkEditRequest(
        diveIds: const ['d1', 'd2'],
        scalars: const DivesCompanion(rating: Value(4)),
        notesAppend: ' trip',
        ops: const [TagsOp(mode: BulkCollectionMode.replace, tagIds: ['t1'])],
      ),
    );

    final r1 = await (db.select(
      db.dives,
    )..where((t) => t.id.equals('d1'))).getSingle();
    expect(r1.rating, 4);
    expect(r1.notes, ' trip');
    final tags = await (db.select(
      db.diveTags,
    )..where((t) => t.diveId.equals('d1'))).get();
    expect(tags.single.tagId, 't1');
    expect(snap.priorDiveRows.length, 2);
    expect(snap.priorTagIds, isNotNull);
  });

  test('undo restores prior scalar values and tag membership', () async {
    await seed('d1');
    await diveRepo.bulkUpdateFields(['d1'], const DivesCompanion(rating: Value(2)));
    await diveRepo.bulkReplaceTags(['d1'], ['orig']);

    final snap = await service.apply(
      BulkEditRequest(
        diveIds: const ['d1'],
        scalars: const DivesCompanion(rating: Value(9)),
        ops: const [TagsOp(mode: BulkCollectionMode.replace, tagIds: ['new'])],
      ),
    );

    await service.undo(snap);

    final r = await (db.select(
      db.dives,
    )..where((t) => t.id.equals('d1'))).getSingle();
    expect(r.rating, 2); // restored
    final tags = await (db.select(
      db.diveTags,
    )..where((t) => t.diveId.equals('d1'))).get();
    expect(tags.single.tagId, 'orig'); // restored
  });
}
