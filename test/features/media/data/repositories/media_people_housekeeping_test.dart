import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/divers/data/repositories/diver_merge_repository.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/media/data/repositories/media_people_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_row_restore.dart';

import '../../../../helpers/test_database.dart';
import 'species_photo_fixtures.dart';

/// People tags follow their media, buddies and divers through deletes,
/// restores and merges (issue #1745), tombstoned so they do not return
/// from another device.
void main() {
  late AppDatabase db;
  final people = MediaPeopleRepository();

  setUp(() async {
    db = await setUpTestDatabase();
    await insertTestDiver('A');
    await insertTestDiver('B');
    await insertTestDive(id: 'd1', at: DateTime(2024, 1, 10), diverId: 'A');
    await insertTestBuddy(id: 'alex', name: 'Alex', diverId: 'A');
    await insertTestBuddy(id: 'bea', name: 'Bea', diverId: 'A');
    await insertTestMedia(id: 'p1', diveId: 'd1');
    await insertTestMedia(id: 'p2', diveId: 'd1');
  });
  tearDown(tearDownTestDatabase);

  Future<Set<String>> tombstones() async => {
    for (final r
        in await db
            .customSelect(
              "SELECT record_id FROM deletion_log WHERE entity_type = 'mediaPeople'",
            )
            .get())
      r.read<String>('record_id'),
  };

  Future<int> rowCount() async =>
      (await db.select(db.mediaPeople).get()).length;

  test('deleting media tombstones its people tags', () async {
    final tag = await people.addTag(mediaId: 'p1', buddyId: 'alex');
    final kept = await people.addTag(mediaId: 'p2', buddyId: 'alex');

    await MediaRepository().deleteMedia('p1');

    expect(await tombstones(), {tag.id});
    expect((await db.select(db.mediaPeople).get()).single.id, kept.id);
  });

  test('deleting several media tombstones their people tags', () async {
    final a = await people.addTag(mediaId: 'p1', buddyId: 'alex');
    final b = await people.addTag(mediaId: 'p2', diverId: 'A');

    await MediaRepository().deleteMultipleMedia(['p1', 'p2']);

    expect(await tombstones(), {a.id, b.id});
    expect(await rowCount(), 0);
  });

  test('the orphan cleanup tombstones the people tags it drops', () async {
    final tag = await people.addTag(mediaId: 'p1', buddyId: 'alex');
    await db.customStatement(
      "UPDATE media SET is_orphaned = 1 WHERE id = 'p1'",
    );

    await MediaRepository().deleteOrphanedMedia();

    expect(await tombstones(), {tag.id});
  });

  test('undoing a media delete restores its people tags', () async {
    final tag = await people.addTag(mediaId: 'p1', buddyId: 'alex');
    final me = await people.addTag(mediaId: 'p1', diverId: 'A');
    final gone = await people.addTag(mediaId: 'p1', buddyId: 'bea');
    final snapshot = await readMediaRows(db, ['p1']);
    expect(snapshot.people, hasLength(3));
    await MediaRepository().deleteMultipleMedia(['p1']);
    // A buddy deleted while the media was gone stays gone.
    await db.customStatement("DELETE FROM buddies WHERE id = 'bea'");

    await restoreMediaRows(db, SyncRepository(), snapshot, now: 10);

    final restored = await people.getTagsForMedia('p1', diverId: 'A');
    expect(restored.map((t) => t.id).toSet(), {tag.id, me.id});
    expect(await tombstones(), isNot(contains(tag.id)));
    expect(await tombstones(), contains(gone.id));
  });

  test('deleting a buddy tombstones their tags', () async {
    final tag = await people.addTag(mediaId: 'p1', buddyId: 'alex');
    final kept = await people.addTag(mediaId: 'p1', buddyId: 'bea');

    await BuddyRepository().deleteBuddy('alex');

    expect(await tombstones(), {tag.id});
    expect((await db.select(db.mediaPeople).get()).single.id, kept.id);
  });

  test('bulk deleting buddies tombstones their tags', () async {
    final a = await people.addTag(mediaId: 'p1', buddyId: 'alex');
    final b = await people.addTag(mediaId: 'p2', buddyId: 'bea');

    await BuddyRepository().bulkDeleteBuddies(['alex', 'bea']);

    expect(await tombstones(), {a.id, b.id});
  });

  test(
    "deleting a diver removes their Me tags and their buddies' tags",
    () async {
      await insertTestBuddy(id: 'zed', name: 'Zed', diverId: 'B');
      await insertTestMedia(id: 'shared');
      final me = await people.addTag(mediaId: 'shared', diverId: 'A');
      final buddy = await people.addTag(mediaId: 'shared', buddyId: 'alex');
      final other = await people.addTag(mediaId: 'shared', buddyId: 'zed');
      final otherMe = await people.addTag(mediaId: 'shared', diverId: 'B');

      await DiverRepository().deleteDiverWithReassignment('A');

      expect(await tombstones(), containsAll([me.id, buddy.id]));
      final left = {
        for (final r in await db.select(db.mediaPeople).get()) r.id,
      };
      expect(left, {other.id, otherMe.id});
    },
  );

  test('merging divers moves Me tags to the keeper', () async {
    final me = await people.addTag(mediaId: 'p1', diverId: 'B');

    await DiverMergeRepository().mergeDivers(keeperId: 'A', duplicateId: 'B');

    final row = await (db.select(
      db.mediaPeople,
    )..where((t) => t.id.equals(me.id))).getSingle();
    expect(row.diverId, 'A');
  });
}
