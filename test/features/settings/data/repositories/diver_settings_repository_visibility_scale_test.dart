import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/domain/visibility/visibility_scale.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  group('AppSettings.visibilityScale derivation', () {
    test('defaults to tropical so no logbook re-labels on upgrade', () {
      const settings = AppSettings();
      expect(settings.visibilityScalePreset, VisibilityScalePreset.tropical);
      expect(settings.visibilityScale, VisibilityScale.tropical);
    });

    test('derives the named preset scales', () {
      expect(
        const AppSettings(
          visibilityScalePreset: VisibilityScalePreset.coldWater,
        ).visibilityScale,
        VisibilityScale.coldWater,
      );
      expect(
        const AppSettings(
          visibilityScalePreset: VisibilityScalePreset.temperate,
        ).visibilityScale,
        VisibilityScale.temperate,
      );
    });

    test('derives a custom scale from the stored thresholds', () {
      const settings = AppSettings(
        visibilityScalePreset: VisibilityScalePreset.custom,
        visibilityScaleExcellentM: 18,
        visibilityScaleGoodM: 9,
        visibilityScaleModerateM: 3,
      );
      expect(settings.visibilityScale.bandFor(9), VisibilityBand.good);
      expect(settings.visibilityScale.bandFor(18), VisibilityBand.excellent);
    });

    test('custom with missing thresholds degrades to tropical', () {
      const settings = AppSettings(
        visibilityScalePreset: VisibilityScalePreset.custom,
      );
      expect(settings.visibilityScale, VisibilityScale.tropical);
    });
  });

  group('DiverSettingsRepository visibility scale persistence', () {
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

    test('new settings default to the tropical preset', () async {
      await repository.createSettingsForDiver('d1');
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded, isNotNull);
      expect(loaded!.visibilityScalePreset, VisibilityScalePreset.tropical);
      expect(loaded.visibilityScale, VisibilityScale.tropical);
    });

    test('round-trips the cold-water preset', () async {
      await repository.createSettingsForDiver('d1');
      await repository.updateSettingsForDiver(
        'd1',
        const AppSettings(
          visibilityScalePreset: VisibilityScalePreset.coldWater,
        ),
      );
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.visibilityScalePreset, VisibilityScalePreset.coldWater);
      expect(loaded.visibilityScale, VisibilityScale.coldWater);
      // The calibration is what makes a 6 m day read as a good day.
      expect(loaded.visibilityScale.bandFor(6), VisibilityBand.good);
    });

    test('round-trips custom thresholds', () async {
      await repository.createSettingsForDiver('d1');
      await repository.updateSettingsForDiver(
        'd1',
        const AppSettings(
          visibilityScalePreset: VisibilityScalePreset.custom,
          visibilityScaleExcellentM: 18,
          visibilityScaleGoodM: 9,
          visibilityScaleModerateM: 3,
        ),
      );
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.visibilityScalePreset, VisibilityScalePreset.custom);
      expect(loaded.visibilityScaleExcellentM, 18);
      expect(loaded.visibilityScaleGoodM, 9);
      expect(loaded.visibilityScaleModerateM, 3);
      expect(loaded.visibilityScale.bandFor(9), VisibilityBand.good);
    });

    test('an unrecognized stored preset falls back to tropical', () async {
      await repository.createSettingsForDiver('d1');
      await db.customStatement(
        "UPDATE diver_settings SET visibility_scale_preset = 'nonsense' "
        "WHERE diver_id = 'd1'",
      );
      final loaded = await repository.getSettingsForDiver('d1');
      // A corrupt preference must degrade, not throw.
      expect(loaded!.visibilityScalePreset, VisibilityScalePreset.tropical);
      expect(loaded.visibilityScale, VisibilityScale.tropical);
    });
  });
}
