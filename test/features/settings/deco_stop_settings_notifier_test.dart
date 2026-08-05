import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/test_database.dart';

/// Drives the real [SettingsNotifier] against a real database so the deco stop
/// setters and the derived provider are exercised end to end, not just the
/// immutable [AppSettings] value class.
void main() {
  group('deco stop settings through SettingsNotifier', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() async {
      // Seeding the pref lets the real CurrentDiverIdNotifier resolve 'd1',
      // so no stub is needed and the production load path is exercised.
      SharedPreferences.setMockInitialValues({currentDiverIdKey: 'd1'});
      final prefs = await SharedPreferences.getInstance();
      db = await setUpTestDatabase();

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

      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      // Let the notifier finish its async load before each test drives it.
      container.read(settingsProvider);
      await Future<void>.delayed(Duration.zero);
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test('setShowDecoStopsOnProfile flips state and persists', () async {
      final notifier = container.read(settingsProvider.notifier);
      expect(container.read(settingsProvider).showDecoStopsOnProfile, isTrue);

      await notifier.setShowDecoStopsOnProfile(false);

      expect(container.read(settingsProvider).showDecoStopsOnProfile, isFalse);
      final stored = await DiverSettingsRepository().getSettingsForDiver('d1');
      expect(
        stored!.showDecoStopsOnProfile,
        isFalse,
        reason: 'the setter must write through to the database, not just state',
      );
    });

    test('setDefaultDecoStopSource flips state and persists', () async {
      final notifier = container.read(settingsProvider.notifier);
      expect(
        container.read(settingsProvider).defaultDecoStopSource,
        MetricDataSource.calculated,
      );

      await notifier.setDefaultDecoStopSource(MetricDataSource.computer);

      expect(
        container.read(settingsProvider).defaultDecoStopSource,
        MetricDataSource.computer,
      );
      final stored = await DiverSettingsRepository().getSettingsForDiver('d1');
      expect(stored!.defaultDecoStopSource, MetricDataSource.computer);
    });

    test('the deco stop setters leave the ceiling settings alone', () async {
      final notifier = container.read(settingsProvider.notifier);
      final ceilingVisibleBefore = container
          .read(settingsProvider)
          .showCeilingOnProfile;
      final ceilingSourceBefore = container
          .read(settingsProvider)
          .defaultCeilingSource;

      await notifier.setShowDecoStopsOnProfile(false);
      await notifier.setDefaultDecoStopSource(MetricDataSource.computer);

      final after = container.read(settingsProvider);
      expect(after.showCeilingOnProfile, ceilingVisibleBefore);
      expect(after.defaultCeilingSource, ceilingSourceBefore);
    });

    test('showDecoStopsOnProfileProvider tracks the setting', () async {
      expect(container.read(showDecoStopsOnProfileProvider), isTrue);

      await container
          .read(settingsProvider.notifier)
          .setShowDecoStopsOnProfile(false);

      expect(container.read(showDecoStopsOnProfileProvider), isFalse);
    });
  });
}
