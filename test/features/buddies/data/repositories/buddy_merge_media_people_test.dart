import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/media/data/repositories/media_people_repository.dart';
import 'package:submersion/features/media/domain/entities/media_person_tag.dart';

import '../../../../helpers/test_database.dart';
import '../../../media/data/repositories/species_photo_fixtures.dart';

/// Merging buddies carries their people tags to the survivor (issue #1745):
/// one tag per person on a photo, every moment kept on a video, smart
/// albums repointed, and all of it undone by the merge's undo.
void main() {
  late AppDatabase db;
  final repo = BuddyRepository();
  final people = MediaPeopleRepository();

  setUp(() async {
    db = await setUpTestDatabase();
    await insertTestDiver('A');
    await insertTestDive(id: 'd1', at: DateTime(2024, 1, 10), diverId: 'A');
    await insertTestBuddy(id: 'keep', name: 'Alex', diverId: 'A');
    await insertTestBuddy(id: 'dup', name: 'Alex R', diverId: 'A');
    await insertTestMedia(id: 'p1', diveId: 'd1');
    await insertTestMedia(id: 'p2', diveId: 'd1');
    await insertTestMedia(id: 'v1', diveId: 'd1', fileType: 'video');
  });
  tearDown(tearDownTestDatabase);

  Future<BuddyMergeResultLike> merge() async {
    final survivor = (await repo.getBuddyById('keep'))!;
    final result = await repo.mergeBuddies(
      mergedBuddy: survivor,
      buddyIds: ['keep', 'dup'],
    );
    return BuddyMergeResultLike(result!.snapshot!);
  }

  Future<Map<String, String?>> buddyByTag() async => {
    for (final r in await db.select(db.mediaPeople).get()) r.id: r.buddyId,
  };

  test('merging buddies moves tags to the survivor', () async {
    final tag = await people.addTag(mediaId: 'p2', buddyId: 'dup');

    await merge();

    expect((await buddyByTag())[tag.id], 'keep');
  });

  test('a photo tagged with both buddies keeps one survivor tag', () async {
    const keepBox = FaceBox(x: 0.1, y: 0.1, width: 0.2, height: 0.2);
    final keep = await people.addTag(
      mediaId: 'p1',
      buddyId: 'keep',
      box: keepBox,
    );
    final dup = await people.addTag(mediaId: 'p1', buddyId: 'dup');
    await people.addTag(
      mediaId: 'v1',
      buddyId: 'keep',
      videoPosition: const Duration(seconds: 1),
    );
    await people.addTag(
      mediaId: 'v1',
      buddyId: 'dup',
      videoPosition: const Duration(seconds: 2),
    );

    await merge();

    final p1 = await people.getTagsForMedia('p1', diverId: 'A');
    expect(p1.map((t) => t.id), [keep.id]);
    expect(p1.single.box, keepBox);
    final tombstoned = await db
        .customSelect(
          "SELECT record_id FROM deletion_log WHERE entity_type = 'mediaPeople'",
        )
        .get();
    expect(tombstoned.map((r) => r.read<String>('record_id')), [dup.id]);
    // Every moment on a video is kept.
    final v1 = await people.getTagsForMedia('v1', diverId: 'A');
    expect(v1.map((t) => t.buddyId), ['keep', 'keep']);
  });

  test(
    'a boxed duplicate gives its box to a survivor tag without one',
    () async {
      const dupBox = FaceBox(x: 0.3, y: 0.3, width: 0.2, height: 0.2);
      final keep = await people.addTag(mediaId: 'p1', buddyId: 'keep');
      final dup = await people.addTag(
        mediaId: 'p1',
        buddyId: 'dup',
        box: dupBox,
      );

      final merged = await merge();

      final tags = await people.getTagsForMedia('p1', diverId: 'A');
      expect(tags.map((t) => (t.id, t.buddyId, t.box)), [
        (keep.id, 'keep', dupBox),
      ]);

      await repo.undoMerge(merged.snapshot);
      final back = {
        for (final t in await people.getTagsForMedia('p1', diverId: 'A'))
          t.id: (t.buddyId, t.box),
      };
      expect(back, {keep.id: ('keep', null), dup.id: ('dup', dupBox)});
    },
  );

  test('on a video, spot-less and same-moment duplicates collapse', () async {
    await people.addTag(mediaId: 'v1', buddyId: 'keep');
    await people.addTag(mediaId: 'v1', buddyId: 'dup');
    await people.addTag(
      mediaId: 'v1',
      buddyId: 'keep',
      box: const FaceBox(x: 0.1, y: 0.1, width: 0.2, height: 0.2),
      videoPosition: const Duration(milliseconds: 42000),
    );
    await people.addTag(
      mediaId: 'v1',
      buddyId: 'dup',
      box: const FaceBox(x: 0.5, y: 0.5, width: 0.2, height: 0.2),
      videoPosition: const Duration(milliseconds: 42300),
    );
    await people.addTag(
      mediaId: 'v1',
      buddyId: 'dup',
      box: const FaceBox(x: 0.5, y: 0.5, width: 0.2, height: 0.2),
      videoPosition: const Duration(seconds: 90),
    );

    await merge();

    final tags = await people.getTagsForMedia('v1', diverId: 'A');
    expect(tags.map((t) => (t.buddyId, t.videoPosition)), [
      ('keep', null),
      ('keep', const Duration(milliseconds: 42000)),
      ('keep', const Duration(seconds: 90)),
    ]);
  });

  test('undoing a three-way merge gives each duplicate its tag back', () async {
    await insertTestBuddy(id: 'dup2', name: 'A. Rivera', diverId: 'A');
    const dupBox = FaceBox(x: 0.3, y: 0.3, width: 0.2, height: 0.2);
    final one = await people.addTag(mediaId: 'p1', buddyId: 'dup');
    final two = await people.addTag(
      mediaId: 'p1',
      buddyId: 'dup2',
      box: dupBox,
    );
    final survivor = (await repo.getBuddyById('keep'))!;
    final result = await repo.mergeBuddies(
      mergedBuddy: survivor,
      buddyIds: ['keep', 'dup', 'dup2'],
    );

    await repo.undoMerge(result!.snapshot!);

    final back = {
      for (final t in await people.getTagsForMedia('p1', diverId: 'A'))
        t.id: (t.buddyId, t.box),
    };
    expect(back, {one.id: ('dup', null), two.id: ('dup2', dupBox)});
  });

  test('undoing the merge restores both tags', () async {
    final keep = await people.addTag(mediaId: 'p1', buddyId: 'keep');
    final dup = await people.addTag(mediaId: 'p1', buddyId: 'dup');
    final moved = await people.addTag(mediaId: 'p2', buddyId: 'dup');
    final merged = await merge();

    await repo.undoMerge(merged.snapshot);

    expect(await buddyByTag(), {
      keep.id: 'keep',
      dup.id: 'dup',
      moved.id: 'dup',
    });
  });

  test(
    'a smart album filtered on the duplicate now names the survivor',
    () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.mediaSmartAlbums)
          .insert(
            MediaSmartAlbumsCompanion(
              id: const Value('album'),
              name: const Value('With Alex'),
              filterJson: Value(
                jsonEncode({
                  'buddyIds': ['dup', 'other'],
                  'futureKey': 1,
                }),
              ),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      await merge();

      final row = await (db.select(
        db.mediaSmartAlbums,
      )..where((t) => t.id.equals('album'))).getSingle();
      final json = jsonDecode(row.filterJson) as Map<String, dynamic>;
      expect(json['buddyIds'], ['keep', 'other']);
      expect(json['futureKey'], 1);
    },
  );

  test('undoing the merge puts the album back on the duplicate', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final original = jsonEncode({
      'buddyIds': ['dup'],
    });
    await db
        .into(db.mediaSmartAlbums)
        .insert(
          MediaSmartAlbumsCompanion(
            id: const Value('album'),
            name: const Value('With Alex R'),
            filterJson: Value(original),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    final merged = await merge();

    await repo.undoMerge(merged.snapshot);

    final row = await (db.select(
      db.mediaSmartAlbums,
    )..where((t) => t.id.equals('album'))).getSingle();
    expect(row.filterJson, original);
  });
}

/// Keeps the test independent of the result class's import path.
class BuddyMergeResultLike {
  BuddyMergeResultLike(this.snapshot);
  final dynamic snapshot;
}
