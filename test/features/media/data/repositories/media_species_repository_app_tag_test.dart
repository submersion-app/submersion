import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';

import '../../../../helpers/test_database.dart';
import 'species_photo_fixtures.dart';

/// The marks on a species tag the app applied (issue #4727).
void main() {
  late MediaSpeciesRepository tags;

  setUp(() async {
    await setUpTestDatabase();
    tags = MediaSpeciesRepository();
    await insertTestSite('s1', 'Blue Hole');
    await insertTestDive(id: 'd1', at: DateTime(2024, 1, 10), siteId: 's1');
    await insertTestDive(id: 'd2', at: DateTime(2024, 1, 11), siteId: 's1');
    await insertTestSpecies(id: 'sp_a', name: 'Queen Parrotfish');
    await insertTestSpecies(id: 'sp_b', name: 'Blue Tang');
    await insertTestMedia(id: 'p1', diveId: 'd1');
    await insertTestMedia(id: 'p2', diveId: 'd2');
  });

  tearDown(tearDownTestDatabase);

  test('an app tag keeps its marks', () async {
    await tags.addTag(
      mediaId: 'p1',
      speciesId: 'sp_a',
      unconfirmed: true,
      createdSighting: true,
    );

    final tag = await tags.findTag('p1', 'sp_a');
    expect(tag!.unconfirmed, isTrue);
    expect(tag.createdSighting, isTrue);
    expect(tag.createdSpecies, isFalse);
  });

  test('a hand tag carries no marks', () async {
    await tags.addTag(mediaId: 'p1', speciesId: 'sp_a');

    final tag = await tags.findTag('p1', 'sp_a');
    expect(tag!.unconfirmed, isFalse);
    expect(tag.createdSighting, isFalse);
    expect(tag.createdSpecies, isFalse);
  });

  test('confirming clears every mark, links the sighting and restamps the '
      'clock', () async {
    await insertTestSighting(id: 'sg1', diveId: 'd1', speciesId: 'sp_a');
    await tags.addTag(
      mediaId: 'p1',
      speciesId: 'sp_a',
      unconfirmed: true,
      createdSighting: true,
      createdSpecies: true,
    );
    final before = await tags.findTag('p1', 'sp_a');

    await tags.confirmTag(mediaId: 'p1', speciesId: 'sp_a', sightingId: 'sg1');

    final after = await tags.findTag('p1', 'sp_a');
    expect(after!.unconfirmed, isFalse);
    expect(after.createdSighting, isFalse);
    expect(after.createdSpecies, isFalse);
    expect(after.sightingId, 'sg1');
    expect(after.hlc, isNotNull);
    expect(after.hlc, isNot(before!.hlc));
  });

  test('confirming a hand tag changes nothing', () async {
    await tags.addTag(mediaId: 'p1', speciesId: 'sp_a');
    final before = await tags.findTag('p1', 'sp_a');

    await tags.confirmTag(mediaId: 'p1', speciesId: 'sp_a');

    expect(await tags.findTag('p1', 'sp_a'), before);
  });

  test('unconfirmed tags, for one dive or the whole log', () async {
    await tags.addTag(mediaId: 'p1', speciesId: 'sp_a', unconfirmed: true);
    await tags.addTag(mediaId: 'p1', speciesId: 'sp_b');
    await tags.addTag(mediaId: 'p2', speciesId: 'sp_b', unconfirmed: true);

    final onD1 = await tags.unconfirmedTags(diveId: 'd1');
    expect([for (final t in onD1) '${t.mediaId}/${t.speciesId}'], ['p1/sp_a']);

    final all = await tags.unconfirmedTags();
    expect(
      {for (final t in all) '${t.mediaId}/${t.speciesId}'},
      {'p1/sp_a', 'p2/sp_b'},
    );
  });

  test('a chip says whether its tag is unconfirmed', () async {
    await tags.addTag(mediaId: 'p1', speciesId: 'sp_a', unconfirmed: true);
    await tags.addTag(mediaId: 'p1', speciesId: 'sp_b');

    final chips = await tags.getTagChipsForMedia('p1');
    expect(
      {for (final c in chips) c.speciesId: c.unconfirmed},
      {'sp_a': true, 'sp_b': false},
    );
  });
}
