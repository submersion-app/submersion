import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart'
    show AppDatabase, BuddiesCompanion, DiveBuddiesCompanion;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/presentation/providers/legacy_buddy_conversion_providers.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';
import '../../helpers/fake_legacy_buddy_conversion_service.dart';

void main() {
  test('the bulk page re-plans on every visit instead of caching', () async {
    // A cached result would keep an empty state after the diver imports
    // dives with buddy text and comes back to the page.
    final service = FakeLegacyBuddyConversionService();
    final container = ProviderContainer(
      overrides: [
        legacyBuddyConversionServiceProvider.overrideWithValue(service),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
      ],
    );
    addTearDown(container.dispose);

    final visit = container.listen(
      linkBuddyNamesDataProvider.future,
      (_, _) {},
    );
    await container.read(linkBuddyNamesDataProvider.future);
    visit.close();
    await pumpEventQueue();

    final again = container.listen(
      linkBuddyNamesDataProvider.future,
      (_, _) {},
    );
    addTearDown(again.close);
    await container.read(linkBuddyNamesDataProvider.future);

    expect(service.planCandidatesCalls, 2);
  });

  group('refreshAfterLegacyBuddyConversion', () {
    // The paginated list's buddy filters read dive_buddies, which its change
    // tick does not watch, so a links-only conversion must reload it.
    late SharedPreferences prefs;
    late AppDatabase db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      db = await setUpTestDatabase();
      final diver = await DiverRepository().createDiver(
        Diver(
          id: '',
          name: 'D',
          isDefault: true,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      );
      await prefs.setString(currentDiverIdKey, diver.id);
      await DiveRepository().createDive(
        Dive(id: 'd1', diverId: diver.id, dateTime: DateTime(2026, 1, 1)),
      );
      await db
          .into(db.buddies)
          .insert(
            BuddiesCompanion.insert(
              id: 'ann',
              name: 'Ann',
              diverId: Value(diver.id),
              createdAt: 1,
              updatedAt: 1,
            ),
          );
    });

    tearDown(tearDownTestDatabase);

    Future<PaginatedDiveListState?> settled(
      ProviderContainer container,
      bool Function(Set<String> ids) done,
    ) async {
      for (var i = 0; i < 200; i++) {
        final state = container.read(paginatedDiveListProvider);
        final value = state.value;
        if (!state.isLoading &&
            value != null &&
            done(value.dives.map((d) => d.id).toSet())) {
          return value;
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      return null;
    }

    test('reloads a buddy-filtered dive list in place', () async {
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      container.read(diveFilterProvider.notifier).state = const DiveFilterState(
        buddyId: 'ann',
      );
      final states = <AsyncValue<PaginatedDiveListState>>[];
      final sub = container.listen(
        paginatedDiveListProvider,
        (_, next) => states.add(next),
      );
      addTearDown(sub.close);
      expect(await settled(container, (ids) => ids.isEmpty), isNotNull);

      // What a conversion writes: a dive_buddies row and nothing else.
      await db
          .into(db.diveBuddies)
          .insert(
            DiveBuddiesCompanion.insert(
              id: 'l1',
              diveId: 'd1',
              buddyId: 'ann',
              createdAt: 1,
            ),
          );
      states.clear();
      refreshAfterLegacyBuddyConversion(container);

      expect(
        await settled(container, (ids) => ids.contains('d1')),
        isNotNull,
        reason: 'the linked dive now matches the buddy filter',
      );
      expect(
        states.where((s) => s.isLoading),
        isEmpty,
        reason: 'an in-place reload keeps the loaded pages on screen',
      );
    });

    test('does not create the dive list when nothing shows it', () async {
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      refreshAfterLegacyBuddyConversion(container);

      expect(container.exists(paginatedDiveListProvider), isFalse);
    });
  });
}
