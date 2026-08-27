import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/utils/coordinates/coordinate_format.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  group('AppSettings.coordinateFormat', () {
    test('defaults to decimal degrees so upgrading changes no notation', () {
      const settings = AppSettings();
      expect(settings.coordinateFormat, CoordinateFormat.decimalDegrees);
    });

    test('copyWith carries the format', () {
      const settings = AppSettings();
      final updated = settings.copyWith(
        coordinateFormat: CoordinateFormat.mgrs,
      );
      expect(updated.coordinateFormat, CoordinateFormat.mgrs);
      // Unrelated settings survive.
      expect(updated.depthUnit, settings.depthUnit);
    });
  });

  group('DiverSettingsRepository coordinate format persistence', () {
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

    test('new settings default to decimal degrees', () async {
      await repository.createSettingsForDiver('d1');
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.coordinateFormat, CoordinateFormat.decimalDegrees);
    });

    for (final format in CoordinateFormat.values) {
      test('round-trips ${format.name}', () async {
        await repository.createSettingsForDiver('d1');
        await repository.updateSettingsForDiver(
          'd1',
          AppSettings(coordinateFormat: format),
        );
        final loaded = await repository.getSettingsForDiver('d1');
        expect(loaded!.coordinateFormat, format);
      });
    }

    test('an unrecognized stored format degrades to decimal degrees', () async {
      await repository.createSettingsForDiver('d1');
      await db.customStatement(
        "UPDATE diver_settings SET coordinate_format = 'nonsense' "
        "WHERE diver_id = 'd1'",
      );
      final loaded = await repository.getSettingsForDiver('d1');
      // A corrupt preference must degrade, not throw.
      expect(loaded!.coordinateFormat, CoordinateFormat.decimalDegrees);
    });
  });
}
