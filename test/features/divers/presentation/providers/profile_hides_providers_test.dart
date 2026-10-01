import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
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

  test('drops a hidden trip or site once its owner unshares it', () async {
    await seedSite(db, 'pier', owner: 'a', shared: true);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'b'),
      ],
    );
    addTearDown(container.dispose);
    final hides = container.read(profileHidesRepositoryProvider);
    await hides.hide(SharedItemKind.trip, 'shared', 'b');
    await hides.hide(SharedItemKind.site, 'pier', 'b');
    // Waits on the provider's own refresh, not a fixed delay.
    Future<List<String>> next(bool Function(List<String>) done) {
      final ids = Completer<List<String>>();
      final sub = container.listen(hiddenItemsProvider, (_, state) {
        if (ids.isCompleted) return;
        if (state.hasError) {
          ids.completeError(state.error!, state.stackTrace);
          return;
        }
        final value = state.value?.map((i) => i.id).toList();
        if (value != null && done(value)) ids.complete(value);
      }, fireImmediately: true);
      return ids.future
          .timeout(const Duration(seconds: 5))
          .whenComplete(sub.close);
    }

    expect(await next((ids) => ids.length == 2), ['shared', 'pier']);

    await TripRepository().setShared('shared', false, actingDiverId: 'a');
    expect(await next((ids) => ids.length == 1), ['pier']);

    await SiteRepository().setShared('pier', false, actingDiverId: 'a');
    expect(await next((ids) => ids.isEmpty), isEmpty);
  });
}
