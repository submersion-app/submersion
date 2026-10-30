import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// The skip-unused-bailout-gases switch (issue #3668) must survive a real
/// write and read through SQLite: a missing companion or row mapping would
/// leave the switch working only in memory, and the saved "on" would silently
/// revert to off at the next load.
void main() {
  group('DiverSettingsRepository omitUnusedOcGases persistence', () {
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

    test('new settings default to off', () async {
      await repository.createSettingsForDiver('d1');
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded, isNotNull);
      expect(loaded!.omitUnusedOcGases, isFalse);
    });

    test('create persists an explicit on', () async {
      await repository.createSettingsForDiver(
        'd1',
        settings: const AppSettings(omitUnusedOcGases: true),
      );
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.omitUnusedOcGases, isTrue);
    });

    test('update round-trips on, then back off', () async {
      await repository.createSettingsForDiver('d1');

      await repository.updateSettingsForDiver(
        'd1',
        const AppSettings(omitUnusedOcGases: true),
      );
      expect(
        (await repository.getSettingsForDiver('d1'))!.omitUnusedOcGases,
        isTrue,
      );

      await repository.updateSettingsForDiver(
        'd1',
        const AppSettings(omitUnusedOcGases: false),
      );
      expect(
        (await repository.getSettingsForDiver('d1'))!.omitUnusedOcGases,
        isFalse,
      );
    });
  });
}
