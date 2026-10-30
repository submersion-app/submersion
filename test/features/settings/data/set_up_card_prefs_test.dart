import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/settings/data/set_up_card_prefs.dart';
import 'package:submersion/features/settings/presentation/providers/set_up_card_prefs_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/test_database.dart';

void main() {
  late SharedPreferences prefs;

  Future<void> withPrefs(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    prefs = await SharedPreferences.getInstance();
  }

  Future<int> Function() divers(int count) =>
      () async => count;

  group('seedOnce', () {
    test('a device that already holds a diver starts hidden, photos '
        'settled', () async {
      await withPrefs({});
      await SetUpCardPrefs(prefs).seedOnce(diverCount: divers(2));

      expect(prefs.getBool(SetUpCardPrefs.hiddenKey), isTrue);
      expect(prefs.getBool(SetUpCardPrefs.photosSkippedKey), isTrue);
      expect(prefs.getBool(SetUpCardPrefs.seedDoneKey), isTrue);
    });

    test('a fresh install is never seeded, even once divers appear', () async {
      await withPrefs({});
      final card = SetUpCardPrefs(prefs);
      await card.seedOnce(diverCount: divers(0));

      expect(prefs.containsKey(SetUpCardPrefs.hiddenKey), isFalse);
      expect(prefs.containsKey(SetUpCardPrefs.photosSkippedKey), isFalse);
      expect(prefs.getBool(SetUpCardPrefs.seedDoneKey), isTrue);

      // The wizard creates the first diver; the next launch seeds nothing.
      await card.seedOnce(diverCount: divers(1));
      expect(card.hidden, isFalse);
      expect(card.photosSkipped, isFalse);
    });

    test('a seed already done counts no divers', () async {
      await withPrefs({SetUpCardPrefs.seedDoneKey: true});
      var counted = false;
      await SetUpCardPrefs(prefs).seedOnce(
        diverCount: () async {
          counted = true;
          return 1;
        },
      );
      expect(counted, isFalse);
    });

    test('a choice already made is kept and ends the seed', () async {
      await withPrefs({SetUpCardPrefs.hiddenKey: false});
      final card = SetUpCardPrefs(prefs);
      await card.seedOnce(diverCount: divers(3));

      expect(card.hidden, isFalse);
      expect(prefs.containsKey(SetUpCardPrefs.photosSkippedKey), isFalse);
      expect(prefs.getBool(SetUpCardPrefs.seedDoneKey), isTrue);
    });

    test('a skipped photo step alone also counts as a choice', () async {
      await withPrefs({SetUpCardPrefs.photosSkippedKey: true});
      final card = SetUpCardPrefs(prefs);
      await card.seedOnce(diverCount: divers(3));

      expect(prefs.containsKey(SetUpCardPrefs.hiddenKey), isFalse);
      expect(card.photosSkipped, isTrue);
    });
  });

  // Issue #3482 review: the seed runs at startup, before the app mounts, so
  // the card's first build already reads the seeded values.
  group('runSetUpCardSeed', () {
    setUp(() async => setUpTestDatabase());
    tearDown(() => tearDownTestDatabase());

    test('counts the divers in the database', () async {
      await withPrefs({});
      await DiverRepository().createDiver(
        Diver(
          id: 'diver-1',
          name: 'Diver',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      );

      await runSetUpCardSeed(prefs);

      expect(prefs.getBool(SetUpCardPrefs.hiddenKey), isTrue);
    });

    test(
      'a failure never blocks startup, and the next launch retries',
      () async {
        await withPrefs({});

        await runSetUpCardSeed(
          prefs,
          diverCount: () async => throw StateError('database'),
        );

        expect(prefs.containsKey(SetUpCardPrefs.seedDoneKey), isFalse);
      },
    );
  });

  group('setUpCardPrefsNotifierProvider', () {
    test('reads the stored state and rebuilds on each write', () async {
      await withPrefs({SetUpCardPrefs.photosSkippedKey: true});
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(setUpCardPrefsNotifierProvider), (
        hidden: false,
        photosSkipped: true,
      ));

      await container
          .read(setUpCardPrefsNotifierProvider.notifier)
          .setHidden(true);
      expect(container.read(setUpCardPrefsNotifierProvider).hidden, isTrue);
      expect(prefs.getBool(SetUpCardPrefs.hiddenKey), isTrue);

      await container
          .read(setUpCardPrefsNotifierProvider.notifier)
          .setPhotosSkipped(false);
      expect(
        container.read(setUpCardPrefsNotifierProvider).photosSkipped,
        isFalse,
      );
    });

    test('a seed run before the first read is what it reads', () async {
      await withPrefs({});
      await SetUpCardPrefs(prefs).seedOnce(diverCount: divers(1));
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(setUpCardPrefsNotifierProvider), (
        hidden: true,
        photosSkipped: true,
      ));
    });
  });
}
