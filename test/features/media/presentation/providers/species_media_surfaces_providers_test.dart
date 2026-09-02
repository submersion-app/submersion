import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';
import '../../data/repositories/species_photo_fixtures.dart';

Future<T> _eventually<T>(
  Future<T> Function() read,
  bool Function(T value) until,
) async {
  late T value;
  for (var i = 0; i < 50; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    value = await read();
    if (until(value)) break;
  }
  return value;
}

void main() {
  late SharedPreferences prefs;
  late MediaSpeciesRepository tags;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    tags = MediaSpeciesRepository();
    await insertTestDive(id: 'd1', at: DateTime(2024, 1, 10));
    await insertTestDive(id: 'd2', at: DateTime(2024, 2, 10));
    await insertTestSpecies(id: 'c1', name: 'Grouper');
    await insertTestSpecies(id: 'c2', name: 'Wrasse');
    await insertTestMedia(
      id: 'p1',
      diveId: 'd1',
      takenAt: DateTime(2024, 1, 10, 9),
    );
    await insertTestMedia(
      id: 'p2',
      diveId: 'd1',
      takenAt: DateTime(2024, 1, 10, 10),
    );
    await insertTestMedia(
      id: 'p3',
      diveId: 'd2',
      takenAt: DateTime(2024, 2, 10, 9),
    );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'speciesCoverMediaProvider maps species to their newest photo',
    () async {
      await tags.addTag(mediaId: 'p1', speciesId: 'c1');
      await tags.addTag(mediaId: 'p3', speciesId: 'c1');
      await tags.addTag(mediaId: 'p2', speciesId: 'c2');
      final container = makeContainer();
      final sub = container.listen(speciesCoverMediaProvider, (_, _) {});
      addTearDown(sub.close);

      final covers = await container.read(speciesCoverMediaProvider.future);

      expect(covers['c1']!.id, 'p3');
      expect(covers['c2']!.id, 'p2');
    },
  );

  test('speciesCoverMediaProvider refreshes when a tag is added', () async {
    final container = makeContainer();
    final sub = container.listen(speciesCoverMediaProvider, (_, _) {});
    addTearDown(sub.close);
    expect(await container.read(speciesCoverMediaProvider.future), isEmpty);

    await tags.addTag(mediaId: 'p1', speciesId: 'c1');

    final covers = await _eventually(
      () => container.read(speciesCoverMediaProvider.future),
      (v) => v.isNotEmpty,
    );
    expect(covers['c1']!.id, 'p1');
  });

  test(
    'diveSpeciesPhotoCountsProvider counts per species on one dive',
    () async {
      await tags.addTag(mediaId: 'p1', speciesId: 'c1');
      await tags.addTag(mediaId: 'p2', speciesId: 'c1');
      await tags.addTag(mediaId: 'p3', speciesId: 'c1');
      final container = makeContainer();
      final sub = container.listen(
        diveSpeciesPhotoCountsProvider('d1'),
        (_, _) {},
      );
      addTearDown(sub.close);

      expect(
        await container.read(diveSpeciesPhotoCountsProvider('d1').future),
        {'c1': 2},
      );
    },
  );

  test(
    "mediaForDiveSpeciesProvider keeps only the dive's photos of the species",
    () async {
      await tags.addTag(mediaId: 'p1', speciesId: 'c1');
      await tags.addTag(mediaId: 'p2', speciesId: 'c2');
      await tags.addTag(mediaId: 'p3', speciesId: 'c1');
      final container = makeContainer();
      const key = (diveId: 'd1', speciesId: 'c1');
      final sub = container.listen(mediaForDiveSpeciesProvider(key), (_, _) {});
      addTearDown(sub.close);

      final items = await container.read(
        mediaForDiveSpeciesProvider(key).future,
      );

      expect(items.map((m) => m.id).toList(), ['p1']);
    },
  );
}
