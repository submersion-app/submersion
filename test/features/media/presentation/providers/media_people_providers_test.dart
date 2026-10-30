import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/media/data/repositories/media_people_repository.dart';
import 'package:submersion/features/media/presentation/providers/media_people_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';
import '../../data/repositories/species_photo_fixtures.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    final db = await setUpTestDatabase();
    await insertTestDiver('A');
    await insertTestDiver('B');
    await insertTestDive(id: 'd1', at: DateTime(2024, 1, 10), diverId: 'A');
    await insertTestBuddy(id: 'alex', name: 'Alex', diverId: 'A');
    await insertTestBuddy(id: 'bea', name: 'Bea', diverId: 'A');
    await insertTestBuddy(id: 'cal', name: 'Cal', diverId: 'A');
    await insertTestBuddy(id: 'zed', name: 'Zed', diverId: 'B');
    await insertTestMedia(id: 'p1', diveId: 'd1');
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.customStatement(
      'INSERT INTO dive_buddies (id, dive_id, buddy_id, role, created_at) '
      "VALUES ('db1', 'd1', 'cal', 'buddy', $now)",
    );
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final diver = MockCurrentDiverIdNotifier();
    await diver.setCurrentDiver('A');
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        currentDiverIdProvider.overrideWith((ref) => diver),
      ],
    );
    addTearDown(container.dispose);
  });
  tearDown(tearDownTestDatabase);

  test('chips refresh after a tag is added', () async {
    final sub = container.listen(mediaPeopleChipsProvider('p1'), (_, _) {});
    addTearDown(sub.close);
    expect(
      await container.read(mediaPeopleChipsProvider('p1').future),
      isEmpty,
    );

    await MediaPeopleRepository().addTag(mediaId: 'p1', buddyId: 'alex');
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final chips = await container.read(mediaPeopleChipsProvider('p1').future);
    expect(chips.single.buddyName, 'Alex');
  });

  test('picker options split the dive\'s buddies from the rest', () async {
    final options = await container.read(
      personPickerOptionsProvider('d1').future,
    );

    expect(options.meDiverId, 'A');
    expect(options.onThisDive.map((b) => b.id), ['cal']);
    expect(options.everyoneElse.map((b) => b.id), ['alex', 'bea']);
  });

  test('picker options without a dive list everyone else only', () async {
    final options = await container.read(
      personPickerOptionsProvider(null).future,
    );

    expect(options.onThisDive, isEmpty);
    expect(options.everyoneElse.map((b) => b.id), ['alex', 'bea', 'cal']);
  });
}
