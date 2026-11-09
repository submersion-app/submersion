import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/card_photo_repository.dart';
import 'package:submersion/features/dive_log/domain/card_photo/card_photo.dart';
import 'package:submersion/features/dive_log/domain/card_photo/focus_box.dart';
import 'package:submersion/features/media/data/repositories/media_people_repository.dart';
import 'package:submersion/features/media/domain/entities/media_person_tag.dart';

import '../../../../helpers/test_database.dart';
import '../../../media/data/repositories/species_photo_fixtures.dart';

void main() {
  late CardPhotoRepository repository;
  AppDatabase db() => DatabaseService.instance.database;

  setUp(() async {
    await setUpTestDatabase();
    repository = CardPhotoRepository();
    await insertTestDiver('A');
    await insertTestDive(id: 'd1', at: DateTime(2024, 1, 10), diverId: 'A');
    await insertTestDive(id: 'd2', at: DateTime(2024, 2, 10), diverId: 'A');
    await insertTestDive(id: 'd3', at: DateTime(2024, 3, 10), diverId: 'A');
    await insertTestBuddy(id: 'alex', name: 'Alex', diverId: 'A');
  });

  tearDown(tearDownTestDatabase);

  test('groups each dive photo under its dive', () async {
    await insertTestMedia(id: 'p1', diveId: 'd1');
    await insertTestMedia(id: 'p2', diveId: 'd1');
    await insertTestMedia(id: 'p3', diveId: 'd2');

    final byDive = await repository.getCardPhotosByDive(diverId: 'A');

    expect(byDive.keys, unorderedEquals(['d1', 'd2']));
    expect(byDive['d1']!.map((p) => p.mediaId), unorderedEquals(['p1', 'p2']));
    expect(byDive['d2']!.single.mediaId, 'p3');
  });

  test('leaves out videos, documents, signatures and unlinked media', () async {
    await insertTestMedia(id: 'v1', diveId: 'd1', fileType: 'video');
    await insertTestMedia(id: 'doc', diveId: 'd1', fileType: 'document');
    await insertTestMedia(
      id: 'sig',
      diveId: 'd1',
      fileType: 'instructor_signature',
    );
    await insertTestMedia(id: 'loose');

    expect(await repository.getCardPhotosByDive(diverId: 'A'), isEmpty);
  });

  test('leaves out photos whose file is missing', () async {
    await insertTestMedia(id: 'p1', diveId: 'd3');
    await (db().update(db().media)..where((t) => t.id.equals('p1'))).write(
      const MediaCompanion(isOrphaned: Value(true)),
    );

    expect(await repository.getCardPhotosByDive(diverId: 'A'), isEmpty);
  });

  test('carries the boxes of people tagged on the photo', () async {
    await insertTestMedia(id: 'p1', diveId: 'd1');
    await insertTestMedia(id: 'p2', diveId: 'd1');
    final people = MediaPeopleRepository();
    await people.addTag(
      mediaId: 'p1',
      buddyId: 'alex',
      box: const FaceBox(x: 0.2, y: 0.3, width: 0.1, height: 0.2),
    );
    // A tag without a spot says nothing about where the subject is.
    await people.addTag(mediaId: 'p2', buddyId: 'alex');

    final photos = {
      for (final p in (await repository.getCardPhotosByDive(
        diverId: 'A',
      ))['d1']!)
        p.mediaId: p,
    };

    expect(
      photos['p1'],
      const CardPhoto(
        mediaId: 'p1',
        focusBoxes: [FocusBox(x: 0.2, y: 0.3, width: 0.1, height: 0.2)],
      ),
    );
    expect(photos['p2']!.focusBoxes, isEmpty);
  });

  group("only the diver's own tags place the crop", () {
    const box = FaceBox(x: 0.2, y: 0.3, width: 0.1, height: 0.2);
    const focus = FocusBox(x: 0.2, y: 0.3, width: 0.1, height: 0.2);

    setUp(() async {
      await insertTestMedia(id: 'p1', diveId: 'd1');
      await insertTestDiver('B');
      await insertTestBuddy(id: 'bo', name: 'Bo', diverId: 'B');
    });

    Future<List<FocusBox>> boxes({String? diverId = 'A'}) async =>
        (await repository.getCardPhotosByDive(
          diverId: diverId,
        ))['d1']!.single.focusBoxes;

    test("the diver's own Me tag counts", () async {
      await MediaPeopleRepository().addTag(
        mediaId: 'p1',
        diverId: 'A',
        box: box,
      );

      expect(await boxes(), [focus]);
    });

    test("another profile's buddy tag on a shared photo does not", () async {
      await MediaPeopleRepository().addTag(
        mediaId: 'p1',
        buddyId: 'bo',
        box: box,
      );

      expect(await boxes(), isEmpty);
      // Seen as B, the same tag is B's own.
      expect(await boxes(diverId: 'B'), [focus]);
    });

    test("another profile's Me tag does not", () async {
      await MediaPeopleRepository().addTag(
        mediaId: 'p1',
        diverId: 'B',
        box: box,
      );

      expect(await boxes(), isEmpty);
    });

    test('a tag that names nobody does not, whoever is looking', () async {
      final ms = DateTime(2024).millisecondsSinceEpoch;
      await db().customStatement(
        'INSERT INTO media_people (id, media_id, bbox_x, bbox_y, bbox_width, '
        'bbox_height, created_at, updated_at) '
        "VALUES ('t-none', 'p1', 0.2, 0.3, 0.1, 0.2, $ms, $ms)",
      );

      expect(await boxes(), isEmpty);
      expect(await boxes(diverId: null), isEmpty);
    });

    test('with no profile chosen, every named tag counts', () async {
      await MediaPeopleRepository().addTag(
        mediaId: 'p1',
        buddyId: 'bo',
        box: box,
      );

      expect(await boxes(diverId: null), [focus]);
    });
  });

  test('offers a photo by any spelling the app reads as a photo', () async {
    // parseMediaType reads every file_type outside kNonPhotoFileTypes as a
    // photo, so the gallery shows this row; the card offers it too.
    await insertTestMedia(id: 'legacy', diveId: 'd1', fileType: 'image');
    await insertTestMedia(
      id: 'buddy',
      diveId: 'd1',
      fileType: 'buddy_signature',
    );

    final byDive = await repository.getCardPhotosByDive(diverId: 'A');

    expect(byDive['d1']!.single.mediaId, 'legacy');
  });

  test('reads no boxes for a photo whose file is missing', () async {
    await insertTestMedia(id: 'p1', diveId: 'd1');
    await insertTestMedia(id: 'gone', diveId: 'd1');
    await MediaPeopleRepository().addTag(
      mediaId: 'gone',
      buddyId: 'alex',
      box: const FaceBox(x: 0.2, y: 0.3, width: 0.1, height: 0.2),
    );
    await (db().update(db().media)..where((t) => t.id.equals('gone'))).write(
      const MediaCompanion(isOrphaned: Value(true)),
    );

    final byDive = await repository.getCardPhotosByDive(diverId: 'A');

    expect(byDive['d1']!.single, const CardPhoto(mediaId: 'p1'));
  });

  test(
    'ticks when a person is tagged, which writes only media_people',
    () async {
      await insertTestMedia(id: 'p1', diveId: 'd1');
      var ticks = 0;
      final sub = repository.watchChanges().listen((_) => ticks++);
      addTearDown(sub.cancel);
      // Let the media insert's own tick land first.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final before = ticks;

      await MediaPeopleRepository().addTag(
        mediaId: 'p1',
        buddyId: 'alex',
        box: const FaceBox(x: 0.2, y: 0.3, width: 0.1, height: 0.2),
      );
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(ticks, greaterThan(before));
    },
  );
}
