import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/data/repositories/profile_hides_repository.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/profile_hides_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/shared_items_fixture.dart';
import '../../../../helpers/test_database.dart';

/// The active profile's hidden trips and sites (issue #2594).
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

  test('isHiddenProvider follows the active profile\'s hide (#2679)', () async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'b'),
      ],
    );
    addTearDown(container.dispose);
    const key = (kind: SharedItemKind.trip, id: 'shared');
    final sub = container.listen(isHiddenProvider(key), (_, _) {});
    addTearDown(sub.close);
    expect(await container.read(isHiddenProvider(key).future), isFalse);

    final hides = container.read(profileHidesRepositoryProvider);
    await hides.hide(SharedItemKind.trip, 'shared', 'b');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await container.read(isHiddenProvider(key).future), isTrue);

    await hides.unhide(SharedItemKind.trip, 'shared', 'b');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await container.read(isHiddenProvider(key).future), isFalse);
  });

  test('isHiddenProvider is false for another profile\'s hide', () async {
    await ProfileHidesRepository().hide(SharedItemKind.trip, 'shared', 'b');
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'a'),
      ],
    );
    addTearDown(container.dispose);
    expect(
      await container.read(
        isHiddenProvider((kind: SharedItemKind.trip, id: 'shared')).future,
      ),
      isFalse,
    );
  });
}
