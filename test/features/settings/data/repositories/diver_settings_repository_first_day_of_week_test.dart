import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/first_day_of_week.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// Issue #4232: the diver's first day of the week.
void main() {
  group('AppSettings.firstDayOfWeek', () {
    test('defaults to automatic', () {
      expect(const AppSettings().firstDayOfWeek, FirstDayOfWeek.auto);
    });

    test('copyWith carries the day', () {
      const settings = AppSettings();
      final updated = settings.copyWith(firstDayOfWeek: FirstDayOfWeek.monday);
      expect(updated.firstDayOfWeek, FirstDayOfWeek.monday);
      // Unrelated settings survive.
      expect(updated.dateFormat, settings.dateFormat);
    });
  });

  group('DiverSettingsRepository first day of week persistence', () {
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

    test('new settings start on automatic', () async {
      await repository.createSettingsForDiver('d1');
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.firstDayOfWeek, FirstDayOfWeek.auto);
    });

    test('new settings keep a first day passed in', () async {
      await repository.createSettingsForDiver(
        'd1',
        settings: const AppSettings(firstDayOfWeek: FirstDayOfWeek.saturday),
      );
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.firstDayOfWeek, FirstDayOfWeek.saturday);
    });

    for (final day in FirstDayOfWeek.values) {
      test('round-trips ${day.name}', () async {
        await repository.createSettingsForDiver('d1');
        await repository.updateSettingsForDiver(
          'd1',
          AppSettings(firstDayOfWeek: day),
        );
        final loaded = await repository.getSettingsForDiver('d1');
        expect(loaded!.firstDayOfWeek, day);
      });
    }

    test('an unrecognized stored day reads as automatic', () async {
      await repository.createSettingsForDiver('d1');
      await db.customStatement(
        "UPDATE diver_settings SET first_day_of_week = 'thursday' "
        "WHERE diver_id = 'd1'",
      );
      final loaded = await repository.getSettingsForDiver('d1');
      // A value a newer peer wrote must degrade, not throw.
      expect(loaded!.firstDayOfWeek, FirstDayOfWeek.auto);
    });
  });
}
