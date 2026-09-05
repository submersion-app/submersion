import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/test_database.dart';

void main() {
  group('default planner water type through SettingsNotifier', () {
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

    test('a fresh diver loads salt as the planner water default', () async {
      expect(
        container.read(settingsProvider).defaultPlannerWaterType,
        PlannerWaterType.salt,
      );
    });

    test('setDefaultPlannerWaterType persists', () async {
      final notifier = container.read(settingsProvider.notifier);

      await notifier.setDefaultPlannerWaterType(PlannerWaterType.fresh);

      expect(
        container.read(settingsProvider).defaultPlannerWaterType,
        PlannerWaterType.fresh,
      );
      final stored = await DiverSettingsRepository().getSettingsForDiver('d1');
      expect(stored!.defaultPlannerWaterType, PlannerWaterType.fresh);
    });
  });
}
