import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

import '../../../../helpers/shared_items_fixture.dart';
import '../../../../helpers/test_database.dart';

/// The trip list deletes as the owner and hides for everyone else
/// (issue #2594).
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

  Future<ProviderContainer> containerFor(String diverId) async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => diverId),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(tripListNotifierProvider, (_, _) {});
    addTearDown(sub.close);
    while (container.read(tripListNotifierProvider).isLoading) {
      await Future<void>.delayed(Duration.zero);
    }
    return container;
  }

  List<String> listed(ProviderContainer c) => [
    for (final t in c.read(tripListNotifierProvider).value ?? const [])
      t.trip.id,
  ];

  test('a non-owner cannot delete it but hides and unhides it', () async {
    final c = await containerFor('b');
    final notifier = c.read(tripListNotifierProvider.notifier);
    expect(await notifier.deleteTrip('shared'), isFalse);
    expect(await TripRepository().getTripById('shared'), isNotNull);

    expect(await notifier.hideTrip('shared'), isTrue);
    expect(listed(c), isEmpty);

    await notifier.unhideTrip('shared');
    expect(listed(c), ['shared']);
  });

  test('the owner deletes it', () async {
    final c = await containerFor('a');
    expect(
      await c.read(tripListNotifierProvider.notifier).deleteTrip('shared'),
      isTrue,
    );
    expect(await TripRepository().getTripById('shared'), isNull);
  });

  test('hideTrips hides a batch and counts only what it hid', () async {
    await seedTrip(db, 'second', owner: 'a', shared: true);
    await seedTrip(db, 'own', owner: 'b', shared: true);
    final c = await containerFor('b');
    final hidden = await c.read(tripListNotifierProvider.notifier).hideTrips([
      'shared',
      'second',
      'own',
    ]);
    expect(hidden, 2);
    expect(listed(c), ['own']);
  });
}
