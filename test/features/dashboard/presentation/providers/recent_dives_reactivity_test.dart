import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

import '../../../../helpers/test_database.dart';
import '../../../../helpers/mock_providers.dart';

/// Regression test for issue #217: the home tab "recent dives" card showed
/// stale data after a dive-computer import or an iCloud sync wrote the dives
/// table directly. The dive LIST refreshed but the home tab did not, so it kept
/// showing the pre-import slice (e.g. dive 144 in place of the new 145) until an
/// app restart.
///
/// `recentDivesProvider` self-invalidates on any `dives`-table write -- both
/// directly (its own [DiveRepository.watchDivesChanges] subscription) and
/// transitively through [divesProvider], which self-invalidates on the same
/// tick. This guards that the home tab recent-dives list reflects a direct DB
/// write -- the same path an import or a sync takes -- without any manual
/// invalidation.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  ProviderContainer makeContainer() => ProviderContainer(
    overrides: [
      // Null current diver => getAllDives returns every dive (no filter),
      // matching the dives created below (which have a null diverId).
      currentDiverIdProvider.overrideWith(
        (ref) => MockCurrentDiverIdNotifier(),
      ),
    ],
  );

  test(
    'recentDivesProvider reflects a dive written while the dashboard was not '
    'listening (issue #217)',
    () async {
      final repository = DiveRepository();
      // Pre-existing dives. All share the helper's entryTime, so newest-first
      // ordering falls back to diveNumber DESC => [3, 2, 1].
      for (final n in [1, 2, 3]) {
        await repository.createDive(
          createTestDiveWithBottomTime(id: 'd$n', diveNumber: n),
        );
      }

      final container = makeContainer();
      addTearDown(container.dispose);

      // Dashboard is on screen: an active listener builds the provider chain,
      // exactly like RecentDivesCard watching recentDivesProvider.
      final onScreen = container.listen(recentDivesProvider, (_, _) {});
      final initial = await container.read(recentDivesProvider.future);
      expect(
        initial.map((d) => d.diveNumber).toList(),
        [3, 2, 1],
        reason: 'pre-import recent dives',
      );

      // User leaves the dashboard to run the import flow. The card unmounts, so
      // it stops listening. recentDivesProvider is a kept-alive (non
      // autoDispose) FutureProvider, so it retains its stale cached slice.
      onScreen.close();

      // The dive-computer import (or an iCloud sync) writes a new most-recent
      // dive straight to the database -- no notifier mutation.
      await repository.createDive(
        createTestDiveWithBottomTime(id: 'd4', diveNumber: 4),
      );

      // User returns to the dashboard: the card re-subscribes.
      final backOnScreen = container.listen(recentDivesProvider, (_, _) {});
      addTearDown(backOnScreen.close);

      // Poll until the dives-table tick -> invalidate -> rebuild settles.
      List<int?> numbers = const [];
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        final dives = await container.read(recentDivesProvider.future);
        numbers = dives.map((d) => d.diveNumber).toList();
        if (numbers.contains(4)) break;
      }

      expect(
        numbers,
        [4, 3, 2],
        reason:
            'After an import/sync writes a new most-recent dive while the '
            'dashboard was backgrounded, the home tab recent-dives list must '
            'show it on return (issue #217), not the stale pre-import slice.',
      );
    },
  );
}
