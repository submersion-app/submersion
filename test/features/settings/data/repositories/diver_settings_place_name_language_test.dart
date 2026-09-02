import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  group('AppSettings.placeNameLanguage', () {
    test('defaults to English so existing logbooks keep grouping', () {
      const settings = AppSettings();
      expect(settings.placeNameLanguage, 'en');
    });

    test('copyWith carries the language', () {
      const settings = AppSettings();
      final updated = settings.copyWith(placeNameLanguage: 'de');
      expect(updated.placeNameLanguage, 'de');
      expect(updated.depthUnit, settings.depthUnit);
    });
  });

  group('DiverSettingsRepository place name language persistence', () {
    late AppDatabase db;
    late DiverSettingsRepository repository;

    setUp(() async {
      db = await setUpTestDatabase();
      repository = DiverSettingsRepository();
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
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test('new settings default to English', () async {
      await repository.createSettingsForDiver('d1');
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.placeNameLanguage, 'en');
    });

    test('round-trips a supported code', () async {
      await repository.createSettingsForDiver('d1');
      await repository.updateSettingsForDiver(
        'd1',
        const AppSettings(placeNameLanguage: 'de'),
      );
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.placeNameLanguage, 'de');
    });

    test('an unknown stored code loads as English', () async {
      await repository.createSettingsForDiver('d1');
      await db.customStatement(
        "UPDATE diver_settings SET place_name_language = 'xx' "
        "WHERE diver_id = 'd1'",
      );
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.placeNameLanguage, 'en');
    });
  });
}
