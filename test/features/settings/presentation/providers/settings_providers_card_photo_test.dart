import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// The dive card photo settings (v347) on the real notifier: the switch,
/// the two overlay opacities and the providers the cards watch.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    db = await setUpTestDatabase();
    final ms = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'me',
            name: 'me',
            createdAt: ms,
            updatedAt: ms,
          ),
        );
    await prefs.setString(currentDiverIdKey, 'me');
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    await container.read(settingsProvider.notifier).initialLoad;
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  SettingsNotifier notifier() => container.read(settingsProvider.notifier);

  Future<Map<String, Object?>> storedRow() async {
    final row = await db
        .customSelect(
          'SELECT show_photo_background_on_dive_cards, '
          'card_photo_overlay_dark, card_photo_overlay_light '
          "FROM diver_settings WHERE diver_id = 'me'",
        )
        .getSingle();
    return row.data;
  }

  test('the photo background is off and both overlays are at 60%', () {
    expect(container.read(showPhotoBackgroundOnDiveCardsProvider), isFalse);
    final overlay = container.read(cardPhotoOverlayProvider);
    expect(overlay.dark, 0.6);
    expect(overlay.light, 0.6);
  });

  test(
    'turning the photo background on reaches the cards and is saved',
    () async {
      await notifier().setShowPhotoBackgroundOnDiveCards(true);

      expect(container.read(showPhotoBackgroundOnDiveCardsProvider), isTrue);
      expect((await storedRow())['show_photo_background_on_dive_cards'], 1);

      await notifier().setShowPhotoBackgroundOnDiveCards(false);
      expect(container.read(showPhotoBackgroundOnDiveCardsProvider), isFalse);
    },
  );

  test('each theme keeps its own overlay, and both are saved', () async {
    await notifier().setCardPhotoOverlayDark(0.8);
    await notifier().setCardPhotoOverlayLight(0.35);

    final overlay = container.read(cardPhotoOverlayProvider);
    expect(overlay.dark, 0.8);
    expect(overlay.light, 0.35);
    final row = await storedRow();
    expect(row['card_photo_overlay_dark'], 0.8);
    expect(row['card_photo_overlay_light'], 0.35);
  });

  test('an overlay above 1 is held at 1', () async {
    await notifier().setCardPhotoOverlayDark(1.5);
    await notifier().setCardPhotoOverlayLight(1.2);

    expect(container.read(cardPhotoOverlayProvider).dark, 1.0);
    expect(container.read(cardPhotoOverlayProvider).light, 1.0);
  });

  test('an overlay below 0 is held at 0', () async {
    await notifier().setCardPhotoOverlayDark(-0.5);
    await notifier().setCardPhotoOverlayLight(-0.1);

    expect(container.read(cardPhotoOverlayProvider).dark, 0.0);
    expect(container.read(cardPhotoOverlayProvider).light, 0.0);
  });
}
