// A failing settings load must not escape to the zone.
//
// SettingsNotifier starts its load in the constructor and nothing listens to
// the resulting future. In Dart a future with no listener delivers its error to
// the zone handler, and package:test attributes a zone error to whichever test
// happens to be running at that moment. So a settings load that fails after its
// own test has finished fails a LATER, unrelated test with "This test failed
// after it had already completed", and which test that is depends on timing.
//
// That is the mechanism behind the intermittent CI failures on shard runs: a
// test sets up a database, touches any settings-derived provider, and finishes
// while the load is still in flight. Teardown closes the database, the pending
// Drift query fails, and the error lands on a stranger.
//
// Reproduced from a real CI failure of
// test/features/weight_planner/presentation/providers/
// plan_buoyancy_twin_provider_test.dart, which reads divePlanNotifierProvider
// and so pulls in settingsProvider through the gradient factor providers.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Stands in for the database going away underneath an in-flight read, which
/// is what a test teardown does to a load started by a provider.
class _FailingDiverRepository extends DiverRepository {
  @override
  Future<List<Diver>> getAllDivers() async =>
      throw StateError('database closed');

  @override
  Future<Diver?> getDefaultDiver() async => throw StateError('database closed');

  @override
  Future<Diver?> getDiverById(String id) async =>
      throw StateError('database closed');
}

class _UnusedSettingsRepository extends DiverSettingsRepository {}

class _NullDiverIdNotifier extends StateNotifier<String?>
    implements CurrentDiverIdNotifier {
  _NullDiverIdNotifier() : super(null);

  @override
  Future<void> setCurrentDiver(String id) async => state = id;

  @override
  Future<void> clearCurrentDiver() async => state = null;
}

Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      diverSettingsRepositoryProvider.overrideWithValue(
        _UnusedSettingsRepository(),
      ),
      diverRepositoryProvider.overrideWithValue(_FailingDiverRepository()),
      currentDiverIdProvider.overrideWith((ref) => _NullDiverIdNotifier()),
    ],
  );
}

/// Several event-loop turns, enough for the constructor's load to run through
/// its awaits and fail.
Future<void> _settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('a failing load does not escape to the zone', () async {
    final container = await _container();
    addTearDown(container.dispose);

    // Deliberately NOT awaiting initialLoad: awaiting it would add a listener
    // and mask the very bug under test. This is what production does, and what
    // every test that merely touches a settings-derived provider does.
    container.read(settingsProvider.notifier);
    await _settle();

    // Reaching here without the runner reporting an uncaught error is the
    // assertion. The settings themselves stay at the defaults.
    expect(container.read(settingsProvider), const AppSettings());
  });

  test(
    'a failing reload after a diver change does not escape either',
    () async {
      final container = await _container();
      addTearDown(container.dispose);

      container.read(settingsProvider.notifier);
      await _settle();

      // The diver-change listener calls the same load fire-and-forget, without
      // even storing the future, so it is the second escape route.
      await container
          .read(currentDiverIdProvider.notifier)
          .setCurrentDiver('d1');
      await _settle();

      expect(container.read(settingsProvider), const AppSettings());
    },
  );

  test('awaiting initialLoad still surfaces the failure', () async {
    // The contract documented on initialLoad is preserved: callers that await
    // it still see the error and fall back to the defaults themselves. Only
    // the unlistened path changes.
    final container = await _container();
    addTearDown(container.dispose);

    await expectLater(
      container.read(settingsProvider.notifier).initialLoad,
      throwsA(isA<StateError>()),
    );
  });
}
