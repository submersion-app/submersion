import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/test_database.dart';

/// Regression test for the statistics half of issue #974.
///
/// Every provider in `statistics_providers.dart` except one used to get its
/// reactivity from `_keepAliveWithExpiry`, whose only trigger was
/// `ref.watch(statisticsVersionProvider)`. That counter was incremented from
/// exactly one line in the entire app, inside `PaginatedDiveListNotifier`.
/// Merge, consolidate, import, and sync pulls never reached it.
///
/// The user-visible symptom: merge two dives, open Statistics inside the
/// five-minute keepAlive window, and every chart still counts the merged-away
/// dive. `_keepAliveWithExpiry`'s own doc comment claimed the providers
/// "refresh when dives are mutated", which is what let this go unnoticed
/// across 33 providers.
///
/// These tests write straight to the database through the same repository path
/// merge and consolidate use, with no notifier involved, and assert the
/// statistics providers follow.
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
      // Null current diver => statistics cover every dive, matching the dives
      // created below (which have a null diverId).
      currentDiverIdProvider.overrideWith(
        (ref) => MockCurrentDiverIdNotifier(),
      ),
      // statisticsRepositoryProvider watches the gas model (issue #828), which
      // otherwise pulls in settingsProvider and its SharedPreferences
      // dependency. Pin it instead of standing up the whole settings stack.
      gasModelProvider.overrideWith((ref) => GasModel.real),
    ],
  );

  /// Polls until [read] satisfies [done], or gives up. The tick is
  /// [DiveRepository.changeTickDebounce]-debounced (300ms), so the refresh is
  /// never immediate.
  Future<T> settle<T>(
    Future<T> Function() read,
    bool Function(T) done, {
    int attempts = 100,
  }) async {
    late T value;
    for (var i = 0; i < attempts; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      value = await read();
      if (done(value)) break;
    }
    return value;
  }

  test(
    'a statistics provider refreshes after a bulk delete that bypasses every '
    'notifier (issue #974)',
    () async {
      final repository = DiveRepository();
      for (final n in [1, 2, 3]) {
        await repository.createDive(
          createTestDiveWithBottomTime(id: 'd$n', diveNumber: n),
        );
      }

      final container = makeContainer();
      addTearDown(container.dispose);

      // Statistics page is open: an active listener builds the provider.
      final onScreen = container.listen(divesPerYearProvider, (_, _) {});
      addTearDown(onScreen.close);

      final initial = await container.read(divesPerYearProvider.future);
      expect(
        initial.map((e) => e.count).fold<int>(0, (a, b) => a + b),
        3,
        reason: 'three dives before the merge',
      );

      // The path dive_merge_service and dive_consolidation_service take. It
      // writes the dives table directly; nothing calls ref.invalidate.
      await repository.bulkDeleteDives(['d3']);

      final after = await settle(
        () => container.read(divesPerYearProvider.future),
        (rows) => rows.map((e) => e.count).fold<int>(0, (a, b) => a + b) == 2,
      );

      expect(
        after.map((e) => e.count).fold<int>(0, (a, b) => a + b),
        2,
        reason:
            'After a merge removes a dive, an open Statistics page must stop '
            'counting it. Before #974 the five-minute keepAlive served the '
            'stale count because statisticsVersionProvider was never bumped '
            'by the merge path.',
      );
    },
  );

  test('a statistics provider refreshes after a plain dive insert', () async {
    final repository = DiveRepository();
    await repository.createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );

    final container = makeContainer();
    addTearDown(container.dispose);

    final onScreen = container.listen(divesPerYearProvider, (_, _) {});
    addTearDown(onScreen.close);

    final initial = await container.read(divesPerYearProvider.future);
    expect(initial.map((e) => e.count).fold<int>(0, (a, b) => a + b), 1);

    // A dive-computer import or a sync pull writing straight to the DB.
    await repository.createDive(
      createTestDiveWithBottomTime(id: 'd2', diveNumber: 2),
    );

    final after = await settle(
      () => container.read(divesPerYearProvider.future),
      (rows) => rows.map((e) => e.count).fold<int>(0, (a, b) => a + b) == 2,
    );

    expect(
      after.map((e) => e.count).fold<int>(0, (a, b) => a + b),
      2,
      reason: 'an imported or synced dive must reach the statistics charts',
    );
  });
}
