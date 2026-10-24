import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// The downloads-follow-owner switch (issue #2050) must survive a real write and
/// read through SQLite: a missing companion or row mapping would leave the
/// switch working only in memory, and the saved "off" would
/// silently revert to on at the next load.
void main() {
  group('DiverSettingsRepository downloadsFollowComputerOwner persistence', () {
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

    test('new settings default to on', () async {
      await repository.createSettingsForDiver('d1');
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded, isNotNull);
      expect(loaded!.downloadsFollowComputerOwner, isTrue);
    });

    test('create persists an explicit off', () async {
      await repository.createSettingsForDiver(
        'd1',
        settings: const AppSettings(downloadsFollowComputerOwner: false),
      );
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.downloadsFollowComputerOwner, isFalse);
    });

    test('update round-trips off, then back on', () async {
      await repository.createSettingsForDiver('d1');

      await repository.updateSettingsForDiver(
        'd1',
        const AppSettings(downloadsFollowComputerOwner: false),
      );
      expect(
        (await repository.getSettingsForDiver(
          'd1',
        ))!.downloadsFollowComputerOwner,
        isFalse,
      );

      await repository.updateSettingsForDiver(
        'd1',
        const AppSettings(downloadsFollowComputerOwner: true),
      );
      expect(
        (await repository.getSettingsForDiver(
          'd1',
        ))!.downloadsFollowComputerOwner,
        isTrue,
      );
    });
  });
}
