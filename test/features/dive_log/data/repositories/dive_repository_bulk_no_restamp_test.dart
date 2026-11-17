import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart' show WeightType;
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart'
    as domain;

import '../../../../helpers/test_database.dart';

/// Issue #4651: a bulk edit of a dive's child rows stages those rows on their
/// own clocks and leaves the dive row alone. Restamping the dive would let
/// this device's copy of it overwrite a newer edit made on another device.
/// The dive is restamped only when the edit changes one of its own columns
/// (the representative dive type or course), and open screens still get a
/// `dives` tick either way.
void main() {
  late DiveRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<Dive> diveRow(String id) =>
      (db.select(db.dives)..where((t) => t.id.equals(id))).getSingle();

  Future<Set<String>> pending(String entityType) async => {
    for (final r in await db.select(db.syncRecords).get())
      if (r.entityType == entityType) r.recordId,
  };

  /// A saved dive with nothing pending; returns its `updated_at`.
  Future<int> seedDive(String id, {List<String> types = const []}) async {
    await repository.createDive(
      domain.Dive(id: id, dateTime: DateTime(2026, 1, 1), diveTypeIds: types),
    );
    await SyncRepository().clearAllSyncRecords();
    return (await diveRow(id)).updatedAt;
  }

  Future<void> seedCourses() async {
    await db.customStatement(
      'INSERT INTO divers (id, name, created_at, updated_at) '
      "VALUES ('diver-1', 'D', 0, 0)",
    );
    for (final (id, day) in [('c1', 1), ('c2', 2)]) {
      await db.customStatement(
        'INSERT INTO courses (id, diver_id, name, agency, start_date, '
        'created_at, updated_at) VALUES (?, ?, ?, ?, ?, 0, 0)',
        [id, 'diver-1', 'Course $id', 'tdi', day],
      );
    }
  }

  void expectDiveLeftAlone(Dive dive, int seededAt) {
    expect(dive.updatedAt, seededAt, reason: 'the dive row was restamped');
  }

  test('a bulk tag edit stages the tag links only', () async {
    final seededAt = await seedDive('d1');
    await db.customStatement(
      'INSERT INTO tags (id, name, created_at, updated_at) '
      "VALUES ('tag1', 'Night', 0, 0)",
    );

    await repository.bulkReplaceTags(['d1'], ['tag1']);

    expectDiveLeftAlone(await diveRow('d1'), seededAt);
    expect(await pending('dives'), isEmpty);
    expect(await pending('diveTags'), hasLength(1));
  });

  test('bulk adding a tag stages the tag link only', () async {
    final seededAt = await seedDive('d1');
    await db.customStatement(
      'INSERT INTO tags (id, name, created_at, updated_at) '
      "VALUES ('tag1', 'Night', 0, 0)",
    );

    await repository.bulkAddTags(['d1'], ['tag1']);

    expectDiveLeftAlone(await diveRow('d1'), seededAt);
    expect(await pending('dives'), isEmpty);
    expect(await pending('diveTags'), hasLength(1));
  });

  test('bulk removing a tag tombstones the tag link only', () async {
    final seededAt = await seedDive('d1');
    await db.customStatement(
      'INSERT INTO tags (id, name, created_at, updated_at) '
      "VALUES ('tag1', 'Night', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO dive_tags (id, dive_id, tag_id, created_at) '
      "VALUES ('dt1', 'd1', 'tag1', 0)",
    );

    await repository.bulkRemoveTags(['d1'], ['tag1']);

    expectDiveLeftAlone(await diveRow('d1'), seededAt);
    expect(await pending('dives'), isEmpty);
    final tombstones = [
      for (final t in await db.select(db.deletionLog).get())
        if (t.entityType == 'diveTags') t.recordId,
    ];
    expect(tombstones, ['dt1']);
  });

  test('bulk tag add and remove still tick dives', () async {
    await seedDive('d1');
    await db.customStatement(
      'INSERT INTO tags (id, name, created_at, updated_at) '
      "VALUES ('tag1', 'Night', 0, 0)",
    );
    var ticks = 0;
    final sub = db
        .tableUpdates(TableUpdateQuery.onTable(db.dives))
        .listen((_) => ticks++);
    addTearDown(sub.cancel);

    await repository.bulkAddTags(['d1'], ['tag1']);
    await pumpEventQueue();
    final afterAdd = ticks;
    await repository.bulkRemoveTags(['d1'], ['tag1']);
    await pumpEventQueue();

    expect(afterAdd, greaterThan(0));
    expect(ticks, greaterThan(afterAdd));
  });

  test('a bulk weight edit stages the weight rows only', () async {
    final seededAt = await seedDive('d1');

    await repository.bulkAddWeights(
      ['d1'],
      [
        const domain.DiveWeight(
          id: '',
          diveId: '',
          weightType: WeightType.belt,
          amountKg: 4,
        ),
      ],
    );

    expectDiveLeftAlone(await diveRow('d1'), seededAt);
    expect(await pending('dives'), isEmpty);
    expect(await pending('diveWeights'), hasLength(1));
  });

  test('a bulk tank edit stages the tank rows only', () async {
    final seededAt = await seedDive('d1');

    await repository.bulkAddTanks(
      ['d1'],
      [const domain.DiveTank(id: '', volume: 12)],
    );

    expectDiveLeftAlone(await diveRow('d1'), seededAt);
    expect(await pending('dives'), isEmpty);
    expect(await pending('diveTanks'), hasLength(1));
  });

  test('a bulk gear edit stages the gear links only', () async {
    final seededAt = await seedDive('d1');
    await db.customStatement(
      'INSERT INTO equipment (id, name, type, created_at, updated_at) '
      "VALUES ('e1', 'Wing', 'bcd', 0, 0)",
    );

    await repository.bulkReplaceEquipment(['d1'], ['e1']);

    expectDiveLeftAlone(await diveRow('d1'), seededAt);
    expect(await pending('dives'), isEmpty);
    expect(await pending('diveEquipment'), isNotEmpty);
  });

  group('dive types', () {
    test('adding a type after the first stages the type rows only', () async {
      final seededAt = await seedDive('d1', types: ['shore']);

      await repository.bulkAddDiveTypes(['d1'], ['night']);

      final dive = await diveRow('d1');
      expect(dive.diveType, 'shore');
      expectDiveLeftAlone(dive, seededAt);
      expect(await pending('dives'), isEmpty);
      expect(await pending('diveDiveTypes'), isNotEmpty);
    });

    test('changing the first type restamps the dive, whose representative '
        'type column changed', () async {
      final seededAt = await seedDive('d1', types: ['shore']);

      await repository.bulkReplaceDiveTypes(['d1'], ['cave']);

      final dive = await diveRow('d1');
      expect(dive.diveType, 'cave');
      expect(dive.updatedAt, greaterThan(seededAt));
      expect(await pending('dives'), {'d1'});
    });
  });

  group('courses', () {
    test('adding a later course stages the course links only', () async {
      await seedCourses();
      await seedDive('d1');
      await repository.bulkAddCourses(['d1'], ['c1']);
      await SyncRepository().clearAllSyncRecords();
      final seededAt = (await diveRow('d1')).updatedAt;

      await repository.bulkAddCourses(['d1'], ['c2']);

      final dive = await diveRow('d1');
      expect(dive.courseId, 'c1');
      expectDiveLeftAlone(dive, seededAt);
      expect(await pending('dives'), isEmpty);
      expect(await pending('diveCourses'), hasLength(1));
    });

    /// A dive in courses c1 (the representative) and c2, nothing pending;
    /// returns its `updated_at`.
    Future<int> seedTwoCourses() async {
      await seedCourses();
      await seedDive('d1');
      await repository.bulkAddCourses(['d1'], ['c1', 'c2']);
      await SyncRepository().clearAllSyncRecords();
      await db.delete(db.deletionLog).go();
      return (await diveRow('d1')).updatedAt;
    }

    test('removing the representative course restamps the dive', () async {
      final seededAt = await seedTwoCourses();
      await Future<void>.delayed(const Duration(milliseconds: 2));

      await repository.bulkRemoveCourses(['d1'], ['c1']);

      final dive = await diveRow('d1');
      expect(dive.courseId, 'c2');
      expect(dive.updatedAt, greaterThan(seededAt));
      expect(await pending('dives'), {'d1'});
    });

    test('replacing the courses with none restamps the dive', () async {
      final seededAt = await seedTwoCourses();
      await Future<void>.delayed(const Duration(milliseconds: 2));

      await repository.bulkReplaceCourses(['d1'], const []);

      final dive = await diveRow('d1');
      expect(dive.courseId, isNull);
      expect(dive.updatedAt, greaterThan(seededAt));
      expect(await pending('dives'), {'d1'});
    });

    test('removing a later course stages the course link only', () async {
      final seededAt = await seedTwoCourses();

      await repository.bulkRemoveCourses(['d1'], ['c2']);

      final dive = await diveRow('d1');
      expect(dive.courseId, 'c1');
      expectDiveLeftAlone(dive, seededAt);
      expect(await pending('dives'), isEmpty);
    });

    test('a first course restamps the dive, whose representative course '
        'column changed', () async {
      await seedCourses();
      final seededAt = await seedDive('d1');

      await repository.bulkAddCourses(['d1'], ['c1']);

      final dive = await diveRow('d1');
      expect(dive.courseId, 'c1');
      expect(dive.updatedAt, greaterThan(seededAt));
      expect(await pending('dives'), {'d1'});
    });
  });

  test(
    'open screens that watch only dives still hear a bulk child edit',
    () async {
      await seedDive('d1');
      await db.customStatement(
        'INSERT INTO tags (id, name, created_at, updated_at) '
        "VALUES ('tag1', 'Night', 0, 0)",
      );
      var ticks = 0;
      final sub = db
          .tableUpdates(TableUpdateQuery.onTable(db.dives))
          .listen((_) => ticks++);
      addTearDown(sub.cancel);

      await repository.bulkReplaceTags(['d1'], ['tag1']);
      await pumpEventQueue();

      expect(ticks, greaterThan(0));
    },
  );
}
