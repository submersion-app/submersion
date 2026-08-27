import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_appearance.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/test_database.dart';

/// Drives the real [SettingsNotifier] end to end. Since v151 the seascape
/// appearance is PER-DIVER (diver_settings column, synced); the legacy
/// device-local pref is adopted once into a row that never held a value,
/// then retired.
void main() {
  late AppDatabase db;

  Future<ProviderContainer> containerWith(
    Map<String, Object> prefsSeed, {
    bool withDiver = true,
    Future<void> Function(AppDatabase db)? prepareDb,
  }) async {
    SharedPreferences.setMockInitialValues({
      if (withDiver) currentDiverIdKey: 'd1',
      ...prefsSeed,
    });
    final prefs = await SharedPreferences.getInstance();
    db = await setUpTestDatabase();
    if (withDiver) {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: 'd1',
              name: 'Test Diver',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await DiverSettingsRepository().createSettingsForDiver('d1');
    }
    // Runs BEFORE the notifier's initial load, so tests can shape the row
    // (e.g. simulate a pre-v151 column) that the load will encounter.
    await prepareDb?.call(db);
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    container.read(settingsProvider);
    await Future<void>.delayed(Duration.zero);
    return container;
  }

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  test('a pre-v151 row adopts the legacy pref once, then retires it', () async {
    const legacy = SeascapeAppearance(rampBanded: true, wallAngleDeg: 30.0);
    final container = await containerWith(
      {SettingsKeys.seascapeAppearance: legacy.encode()},
      // Simulate a row created before v151: the column never held a value.
      prepareDb: (db) => db.customStatement(
        'UPDATE diver_settings SET seascape_appearance = NULL',
      ),
    );

    expect(container.read(settingsProvider).seascapeAppearance, legacy);
    // Adoption wrote through to the diver row so it syncs.
    final stored = await DiverSettingsRepository().getSettingsForDiver('d1');
    expect(stored!.seascapeAppearance, legacy);
    // The pref is retired so a later reset elsewhere cannot be resurrected.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(SettingsKeys.seascapeAppearance), isNull);
  });

  test('a row that has held a value wins over a stale pref', () async {
    const dbValue = SeascapeAppearance(wallAngleDeg: 45.0);
    const stalePref = SeascapeAppearance(rampBanded: true);
    final container = await containerWith(
      {SettingsKeys.seascapeAppearance: stalePref.encode()},
      prepareDb: (db) => DiverSettingsRepository().updateSettingsForDiver(
        'd1',
        const AppSettings(seascapeAppearance: dbValue),
      ),
    );

    expect(container.read(settingsProvider).seascapeAppearance, dbValue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(SettingsKeys.seascapeAppearance), isNull);
  });

  test('setSeascapeAppearance persists to the diver row, not prefs', () async {
    final container = await containerWith({});
    const next = SeascapeAppearance(
      rampMaxDepthMeters: 40.0,
      contourMode: SeascapeContourMode.custom,
      customLevels: [SeascapeContourLevel(depthMeters: 10.0)],
    );
    await container.read(settingsProvider.notifier).setSeascapeAppearance(next);

    expect(container.read(settingsProvider).seascapeAppearance, next);
    final stored = await DiverSettingsRepository().getSettingsForDiver('d1');
    expect(stored!.seascapeAppearance, next);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(SettingsKeys.seascapeAppearance), isNull);
  });

  test('with no diver the pref remains the fallback store', () async {
    const stored = SeascapeAppearance(rampBanded: true);
    final container = await containerWith({
      SettingsKeys.seascapeAppearance: stored.encode(),
    }, withDiver: false);
    expect(container.read(settingsProvider).seascapeAppearance, stored);

    const next = SeascapeAppearance(wallAngleDeg: 60.0);
    await container.read(settingsProvider.notifier).setSeascapeAppearance(next);
    final prefs = await SharedPreferences.getInstance();
    expect(
      SeascapeAppearance.decode(
        prefs.getString(SettingsKeys.seascapeAppearance),
      ),
      next,
    );
  });
}
