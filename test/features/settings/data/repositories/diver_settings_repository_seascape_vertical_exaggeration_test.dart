import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  group('AppSettings.seascapeVerticalExaggerationOverrides', () {
    test('defaults to empty, so every site starts fully automatic', () {
      const settings = AppSettings();
      expect(settings.seascapeVerticalExaggerationOverrides, isEmpty);
    });

    test('copyWith carries the map', () {
      const settings = AppSettings();
      final updated = settings.copyWith(
        seascapeVerticalExaggerationOverrides: const {'site-1': 3.5},
      );
      expect(updated.seascapeVerticalExaggerationOverrides, {'site-1': 3.5});
      // Unrelated settings survive.
      expect(updated.depthUnit, settings.depthUnit);
    });
  });

  group(
    'DiverSettingsRepository vertical exaggeration override persistence',
    () {
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

      test('new settings default to no overrides', () async {
        await repository.createSettingsForDiver('d1');
        final loaded = await repository.getSettingsForDiver('d1');
        expect(loaded!.seascapeVerticalExaggerationOverrides, isEmpty);
      });

      test('round-trips a map with several sites', () async {
        await repository.createSettingsForDiver('d1');
        await repository.updateSettingsForDiver(
          'd1',
          const AppSettings(
            seascapeVerticalExaggerationOverrides: {
              'site-1': 3.5,
              'site-2': 1.0,
            },
          ),
        );
        final loaded = await repository.getSettingsForDiver('d1');
        expect(loaded!.seascapeVerticalExaggerationOverrides, {
          'site-1': 3.5,
          'site-2': 1.0,
        });
      });

      test('clearing back to empty round-trips too', () async {
        await repository.createSettingsForDiver('d1');
        await repository.updateSettingsForDiver(
          'd1',
          const AppSettings(
            seascapeVerticalExaggerationOverrides: {'site-1': 3.5},
          ),
        );
        await repository.updateSettingsForDiver('d1', const AppSettings());
        final loaded = await repository.getSettingsForDiver('d1');
        expect(loaded!.seascapeVerticalExaggerationOverrides, isEmpty);
      });

      test('malformed stored JSON degrades to empty, never throws', () async {
        await repository.createSettingsForDiver('d1');
        await db.customStatement(
          "UPDATE diver_settings "
          "SET seascape_vertical_exaggeration_overrides = 'not json' "
          "WHERE diver_id = 'd1'",
        );
        final loaded = await repository.getSettingsForDiver('d1');
        expect(loaded!.seascapeVerticalExaggerationOverrides, isEmpty);
      });

      test('a non-numeric entry is dropped, the rest survive', () async {
        await repository.createSettingsForDiver('d1');
        await db.customStatement(
          "UPDATE diver_settings "
          "SET seascape_vertical_exaggeration_overrides = "
          "'{\"site-1\": 3.5, \"site-2\": \"nonsense\"}' "
          "WHERE diver_id = 'd1'",
        );
        final loaded = await repository.getSettingsForDiver('d1');
        expect(loaded!.seascapeVerticalExaggerationOverrides, {'site-1': 3.5});
      });
    },
  );
}
