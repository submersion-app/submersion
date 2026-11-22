import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/outing_cover_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late OutingCoverRepository repo;

  Future<void> media(
    String id, {
    String? diveId = 'd1',
    String type = 'photo',
    bool favorite = false,
    bool orphaned = false,
    int? takenAt,
  }) => db
      .into(db.media)
      .insert(
        MediaCompanion.insert(
          id: id,
          diveId: Value(diveId),
          filePath: '/$id.jpg',
          fileType: Value(type),
          isFavorite: Value(favorite),
          isOrphaned: Value(orphaned),
          takenAt: Value(takenAt),
          createdAt: 0,
          updatedAt: 0,
        ),
      );

  setUp(() async {
    db = await setUpTestDatabase();
    repo = OutingCoverRepository();
    for (final id in ['d1', 'd2', 'd3']) {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion(
              id: Value(id),
              diveDateTime: const Value(0),
              createdAt: const Value(0),
              updatedAt: const Value(0),
            ),
          );
    }
    await db
        .into(db.species)
        .insert(
          SpeciesCompanion.insert(
            id: 'sp',
            commonName: 'Turtle',
            category: 'reptile',
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  test('candidates are the photos and videos on the given dives', () async {
    await media('photo', favorite: true, takenAt: 1000);
    await media('clip', type: 'video');
    await media('signature', type: 'instructor_signature');
    await media('document', type: 'document');
    await media('lost', orphaned: true);
    await media('siteOnly', diveId: null);
    await media('tagged', diveId: 'd2');
    await media('elsewhere', diveId: 'd3');
    await db
        .into(db.mediaSpecies)
        .insert(
          MediaSpeciesCompanion.insert(
            id: 'ms',
            mediaId: 'tagged',
            speciesId: 'sp',
            createdAt: 0,
          ),
        );
    // A tag still awaiting the diver's confirmation does not count.
    await media('pending', diveId: 'd2');
    await db
        .into(db.mediaSpecies)
        .insert(
          MediaSpeciesCompanion.insert(
            id: 'ms2',
            mediaId: 'pending',
            speciesId: 'sp',
            createdAt: 0,
            unconfirmed: const Value(1),
          ),
        );

    final found = await repo.getCoverCandidates(['d1', 'd2']);
    final byId = {for (final c in found) c.mediaId: c};
    expect(byId.keys, unorderedEquals(['photo', 'clip', 'tagged', 'pending']));
    expect(byId['photo']!.isFavorite, isTrue);
    expect(byId['photo']!.diveId, 'd1');
    expect(byId['photo']!.takenAt, isNotNull);
    expect(byId['clip']!.isVideo, isTrue);
    expect(byId['tagged']!.hasSpeciesTag, isTrue);
    expect(byId['photo']!.hasSpeciesTag, isFalse);
    expect(byId['pending']!.hasSpeciesTag, isFalse);
  });

  test('no dives read nothing', () async {
    await media('photo');
    expect(await repo.getCoverCandidates(const []), isEmpty);
    expect(await repo.getMediaByIds(const []), isEmpty);
  });

  test('media by id returns the requested items', () async {
    await media('a');
    await media('b');
    await media('c');
    final items = await repo.getMediaByIds(['a', 'c']);
    expect(items.map((m) => m.id), unorderedEquals(['a', 'c']));
  });
}
