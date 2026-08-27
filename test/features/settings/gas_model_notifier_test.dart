import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/test_database.dart';

/// Drives the real [SettingsNotifier] against a real database so the gas model
/// setter, its write-through to `diver_settings`, and the derived provider are
/// exercised end to end rather than only through the immutable value class
/// (issue #828).
void main() {
  group('gas model through SettingsNotifier', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() async {
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

      container.read(settingsProvider);
      await Future<void>.delayed(Duration.zero);
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test('a fresh diver loads the real gas default', () async {
      expect(container.read(settingsProvider).gasModel, GasModel.real);
    });

    test('setGasModel flips state and persists', () async {
      final notifier = container.read(settingsProvider.notifier);

      await notifier.setGasModel(GasModel.ideal);

      expect(container.read(settingsProvider).gasModel, GasModel.ideal);
      final stored = await DiverSettingsRepository().getSettingsForDiver('d1');
      expect(
        stored!.gasModel,
        GasModel.ideal,
        reason: 'the setter must write through to the database, not just state',
      );
    });

    test('setGasModel round-trips back to real', () async {
      final notifier = container.read(settingsProvider.notifier);

      await notifier.setGasModel(GasModel.ideal);
      await notifier.setGasModel(GasModel.real);

      expect(container.read(settingsProvider).gasModel, GasModel.real);
      final stored = await DiverSettingsRepository().getSettingsForDiver('d1');
      expect(stored!.gasModel, GasModel.real);
    });

    test('gasModelProvider follows the setting', () async {
      expect(container.read(gasModelProvider), GasModel.real);

      await container
          .read(settingsProvider.notifier)
          .setGasModel(GasModel.ideal);

      expect(
        container.read(gasModelProvider),
        GasModel.ideal,
        reason:
            'services take the model from this provider, so it has to '
            'track the setting for a change to reach them',
      );
    });

    test('setGasModel leaves the other unit settings alone', () async {
      final notifier = container.read(settingsProvider.notifier);
      final sacUnitBefore = container.read(settingsProvider).sacUnit;
      final volumeUnitBefore = container.read(settingsProvider).volumeUnit;

      await notifier.setGasModel(GasModel.ideal);

      final after = container.read(settingsProvider);
      expect(after.sacUnit, sacUnitBefore);
      expect(after.volumeUnit, volumeUnitBefore);
    });
  });
}
