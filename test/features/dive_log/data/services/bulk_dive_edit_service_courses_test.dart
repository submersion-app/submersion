import 'package:drift/drift.dart' show Value;
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

/// Bulk add / remove / replace of a dive's courses, and undo (#2515).
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
    await db
        .into(db.divers)
        .insert(
          const DiversCompanion(
            id: Value('d'),
            name: Value('D'),
            createdAt: Value(0),
            updatedAt: Value(0),
          ),
        );
    for (final (id, start) in [('c1', 1), ('c2', 2), ('c3', 3)]) {
      await db
          .into(db.courses)
          .insert(
            CoursesCompanion(
              id: Value(id),
              diverId: const Value('d'),
              name: Value(id),
              agency: const Value('tdi'),
              startDate: Value(start),
              createdAt: const Value(0),
              updatedAt: const Value(0),
            ),
          );
    }
  });
  tearDown(() async => tearDownTestDatabase());

  Future<List<String>> coursesOf(String id) async =>
      (await diveRepo.getDiveById(id))!.courseIds.toList()..sort();

  Future<void> seed(String id, List<String> c) => diveRepo.createDive(
    domain.Dive(
      id: id,
      diverId: 'd',
      dateTime: DateTime(2026, 1, 1),
      courseIds: c,
    ),
  );

  BulkEditRequest req(
    List<String> ids,
    BulkCollectionMode mode,
    List<String> c,
  ) => BulkEditRequest(
    diveIds: ids,
    ops: [DiveCoursesOp(mode: mode, courseIds: c)],
  );

  test('add keeps each dive own courses', () async {
    await seed('v1', ['c1']);
    await seed('v2', []);
    await service.apply(req(['v1', 'v2'], BulkCollectionMode.add, ['c2']));
    expect(await coursesOf('v1'), ['c1', 'c2']);
    expect(await coursesOf('v2'), ['c2']);
  });

  test('remove drops only the named course', () async {
    await seed('v1', ['c1', 'c2']);
    await service.apply(req(['v1'], BulkCollectionMode.remove, ['c1']));
    expect(await coursesOf('v1'), ['c2']);
  });

  test('replace sets exactly the given courses', () async {
    await seed('v1', ['c1', 'c2']);
    await service.apply(req(['v1'], BulkCollectionMode.replace, ['c3']));
    expect(await coursesOf('v1'), ['c3']);
  });

  test('undo restores each dive prior courses', () async {
    await seed('v1', ['c1', 'c2']);
    await seed('v2', []);
    final snapshot = await service.apply(
      req(['v1', 'v2'], BulkCollectionMode.replace, ['c3']),
    );
    await service.undo(snapshot);
    expect(await coursesOf('v1'), ['c1', 'c2']);
    expect(await coursesOf('v2'), isEmpty);
  });

  test('counts courses across the selected dives', () async {
    await seed('v1', ['c1', 'c2']);
    await seed('v2', ['c2']);
    expect(await diveRepo.courseCountsForDives(['v1', 'v2']), {
      'c1': 1,
      'c2': 2,
    });
  });
}
