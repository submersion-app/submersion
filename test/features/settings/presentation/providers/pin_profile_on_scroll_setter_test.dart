import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// The "Pin profile when scrolling" switch (issue #4423): on by default,
/// and a change reaches both the provider dive details reads and the
/// diver's stored settings.
void main() {
  late ProviderContainer container;
  late String diverId;

  setUp(() async {
    await setUpTestDatabase();
    final now = DateTime.now();
    final diver = await DiverRepository().createDiver(
      Diver(id: '', name: 'A', createdAt: now, updatedAt: now),
    );
    diverId = diver.id;
    SharedPreferences.setMockInitialValues({currentDiverIdKey: diverId});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  test('is on by default', () async {
    await container.read(settingsProvider.notifier).initialLoad;
    expect(container.read(pinProfileOnScrollProvider), isTrue);
  });

  test('turning it off updates the provider and persists', () async {
    final notifier = container.read(settingsProvider.notifier);
    await notifier.initialLoad;

    await notifier.setPinProfileOnScroll(false);

    expect(container.read(pinProfileOnScrollProvider), isFalse);
    final stored = await DiverSettingsRepository().getSettingsForDiver(diverId);
    expect(stored!.pinProfileOnScroll, isFalse);
  });
}
