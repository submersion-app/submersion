import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  test('the cold line accepts sub-zero water', () async {
    await container.read(settingsProvider.notifier).setColdWaterThresholdC(-1);
    expect(container.read(settingsProvider).coldWaterThresholdC, -1.0);
  });
}
