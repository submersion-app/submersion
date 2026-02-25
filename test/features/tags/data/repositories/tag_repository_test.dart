import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';

import '../../../../helpers/test_database.dart';

/// Insert a diver into the test DB.
Future<void> insertTestDiver(String id) async {
  final db = DatabaseService.instance.database;
  final now = DateTime.now().millisecondsSinceEpoch;
  await db
      .into(db.divers)
      .insertOnConflictUpdate(
        DiversCompanion(
          id: Value(id),
          name: Value('Diver $id'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
}

/// Insert a minimal dive into the test DB.
Future<void> insertTestDive({required String id, String? diverId}) async {
  final db = DatabaseService.instance.database;
  final now = DateTime.now().millisecondsSinceEpoch;

  if (diverId != null) {
    await insertTestDiver(diverId);
  }

  await db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diverId: Value(diverId),
          diveDateTime: Value(now),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
}

/// Insert a tag directly into the test DB.
Future<void> insertTestTag({
  required String id,
  required String name,
  String? diverId,
  String? color,
}) async {
  final db = DatabaseService.instance.database;
  final now = DateTime.now().millisecondsSinceEpoch;
  await db
      .into(db.tags)
      .insert(
        TagsCompanion(
          id: Value(id),
          diverId: Value(diverId),
          name: Value(name),
          color: Value(color),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
}

/// Insert a dive-tag association directly into the test DB.
Future<void> insertDiveTag({
  required String id,
  required String diveId,
  required String tagId,
}) async {
  final db = DatabaseService.instance.database;
  final now = DateTime.now().millisecondsSinceEpoch;
  await db
      .into(db.diveTags)
      .insert(
        DiveTagsCompanion(
          id: Value(id),
          diveId: Value(diveId),
          tagId: Value(tagId),
          createdAt: Value(now),
        ),
      );
}

void main() {
  late TagRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = TagRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('getTagUsageCount', () {
    test('returns 0 for tag with no dives', () async {
      await insertTestTag(id: 'tag1', name: 'Night Dive');

      final count = await repository.getTagUsageCount('tag1');

      expect(count, 0);
    });

    test('returns correct count for tag with multiple dives', () async {
      await insertTestDiver('diver1');
      await insertTestTag(id: 'tag1', name: 'Night Dive', diverId: 'diver1');
      await insertTestDive(id: 'dive1', diverId: 'diver1');
      await insertTestDive(id: 'dive2', diverId: 'diver1');
      await insertTestDive(id: 'dive3', diverId: 'diver1');

      await insertDiveTag(id: 'dt1', diveId: 'dive1', tagId: 'tag1');
      await insertDiveTag(id: 'dt2', diveId: 'dive2', tagId: 'tag1');
      await insertDiveTag(id: 'dt3', diveId: 'dive3', tagId: 'tag1');

      final count = await repository.getTagUsageCount('tag1');

      expect(count, 3);
    });
  });

  group('getMergedDiveCount', () {
    test('returns 0 for empty list', () async {
      final count = await repository.getMergedDiveCount([]);

      expect(count, 0);
    });

    test('returns correct count for single tag', () async {
      await insertTestDiver('diver1');
      await insertTestTag(id: 'tag1', name: 'Deep Dive', diverId: 'diver1');
      await insertTestDive(id: 'dive1', diverId: 'diver1');
      await insertTestDive(id: 'dive2', diverId: 'diver1');

      await insertDiveTag(id: 'dt1', diveId: 'dive1', tagId: 'tag1');
      await insertDiveTag(id: 'dt2', diveId: 'dive2', tagId: 'tag1');

      final count = await repository.getMergedDiveCount(['tag1']);

      expect(count, 2);
    });

    test('returns union count for overlapping tags (not sum)', () async {
      await insertTestDiver('diver1');
      await insertTestTag(id: 'tag1', name: 'Night', diverId: 'diver1');
      await insertTestTag(id: 'tag2', name: 'Deep', diverId: 'diver1');
      await insertTestDive(id: 'dive1', diverId: 'diver1');
      await insertTestDive(id: 'dive2', diverId: 'diver1');

      // dive1 has both tags, dive2 has only tag1
      await insertDiveTag(id: 'dt1', diveId: 'dive1', tagId: 'tag1');
      await insertDiveTag(id: 'dt2', diveId: 'dive1', tagId: 'tag2');
      await insertDiveTag(id: 'dt3', diveId: 'dive2', tagId: 'tag1');

      // Sum would be 3, but union (distinct dives) should be 2
      final count = await repository.getMergedDiveCount(['tag1', 'tag2']);

      expect(count, 2);
    });

    test('returns count for disjoint tags', () async {
      await insertTestDiver('diver1');
      await insertTestTag(id: 'tag1', name: 'Night', diverId: 'diver1');
      await insertTestTag(id: 'tag2', name: 'Deep', diverId: 'diver1');
      await insertTestDive(id: 'dive1', diverId: 'diver1');
      await insertTestDive(id: 'dive2', diverId: 'diver1');

      // Each tag on a different dive, no overlap
      await insertDiveTag(id: 'dt1', diveId: 'dive1', tagId: 'tag1');
      await insertDiveTag(id: 'dt2', diveId: 'dive2', tagId: 'tag2');

      final count = await repository.getMergedDiveCount(['tag1', 'tag2']);

      expect(count, 2);
    });
  });

  group('mergeTags', () {
    test('moves associations from source to surviving tag', () async {
      await insertTestDiver('diver1');
      await insertTestTag(id: 'surviving', name: 'Main', diverId: 'diver1');
      await insertTestTag(id: 'source1', name: 'Old Tag', diverId: 'diver1');
      await insertTestDive(id: 'dive1', diverId: 'diver1');

      // source1 is associated with dive1, surviving is not
      await insertDiveTag(id: 'dt1', diveId: 'dive1', tagId: 'source1');

      await repository.mergeTags(
        sourceTagIds: ['source1'],
        survivingTagId: 'surviving',
        name: 'Main',
        colorHex: '#FF0000',
      );

      // dive1 should now be associated with surviving tag
      final tagsForDive = await repository.getTagsForDive('dive1');
      expect(tagsForDive.length, 1);
      expect(tagsForDive.first.id, 'surviving');
    });

    test(
      'skips duplicate associations when dive already has surviving tag',
      () async {
        await insertTestDiver('diver1');
        await insertTestTag(id: 'surviving', name: 'Main', diverId: 'diver1');
        await insertTestTag(id: 'source1', name: 'Old Tag', diverId: 'diver1');
        await insertTestDive(id: 'dive1', diverId: 'diver1');

        // Both tags associated with dive1
        await insertDiveTag(id: 'dt1', diveId: 'dive1', tagId: 'surviving');
        await insertDiveTag(id: 'dt2', diveId: 'dive1', tagId: 'source1');

        await repository.mergeTags(
          sourceTagIds: ['source1'],
          survivingTagId: 'surviving',
          name: 'Main',
          colorHex: '#FF0000',
        );

        // dive1 should have exactly one tag (surviving), not a duplicate
        final tagsForDive = await repository.getTagsForDive('dive1');
        expect(tagsForDive.length, 1);
        expect(tagsForDive.first.id, 'surviving');
      },
    );

    test('deletes source tags after merge', () async {
      await insertTestDiver('diver1');
      await insertTestTag(id: 'surviving', name: 'Main', diverId: 'diver1');
      await insertTestTag(
        id: 'source1',
        name: 'To Delete 1',
        diverId: 'diver1',
      );
      await insertTestTag(
        id: 'source2',
        name: 'To Delete 2',
        diverId: 'diver1',
      );

      await repository.mergeTags(
        sourceTagIds: ['source1', 'source2'],
        survivingTagId: 'surviving',
        name: 'Main',
        colorHex: '#FF0000',
      );

      // Source tags should no longer exist
      final source1 = await repository.getTagById('source1');
      final source2 = await repository.getTagById('source2');
      expect(source1, isNull);
      expect(source2, isNull);

      // Surviving tag should still exist
      final surviving = await repository.getTagById('surviving');
      expect(surviving, isNotNull);
    });

    test('updates surviving tag name and color', () async {
      await insertTestDiver('diver1');
      await insertTestTag(
        id: 'surviving',
        name: 'Old Name',
        diverId: 'diver1',
        color: '#000000',
      );
      await insertTestTag(id: 'source1', name: 'Source', diverId: 'diver1');

      await repository.mergeTags(
        sourceTagIds: ['source1'],
        survivingTagId: 'surviving',
        name: 'New Name',
        colorHex: '#00FF00',
      );

      final updated = await repository.getTagById('surviving');
      expect(updated, isNotNull);
      expect(updated!.name, 'New Name');
      expect(updated.colorHex, '#00FF00');
    });

    test(
      'throws ArgumentError when survivingTagId is in sourceTagIds',
      () async {
        expect(
          () => repository.mergeTags(
            sourceTagIds: ['tag1', 'tag2'],
            survivingTagId: 'tag1',
            name: 'Name',
            colorHex: '#FF0000',
          ),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test('returns early for empty sourceTagIds', () async {
      await insertTestDiver('diver1');
      await insertTestTag(
        id: 'surviving',
        name: 'Original',
        diverId: 'diver1',
        color: '#FF0000',
      );

      // Should complete without error and not modify the surviving tag
      await repository.mergeTags(
        sourceTagIds: [],
        survivingTagId: 'surviving',
        name: 'Updated',
        colorHex: '#00FF00',
      );

      // The surviving tag should remain unchanged since sourceTagIds was empty
      final tag = await repository.getTagById('surviving');
      expect(tag, isNotNull);
      expect(tag!.name, 'Original');
      expect(tag.colorHex, '#FF0000');
    });
  });

  group('no auto-cleanup', () {
    test(
      'removeTagFromDive does not delete tag when it was the last dive',
      () async {
        await insertTestDiver('diver1');
        await insertTestTag(id: 'tag1', name: 'Night Dive', diverId: 'diver1');
        await insertTestDive(id: 'dive1', diverId: 'diver1');
        await insertDiveTag(id: 'dt1', diveId: 'dive1', tagId: 'tag1');

        // Remove the only dive association
        await repository.removeTagFromDive('dive1', 'tag1');

        // Tag should still exist even though it has zero dives
        final tag = await repository.getTagById('tag1');
        expect(tag, isNotNull);
        expect(tag!.name, 'Night Dive');

        // Verify the association was actually removed
        final count = await repository.getTagUsageCount('tag1');
        expect(count, 0);
      },
    );

    test('setTagsForDive does not delete removed tags', () async {
      await insertTestDiver('diver1');
      await insertTestTag(id: 'tag1', name: 'Tag A', diverId: 'diver1');
      await insertTestTag(id: 'tag2', name: 'Tag B', diverId: 'diver1');
      await insertTestDive(id: 'dive1', diverId: 'diver1');

      // Initially dive1 has tag1 and tag2
      await insertDiveTag(id: 'dt1', diveId: 'dive1', tagId: 'tag1');
      await insertDiveTag(id: 'dt2', diveId: 'dive1', tagId: 'tag2');

      // Set tags to only tag2, removing tag1
      final tag2 = await repository.getTagById('tag2');
      await repository.setTagsForDive('dive1', [tag2!]);

      // tag1 should still exist even though it has no dives
      final tag1 = await repository.getTagById('tag1');
      expect(tag1, isNotNull);
      expect(tag1!.name, 'Tag A');

      // Verify tag1 has no associations
      final count = await repository.getTagUsageCount('tag1');
      expect(count, 0);

      // Verify tag2 is still associated
      final tagsForDive = await repository.getTagsForDive('dive1');
      expect(tagsForDive.length, 1);
      expect(tagsForDive.first.id, 'tag2');
    });
  });
}
