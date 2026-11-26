import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/marine_life/domain/entities/species_crop.dart';
import 'package:submersion/features/marine_life/domain/practice/leitner.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_gallery_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';
import '../../data/repositories/species_gallery_fixtures.dart';

/// The gallery providers read through their real repositories (issue
/// #5027): one diver, one dive on a trip at a site, one tagged photo with
/// an accepted crop and a depth.
void main() {
  late ProviderContainer container;

  setUp(() async {
    await setUpTestDatabase();
    await insertTestDiver('diver-a');
    await insertTestSite('reef', 'Reef');
    await insertTestTrip('bonaire', 'Bonaire', DateTime.utc(2025, 3, 1));
    await insertTestDive(
      id: 'd1',
      at: DateTime.utc(2025, 3, 10),
      diverId: 'diver-a',
      siteId: 'reef',
    );
    await setDiveTrip('d1', 'bonaire');
    await insertTestSpecies(id: 'grouper', name: 'Grouper');
    await insertTestSighting(id: 's1', diveId: 'd1', speciesId: 'grouper');
    await insertTestMedia(
      id: 'p1',
      diveId: 'd1',
      takenAt: DateTime.utc(2025, 3, 10, 9),
    );
    await insertTestTag(mediaId: 'p1', speciesId: 'grouper');
    await insertTestIdentification(
      id: 'i1',
      mediaId: 'p1',
      speciesId: 'grouper',
    );
    await insertTestDepth(mediaId: 'p1', diveId: 'd1', depth: 12);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier()..setCurrentDiver('diver-a'),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  test('crops, best crop and pictures come from the database', () async {
    final best = await container.read(speciesBestCropsProvider.future);
    expect(best['grouper']!.identificationId, 'i1');
    final crops = await container.read(speciesCropsProvider('grouper').future);
    expect(crops.single.mediaId, 'p1');
    final pictures = await container.read(speciesPicturesProvider.future);
    expect(pictures['grouper'], isA<CropPicture>());
    expect(
      await container.read(speciesPicturesCompleteProvider.future),
      isTrue,
    );
  });

  test('a cover set through the repository becomes the picture', () async {
    await container
        .read(speciesCoverRepositoryProvider)
        .setCover(
          diverId: 'diver-a',
          speciesId: 'grouper',
          mediaId: 'p1',
          identificationId: 'i1',
        );
    expect(
      (await container.read(speciesCoversProvider.future))['grouper']!.mediaId,
      'p1',
    );
    expect(
      (await container.read(
        speciesCoverCropsProvider.future,
      ))['grouper']!.identificationId,
      'i1',
    );
    expect(await container.read(speciesCoverPhotosProvider.future), isEmpty);
  });

  test('a photo cover with no crop is read back as a photo', () async {
    await container
        .read(speciesCoverRepositoryProvider)
        .setCover(diverId: 'diver-a', speciesId: 'grouper', mediaId: 'p1');
    final photos = await container.read(speciesCoverPhotosProvider.future);
    expect(photos['grouper']!.id, 'p1');
  });

  test('places, months and depths come from the database', () async {
    final places = await container.read(speciesPlacesProvider.future);
    expect(places.tripsBySpecies['grouper']!.single.name, 'Bonaire');
    final months = await container.read(
      speciesMonthCountsProvider('grouper').future,
    );
    expect(months[2], 1);
    final depths = await container.read(
      speciesPhotoDepthsProvider('grouper').future,
    );
    expect(depths, [12]);
  });

  test('practice pool and states come from the database', () async {
    final pool = await container.read(speciesPracticePoolProvider.future);
    expect(pool['grouper']!.single.identificationId, 'i1');
    await container
        .read(speciesPracticeRepositoryProvider)
        .save('diver-a', PracticeState.fresh('grouper', DateTime.utc(2026)));
    final states = await container.read(speciesPracticeStatesProvider.future);
    expect(states['grouper']!.box, 1);
  });
}
