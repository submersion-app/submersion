import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/features/settings/data/set_up_card_prefs.dart';
import 'package:submersion/features/settings/presentation/providers/set_up_card_prefs_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  late SharedPreferences prefs;

  Future<void> withPrefs(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    prefs = await SharedPreferences.getInstance();
  }

  group('seedOnce', () {
    test('a device that already holds a diver starts hidden, photos '
        'settled', () async {
      await withPrefs({});
      await SetUpCardPrefs(prefs).seedOnce(diverCount: 2);

      expect(prefs.getBool(SetUpCardPrefs.hiddenKey), isTrue);
      expect(prefs.getBool(SetUpCardPrefs.photosSkippedKey), isTrue);
      expect(prefs.getBool(SetUpCardPrefs.seedDoneKey), isTrue);
    });

    test('a fresh install is never seeded, even once divers appear', () async {
      await withPrefs({});
      final card = SetUpCardPrefs(prefs);
      await card.seedOnce(diverCount: 0);

      expect(prefs.containsKey(SetUpCardPrefs.hiddenKey), isFalse);
      expect(prefs.containsKey(SetUpCardPrefs.photosSkippedKey), isFalse);
      expect(prefs.getBool(SetUpCardPrefs.seedDoneKey), isTrue);

      // The wizard creates the first diver; the next launch seeds nothing.
      await card.seedOnce(diverCount: 1);
      expect(card.hidden, isFalse);
      expect(card.photosSkipped, isFalse);
    });

    test('a choice already made is kept and ends the seed', () async {
      await withPrefs({SetUpCardPrefs.hiddenKey: false});
      final card = SetUpCardPrefs(prefs);
      await card.seedOnce(diverCount: 3);

      expect(card.hidden, isFalse);
      expect(prefs.containsKey(SetUpCardPrefs.photosSkippedKey), isFalse);
      expect(prefs.getBool(SetUpCardPrefs.seedDoneKey), isTrue);
    });

    test('a skipped photo step alone also counts as a choice', () async {
      await withPrefs({SetUpCardPrefs.photosSkippedKey: true});
      final card = SetUpCardPrefs(prefs);
      await card.seedOnce(diverCount: 3);

      expect(prefs.containsKey(SetUpCardPrefs.hiddenKey), isFalse);
      expect(card.photosSkipped, isTrue);
    });
  });

  group('setUpCardPrefsProvider', () {
    test('reads the stored state and rebuilds on each write', () async {
      await withPrefs({SetUpCardPrefs.photosSkippedKey: true});
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(setUpCardPrefsProvider), (
        hidden: false,
        photosSkipped: true,
      ));

      await container.read(setUpCardPrefsProvider.notifier).setHidden(true);
      expect(container.read(setUpCardPrefsProvider).hidden, isTrue);
      expect(prefs.getBool(SetUpCardPrefs.hiddenKey), isTrue);

      await container
          .read(setUpCardPrefsProvider.notifier)
          .setPhotosSkipped(false);
      expect(container.read(setUpCardPrefsProvider).photosSkipped, isFalse);
    });

    test('the seed reaches the provider state', () async {
      await withPrefs({});
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(setUpCardPrefsProvider).hidden, isFalse);
      await container
          .read(setUpCardPrefsProvider.notifier)
          .seedOnce(diverCount: 1);
      expect(container.read(setUpCardPrefsProvider), (
        hidden: true,
        photosSkipped: true,
      ));
    });
  });
}
