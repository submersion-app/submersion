import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/database/read_only_query_interceptor.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// A desktop pop-out window reads the main window's settings and must write
/// nothing (#5078): no adopted device values, no created row, no cached theme,
/// no prefs, no saves.
void main() {
  late AppDatabase writer;
  late AppDatabase readOnly;
  late String diverId;
  late SharedPreferences prefs;
  late Map<String, Object?> prefsBefore;
  late ProviderContainer container;

  Map<String, Object?> snapshot(SharedPreferences p) => {
    for (final key in p.getKeys()) key: p.get(key),
  };

  setUp(() async {
    writer = await setUpTestDatabase();
    final now = DateTime.now();
    final diver = await DiverRepository().createDiver(
      Diver(id: '', name: 'A', createdAt: now, updatedAt: now),
    );
    diverId = diver.id;
    final repo = DiverSettingsRepository();
    final created = await repo.getOrCreateSettingsForDiver(diverId);
    await repo.updateSettingsForDiver(
      diverId,
      created.copyWith(depthUnit: DepthUnit.feet),
      previous: created,
    );

    // From here every repository reads through a connection that refuses
    // writes: an attempted write fails the load and so fails the test.
    readOnly = AppDatabase(
      DatabaseConnection(
        writer.executor,
      ).interceptWith(ReadOnlyQueryInterceptor()),
    );
    DatabaseService.instance.setTestDatabase(readOnly);

    SharedPreferences.setMockInitialValues({
      currentDiverIdKey: diverId,
      // A value the full load would adopt into the row (#2948).
      SettingsKeys.pscrRatio: 50.0,
    });
    prefs = await SharedPreferences.getInstance();
    prefsBefore = snapshot(prefs);
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        currentDiverIdProvider.overrideWith(
          (ref) => CurrentDiverIdNotifier.readOnly(
            ref.watch(sharedPreferencesProvider),
            ref.watch(diverRepositoryProvider),
          ),
        ),
        settingsProvider.overrideWith(
          (ref) => SettingsNotifier.readOnly(
            ref.watch(diverSettingsRepositoryProvider),
            ref,
          ),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    DatabaseService.instance.setTestDatabase(writer);
    await tearDownTestDatabase();
  });

  test('read-only load reflects the stored row and writes nothing', () async {
    final notifier = container.read(settingsProvider.notifier);
    await notifier.initialLoad;

    expect(container.read(settingsProvider).depthUnit, DepthUnit.feet);
    expect(snapshot(prefs), prefsBefore);
  });

  test('read-only setters change state but never save', () async {
    final notifier = container.read(settingsProvider.notifier);
    await notifier.initialLoad;

    await notifier.setDepthUnit(DepthUnit.meters);

    expect(container.read(settingsProvider).depthUnit, DepthUnit.meters);
    final stored = await DiverSettingsRepository().getSettingsForDiver(diverId);
    expect(stored!.depthUnit, DepthUnit.feet);
    expect(snapshot(prefs), prefsBefore);
  });

  test(
    'a stale diver id falls back to the default diver, reading only',
    () async {
      // The diver was deleted: the load falls back to the default diver.
      await prefs.setString(currentDiverIdKey, 'deleted-diver');
      prefsBefore = snapshot(prefs);
      final fresh = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentDiverIdProvider.overrideWith(
            (ref) => CurrentDiverIdNotifier.readOnly(
              ref.watch(sharedPreferencesProvider),
              ref.watch(diverRepositoryProvider),
            ),
          ),
          settingsProvider.overrideWith(
            (ref) => SettingsNotifier.readOnly(
              ref.watch(diverSettingsRepositoryProvider),
              ref,
            ),
          ),
        ],
      );
      addTearDown(fresh.dispose);

      await fresh.read(settingsProvider.notifier).initialLoad;

      expect(fresh.read(settingsProvider).depthUnit, DepthUnit.feet);
      expect(snapshot(prefs), prefsBefore);
    },
  );

  test(
    'read-only diver notifier serves the stored id and writes nothing',
    () async {
      expect(container.read(currentDiverIdProvider), diverId);
      // Give a full notifier's validation and sync time to have run.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(container.read(currentDiverIdProvider), diverId);
      expect(snapshot(prefs), prefsBefore);
    },
  );

  test('reload keeps the settings until the fresh load lands', () async {
    final notifier = container.read(settingsProvider.notifier);
    await notifier.initialLoad;
    expect(container.read(settingsProvider).depthUnit, DepthUnit.feet);

    final reloading = notifier.reload();
    // Not the defaults in between: a pop-out would flash them.
    expect(container.read(settingsProvider).depthUnit, DepthUnit.feet);
    await reloading;
    expect(container.read(settingsProvider).depthUnit, DepthUnit.feet);
    expect(snapshot(prefs), prefsBefore);
  });
}
