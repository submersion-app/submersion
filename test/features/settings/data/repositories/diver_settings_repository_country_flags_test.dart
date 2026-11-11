import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// The country flags switch (issue #4426) must survive a real write and read
/// through SQLite: a missing companion or row mapping would leave "off"
/// working only in memory, and the flags would come back at the next load.
void main() {
  group('DiverSettingsRepository showCountryFlags persistence', () {
    late DiverSettingsRepository repository;

    setUp(() async {
      final db = await setUpTestDatabase();
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

    test('flags default to on', () async {
      expect(const AppSettings().showCountryFlags, isTrue);
      await repository.createSettingsForDiver('d1');
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.showCountryFlags, isTrue);
    });

    test('update round-trips off, then back on', () async {
      await repository.createSettingsForDiver('d1');

      await repository.updateSettingsForDiver(
        'd1',
        const AppSettings(showCountryFlags: false),
      );
      expect(
        (await repository.getSettingsForDiver('d1'))!.showCountryFlags,
        isFalse,
      );

      await repository.updateSettingsForDiver(
        'd1',
        const AppSettings(showCountryFlags: true),
      );
      expect(
        (await repository.getSettingsForDiver('d1'))!.showCountryFlags,
        isTrue,
      );
    });

    test('copyWith carries the switch', () {
      const settings = AppSettings();
      expect(
        settings.copyWith(showCountryFlags: false).showCountryFlags,
        isFalse,
      );
      expect(
        settings.copyWith(showCountryFlags: false).copyWith().showCountryFlags,
        isFalse,
      );
    });
  });
}
