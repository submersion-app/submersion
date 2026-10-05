import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/test_database.dart';

/// Since v261 the pSCR ratio and "metrics follow viewport" are per-diver
/// (synced, issue #2948). A row that has never held one adopts this
/// device's old pref; the pref is kept so every diver can adopt it.
void main() {
  late AppDatabase db;

  Future<void> insertDiver(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: id,
            name: 'Diver $id',
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<ProviderContainer> containerWith(
    Map<String, Object> prefsSeed, {
    String? diverId = 'd1',
    bool createRow = true,
    Future<void> Function(AppDatabase db)? prepareDb,
  }) async {
    SharedPreferences.setMockInitialValues({
      currentDiverIdKey: ?diverId,
      ...prefsSeed,
    });
    final prefs = await SharedPreferences.getInstance();
    db = await setUpTestDatabase();
    if (diverId != null) {
      await insertDiver(diverId);
      if (createRow) {
        await DiverSettingsRepository().createSettingsForDiver(diverId);
      }
    }
    await prepareDb?.call(db);
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    await container.read(settingsProvider.notifier).settingsLoaded;
    return container;
  }

  Future<DiverSetting> row(String diverId) => (db.select(
    db.diverSettings,
  )..where((t) => t.diverId.equals(diverId))).getSingle();

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  test('an unset row adopts both prefs and writes them through', () async {
    final container = await containerWith({
      SettingsKeys.pscrRatio: 40.0,
      SettingsKeys.profileMetricsFollowViewport: true,
    });

    expect(container.read(settingsProvider).pscrRatio, 40.0);
    expect(container.read(settingsProvider).profileMetricsFollowViewport, true);
    expect((await row('d1')).pscrRatio, 40.0);
    expect((await row('d1')).profileMetricsFollowViewport, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble(SettingsKeys.pscrRatio), 40.0);
  });

  test('a pref equal to the default is still written', () async {
    await containerWith({
      SettingsKeys.pscrRatio: 100.0,
      SettingsKeys.profileMetricsFollowViewport: false,
    });

    expect((await row('d1')).pscrRatio, 100.0);
    expect((await row('d1')).profileMetricsFollowViewport, isFalse);
  });

  test('no pref leaves the columns unset and reads the defaults', () async {
    final container = await containerWith({});

    expect(container.read(settingsProvider).pscrRatio, 100.0);
    expect(
      container.read(settingsProvider).profileMetricsFollowViewport,
      isFalse,
    );
    expect((await row('d1')).pscrRatio, isNull);
    expect((await row('d1')).profileMetricsFollowViewport, isNull);
  });

  test('a row that holds a value wins over a stale pref', () async {
    final container = await containerWith(
      {
        SettingsKeys.pscrRatio: 40.0,
        SettingsKeys.profileMetricsFollowViewport: false,
      },
      prepareDb: (db) => db.customStatement(
        'UPDATE diver_settings SET pscr_ratio = 15.0, '
        'profile_metrics_follow_viewport = 1',
      ),
    );

    expect(container.read(settingsProvider).pscrRatio, 15.0);
    expect(container.read(settingsProvider).profileMetricsFollowViewport, true);
    expect((await row('d1')).pscrRatio, 15.0);
    expect((await row('d1')).profileMetricsFollowViewport, isTrue);
  });

  test('a new diver with no row yet adopts the pref', () async {
    await containerWith({SettingsKeys.pscrRatio: 40.0}, createRow: false);

    expect((await row('d1')).pscrRatio, 40.0);
  });

  test('a second diver on the device adopts the same pref', () async {
    final container = await containerWith(
      {SettingsKeys.pscrRatio: 40.0},
      prepareDb: (db) async {
        await insertDiver('d2');
        await DiverSettingsRepository().createSettingsForDiver('d2');
      },
    );

    await container.read(currentDiverIdProvider.notifier).setCurrentDiver('d2');
    await container.read(settingsProvider.notifier).settingsLoaded;

    expect(container.read(settingsProvider).pscrRatio, 40.0);
    expect((await row('d2')).pscrRatio, 40.0);
  });

  test('with a diver the setters write the row, not the prefs', () async {
    final container = await containerWith({});

    await container.read(settingsProvider.notifier).setPscrRatio(25.0);
    await container
        .read(settingsProvider.notifier)
        .setProfileMetricsFollowViewport(true);

    expect((await row('d1')).pscrRatio, 25.0);
    expect((await row('d1')).profileMetricsFollowViewport, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble(SettingsKeys.pscrRatio), isNull);
    expect(prefs.getBool(SettingsKeys.profileMetricsFollowViewport), isNull);
  });

  test('with no diver the prefs remain the store', () async {
    final container = await containerWith({
      SettingsKeys.pscrRatio: 40.0,
    }, diverId: null);

    expect(container.read(settingsProvider).pscrRatio, 40.0);
    await container.read(settingsProvider.notifier).setPscrRatio(25.0);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble(SettingsKeys.pscrRatio), 25.0);
  });
}
