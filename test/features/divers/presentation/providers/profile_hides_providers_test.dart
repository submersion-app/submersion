import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/profile_hides_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';

import '../../../../helpers/shared_items_fixture.dart';
import '../../../../helpers/test_database.dart';

/// The active profile's hidden trips and sites (issues #2594, #2678).
void main() {
  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = await setUpTestDatabase();
    await seedDivers(db, ['a', 'b']);
    await seedTrip(db, 'shared', owner: 'a', shared: true);
  });

  tearDown(tearDownTestDatabase);

  test('lists the active profile\'s hides and refreshes on a hide', () async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'b'),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(hiddenItemsProvider, (_, _) {});
    addTearDown(sub.close);
    expect(await container.read(hiddenItemsProvider.future), isEmpty);

    await container
        .read(profileHidesRepositoryProvider)
        .hide(SharedItemKind.trip, 'shared', 'b');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(
      (await container.read(hiddenItemsProvider.future)).single.id,
      'shared',
    );
  });

  test('drops a hidden trip once its owner unshares it', () async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'b'),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(profileHidesRepositoryProvider)
        .hide(SharedItemKind.trip, 'shared', 'b');
    final sub = container.listen(hiddenItemsProvider, (_, _) {});
    addTearDown(sub.close);
    expect(await container.read(hiddenItemsProvider.future), hasLength(1));

    await TripRepository().setShared('shared', false, actingDiverId: 'a');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await container.read(hiddenItemsProvider.future), isEmpty);
  });
}
