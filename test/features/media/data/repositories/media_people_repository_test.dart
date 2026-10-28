import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/media/data/repositories/media_people_repository.dart';
import 'package:submersion/features/media/domain/entities/media_person_tag.dart';

import '../../../../helpers/test_database.dart';
import 'species_photo_fixtures.dart';

void main() {
  late MediaPeopleRepository repository;
  AppDatabase db() => DatabaseService.instance.database;

  const box = FaceBox(x: 0.2, y: 0.3, width: 0.15, height: 0.2);

  Future<bool> isPending(String id) async => (await (db().select(
    db().syncRecords,
  )..where((t) => t.recordId.equals(id))).get()).isNotEmpty;

  Future<bool> isTombstoned(String id) async =>
      (await (db().select(db().deletionLog)..where(
                (t) =>
                    t.recordId.equals(id) & t.entityType.equals('mediaPeople'),
              ))
              .get())
          .isNotEmpty;

  setUp(() async {
    await setUpTestDatabase();
    repository = MediaPeopleRepository();
    await insertTestDiver('A');
    await insertTestDiver('B');
    await insertTestDive(id: 'd1', at: DateTime(2024, 1, 10), diverId: 'A');
    await insertTestDive(id: 'd2', at: DateTime(2024, 2, 10), diverId: 'A');
    await insertTestBuddy(id: 'alex', name: 'Alex', diverId: 'A');
    await insertTestBuddy(id: 'bea', name: 'Bea', diverId: 'A');
    await insertTestBuddy(id: 'zed', name: 'Zed', diverId: 'B');
    await insertTestMedia(
      id: 'p1',
      diveId: 'd1',
      takenAt: DateTime(2024, 1, 10),
    );
    await insertTestMedia(
      id: 'p2',
      diveId: 'd2',
      takenAt: DateTime(2024, 2, 10),
    );
    await insertTestMedia(
      id: 'v1',
      diveId: 'd1',
      takenAt: DateTime(2024, 1, 11),
      fileType: 'video',
    );
    // Media with no dive: every profile can see it.
    await insertTestMedia(id: 'shared', takenAt: DateTime(2024, 3, 1));
  });

  tearDown(tearDownTestDatabase);

  test('addTag stores a buddy face box and marks the row pending', () async {
    final tag = await repository.addTag(
      mediaId: 'p1',
      buddyId: 'alex',
      box: box,
    );

    expect(tag.buddyId, 'alex');
    expect(tag.box, box);
    expect(tag.isMe, isFalse);
    final tags = await repository.getTagsForMedia('p1', diverId: 'A');
    expect(tags.single, tag);
    expect(await isPending(tag.id), isTrue);
  });

  test('addTag rejects a row with both or neither person', () async {
    expect(
      () => repository.addTag(mediaId: 'p1', buddyId: 'alex', diverId: 'A'),
      throwsArgumentError,
    );
    expect(() => repository.addTag(mediaId: 'p1'), throwsArgumentError);
  });

  test('a second tag of the same person on a photo replaces the box', () async {
    final first = await repository.addTag(
      mediaId: 'p1',
      buddyId: 'alex',
      box: box,
    );
    const moved = FaceBox(x: 0.6, y: 0.4, width: 0.1, height: 0.1);
    final second = await repository.addTag(
      mediaId: 'p1',
      buddyId: 'alex',
      box: moved,
    );

    expect(second.id, first.id);
    final tags = await repository.getTagsForMedia('p1', diverId: 'A');
    expect(tags.single.box, moved);
  });

  test('a video keeps one tag per moment for the same person', () async {
    await repository.addTag(
      mediaId: 'v1',
      buddyId: 'alex',
      box: box,
      videoPosition: const Duration(seconds: 42),
    );
    await repository.addTag(
      mediaId: 'v1',
      buddyId: 'alex',
      box: box,
      videoPosition: const Duration(seconds: 118),
    );

    final tags = await repository.getTagsForMedia('v1', diverId: 'A');
    expect(tags.map((t) => t.videoPosition), [
      const Duration(seconds: 42),
      const Duration(seconds: 118),
    ]);
  });

  test('updateTag changes the person and bumps updatedAt', () async {
    final tag = await repository.addTag(
      mediaId: 'p1',
      buddyId: 'alex',
      box: box,
    );
    await (db().delete(db().syncRecords)).go();

    await repository.updateTag(
      tag.copyWith(
        buddyId: 'bea',
        updatedAt: tag.updatedAt.add(const Duration(seconds: 5)),
      ),
    );

    final stored = (await repository.getTagsForMedia(
      'p1',
      diverId: 'A',
    )).single;
    expect(stored.buddyId, 'bea');
    expect(stored.updatedAt.isAfter(tag.updatedAt), isTrue);
    expect(await isPending(tag.id), isTrue);
  });

  test('removeTag deletes and tombstones the row', () async {
    final tag = await repository.addTag(mediaId: 'p1', buddyId: 'alex');

    await repository.removeTag(tag.id);

    expect(await repository.getTagsForMedia('p1', diverId: 'A'), isEmpty);
    expect(await isTombstoned(tag.id), isTrue);
  });

  test('getTagsForMedia shows a profile only its own tags', () async {
    await repository.addTag(mediaId: 'shared', buddyId: 'alex', box: box);
    await repository.addTag(mediaId: 'shared', diverId: 'A', box: box);
    final own = await repository.addTag(mediaId: 'shared', buddyId: 'zed');

    final forB = await repository.getTagsForMedia('shared', diverId: 'B');
    expect(forB.map((t) => t.id), [own.id]);
    final forA = await repository.getTagsForMedia('shared', diverId: 'A');
    expect(forA, hasLength(2));
  });

  test(
    'getTagsForMedia orders Me first, then buddies by name, then moment',
    () async {
      await repository.addTag(
        mediaId: 'v1',
        buddyId: 'bea',
        videoPosition: const Duration(seconds: 5),
      );
      await repository.addTag(
        mediaId: 'v1',
        buddyId: 'alex',
        videoPosition: const Duration(seconds: 90),
      );
      await repository.addTag(
        mediaId: 'v1',
        buddyId: 'alex',
        videoPosition: const Duration(seconds: 10),
      );
      await repository.addTag(mediaId: 'v1', diverId: 'A');

      final chips = await repository.getChipsForMedia('v1', diverId: 'A');
      expect(chips.map((c) => (c.tag.isMe, c.buddyName, c.tag.videoPosition)), [
        (true, null, null),
        (false, 'Alex', const Duration(seconds: 10)),
        (false, 'Alex', const Duration(seconds: 90)),
        (false, 'Bea', const Duration(seconds: 5)),
      ]);
    },
  );

  test(
    'getMediaForBuddy returns each tagged item once, newest first',
    () async {
      await repository.addTag(
        mediaId: 'v1',
        buddyId: 'alex',
        videoPosition: const Duration(seconds: 1),
      );
      await repository.addTag(
        mediaId: 'v1',
        buddyId: 'alex',
        videoPosition: const Duration(seconds: 2),
      );
      await repository.addTag(mediaId: 'p1', buddyId: 'alex');
      await repository.addTag(mediaId: 'p2', buddyId: 'alex');
      await repository.addTag(mediaId: 'p2', buddyId: 'bea');

      final media = await repository.getMediaForBuddy('alex', diverId: 'A');
      expect(media.map((m) => m.id).toSet(), {'v1', 'p1', 'p2'});
      expect(media, hasLength(3));
      expect(media.first.id, 'p2');
    },
  );

  test(
    'getTaggedBuddyIds lists the diver\'s tagged buddies once each',
    () async {
      await repository.addTag(mediaId: 'p1', buddyId: 'alex');
      await repository.addTag(mediaId: 'p2', buddyId: 'alex');
      await repository.addTag(mediaId: 'shared', buddyId: 'zed');
      await repository.addTag(mediaId: 'p1', diverId: 'A');

      expect(await repository.getTaggedBuddyIds(diverId: 'A'), {'alex'});
      expect(await repository.getTaggedBuddyIds(diverId: 'B'), {'zed'});
    },
  );

  test('deleteForBuddies tombstones every tag of those buddies', () async {
    final a = await repository.addTag(mediaId: 'p1', buddyId: 'alex');
    final b = await repository.addTag(mediaId: 'p2', buddyId: 'alex');
    final kept = await repository.addTag(mediaId: 'p1', buddyId: 'bea');

    await repository.deleteForBuddies(['alex']);

    expect(await isTombstoned(a.id), isTrue);
    expect(await isTombstoned(b.id), isTrue);
    expect(await isTombstoned(kept.id), isFalse);
    expect(
      (await repository.getTagsForMedia('p1', diverId: 'A')).single.id,
      kept.id,
    );
  });

  test('deleteForMedia tombstones every tag on that media', () async {
    final a = await repository.addTag(mediaId: 'p1', buddyId: 'alex');
    final kept = await repository.addTag(mediaId: 'p2', buddyId: 'alex');

    await repository.deleteForMedia(['p1']);

    expect(await isTombstoned(a.id), isTrue);
    expect(await isTombstoned(kept.id), isFalse);
  });

  test('FaceBox.clamped keeps the box inside the image', () {
    final b = FaceBox.clamped(x: -0.1, y: 0.95, width: 0.3, height: 0.2);
    expect(b.x, 0);
    expect(b.y + b.height, lessThanOrEqualTo(1));
    expect(b.height, greaterThanOrEqualTo(FaceBox.minSize));
    final tiny = FaceBox.clamped(x: 0.5, y: 0.5, width: 0, height: 0);
    expect(tiny.width, FaceBox.minSize);
  });

  group('one person per photo', () {
    test('a tag without a spot keeps an existing box', () async {
      final boxed = await repository.addTag(
        mediaId: 'p1',
        buddyId: 'alex',
        box: box,
      );
      final again = await repository.addTag(mediaId: 'p1', buddyId: 'alex');

      expect(again.id, boxed.id);
      expect(
        (await repository.getTagsForMedia('p1', diverId: 'A')).single.box,
        box,
      );
    });

    test(
      'tagging someone again at the same video moment moves the box',
      () async {
        final first = await repository.addTag(
          mediaId: 'v1',
          buddyId: 'alex',
          box: box,
          videoPosition: const Duration(milliseconds: 42000),
        );
        const moved = FaceBox(x: 0.6, y: 0.4, width: 0.1, height: 0.1);
        final second = await repository.addTag(
          mediaId: 'v1',
          buddyId: 'alex',
          box: moved,
          videoPosition: const Duration(milliseconds: 42200),
        );

        expect(second.id, first.id);
        final tags = await repository.getTagsForMedia('v1', diverId: 'A');
        expect(tags.single.box, moved);
      },
    );

    test(
      'changing a spot-less tag to someone with a box keeps the box',
      () async {
        final alex = await repository.addTag(
          mediaId: 'p1',
          buddyId: 'alex',
          box: box,
        );
        final bea = await repository.addTag(mediaId: 'p1', buddyId: 'bea');

        await repository.updateTag(bea.copyWith(buddyId: 'alex'));

        final tags = await repository.getTagsForMedia('p1', diverId: 'A');
        expect(tags.single.buddyId, 'alex');
        expect(tags.single.box, box);
        expect(
          await isTombstoned(alex.id) || await isTombstoned(bea.id),
          isTrue,
        );
      },
    );

    test(
      'changing a video tag to someone at that moment leaves one tag',
      () async {
        await repository.addTag(
          mediaId: 'v1',
          buddyId: 'alex',
          box: box,
          videoPosition: const Duration(milliseconds: 42000),
        );
        final bea = await repository.addTag(
          mediaId: 'v1',
          buddyId: 'bea',
          box: box,
          videoPosition: const Duration(milliseconds: 42100),
        );

        await repository.updateTag(bea.copyWith(buddyId: 'alex'));

        final tags = await repository.getTagsForMedia('v1', diverId: 'A');
        expect(tags.map((t) => t.buddyId), ['alex']);
      },
    );

    test('a video keeps one tag without a spot per person', () async {
      final first = await repository.addTag(mediaId: 'v1', buddyId: 'alex');
      final second = await repository.addTag(mediaId: 'v1', buddyId: 'alex');

      expect(second.id, first.id);
      expect(
        await repository.getTagsForMedia('v1', diverId: 'A'),
        hasLength(1),
      );
    });

    test(
      'changing a box to someone already tagged leaves one tag for them',
      () async {
        final bea = await repository.addTag(mediaId: 'p1', buddyId: 'bea');
        final alex = await repository.addTag(
          mediaId: 'p1',
          buddyId: 'alex',
          box: box,
        );

        await repository.updateTag(alex.copyWith(buddyId: 'bea'));

        final tags = await repository.getTagsForMedia('p1', diverId: 'A');
        expect(tags.map((t) => (t.id, t.buddyId, t.box)), [
          (alex.id, 'bea', box),
        ]);
        expect(await isTombstoned(bea.id), isTrue);
      },
    );
  });
}
