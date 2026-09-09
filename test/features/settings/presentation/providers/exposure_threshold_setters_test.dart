import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// The exposure threshold setters reject values no dive can satisfy.
void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    await container.read(settingsProvider.notifier).initialLoad;
  });
  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  test('a negative deep line clamps to zero', () async {
    await container.read(settingsProvider.notifier).setDeepDiveThresholdM(-5);
    expect(container.read(settingsProvider).deepDiveThresholdM, 0.0);
    await container.read(settingsProvider.notifier).setDeepDiveThresholdM(18);
    expect(container.read(settingsProvider).deepDiveThresholdM, 18.0);
  });

  test('the O2 line stays within 0 to 100 percent', () async {
    final notifier = container.read(settingsProvider.notifier);
    await notifier.setHighO2ThresholdPercent(150);
    expect(container.read(settingsProvider).highO2ThresholdPercent, 100.0);
    await notifier.setHighO2ThresholdPercent(-10);
    expect(container.read(settingsProvider).highO2ThresholdPercent, 0.0);
    await notifier.setHighO2ThresholdPercent(32);
    expect(container.read(settingsProvider).highO2ThresholdPercent, 32.0);
  });

  test('a failed write rolls the in-memory value back', () async {
    // A selected diver routes the save through diver_settings; dropping that
    // table is the one seam that makes the write throw.
    container.dispose();
    final now = DateTime.now();
    final diver = await DiverRepository().createDiver(
      Diver(id: '', name: 'A', createdAt: now, updatedAt: now),
    );
    SharedPreferences.setMockInitialValues({currentDiverIdKey: diver.id});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    final notifier = container.read(settingsProvider.notifier);
    await notifier.initialLoad;
    await notifier.setDeepDiveThresholdM(25);
    expect(container.read(settingsProvider).deepDiveThresholdM, 25.0);

    await DatabaseService.instance.database.customStatement(
      'DROP TABLE diver_settings',
    );
    await expectLater(notifier.setDeepDiveThresholdM(40), throwsA(anything));
    expect(container.read(settingsProvider).deepDiveThresholdM, 25.0);
  });

  test('the cold line accepts sub-zero water', () async {
    await container.read(settingsProvider.notifier).setColdWaterThresholdC(-1);
    expect(container.read(settingsProvider).coldWaterThresholdC, -1.0);
  });
}
