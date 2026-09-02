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
    await insertTestSpecies(id: 'c1', name: 'Grouper');
    await insertTestSighting(id: 'sg1', diveId: 'd1', speciesId: 'c1');
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

  test('mediaForSpeciesProvider refreshes when a tag is added', () async {
    final container = makeContainer();
    final sub = container.listen(mediaForSpeciesProvider('c1'), (_, _) {});
    addTearDown(sub.close);
    expect(await container.read(mediaForSpeciesProvider('c1').future), isEmpty);

    await tags.addTag(mediaId: 'p2', speciesId: 'c1');

    final items = await _eventually(
      () => container.read(mediaForSpeciesProvider('c1').future),
      (v) => v.isNotEmpty,
    );
    expect(items.single.id, 'p2');
  });

  test(
    'speciesTagCandidatesProvider drops a photo once it is tagged',
    () async {
      final container = makeContainer();
      final sub = container.listen(
        speciesTagCandidatesProvider('c1'),
        (_, _) {},
      );
      addTearDown(sub.close);
      final before = await container.read(
        speciesTagCandidatesProvider('c1').future,
      );
      expect(before.single.items.map((m) => m.id).toList(), ['p1', 'p2']);

      await tags.addTag(mediaId: 'p1', speciesId: 'c1', sightingId: 'sg1');

      final after = await _eventually(
        () => container.read(speciesTagCandidatesProvider('c1').future),
        (v) => v.single.items.length == 1,
      );
      expect(after.single.items.single.id, 'p2');
    },
  );

  test('mediaTagChipsProvider lists chips and refreshes on removal', () async {
    await tags.addTag(mediaId: 'p1', speciesId: 'c1');
    final container = makeContainer();
    final sub = container.listen(mediaTagChipsProvider('p1'), (_, _) {});
    addTearDown(sub.close);
    final chips = await container.read(mediaTagChipsProvider('p1').future);
    expect(chips.single.storedName, 'Grouper');

    await tags.removeTag(mediaId: 'p1', speciesId: 'c1');

    final after = await _eventually(
      () => container.read(mediaTagChipsProvider('p1').future),
      (v) => v.isEmpty,
    );
    expect(after, isEmpty);
  });
}
