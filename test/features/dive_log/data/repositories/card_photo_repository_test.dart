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

    final byDive = await repository.getCardPhotosByDive();

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

    expect(await repository.getCardPhotosByDive(), isEmpty);
  });

  test('leaves out photos whose file is missing', () async {
    await insertTestMedia(id: 'p1', diveId: 'd3');
    await (db().update(db().media)..where((t) => t.id.equals('p1'))).write(
      const MediaCompanion(isOrphaned: Value(true)),
    );

    expect(await repository.getCardPhotosByDive(), isEmpty);
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
      for (final p in (await repository.getCardPhotosByDive())['d1']!)
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
}
