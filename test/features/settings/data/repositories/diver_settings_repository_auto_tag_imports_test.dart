import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// The auto-tag-imports opt-out (issue #998) must survive a real write and
/// read through SQLite: a missing companion or row mapping would leave the
/// tag management switch working only in memory, and the saved "off" would
/// silently revert to on at the next load.
void main() {
  group('DiverSettingsRepository autoTagImports persistence', () {
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
      expect(loaded!.autoTagImports, isTrue);
    });

    test('create persists an explicit off', () async {
      await repository.createSettingsForDiver(
        'd1',
        settings: const AppSettings(autoTagImports: false),
      );
      final loaded = await repository.getSettingsForDiver('d1');
      expect(loaded!.autoTagImports, isFalse);
    });

    test('update round-trips off, then back on', () async {
      await repository.createSettingsForDiver('d1');

      await repository.updateSettingsForDiver(
        'd1',
        const AppSettings(autoTagImports: false),
      );
      expect(
        (await repository.getSettingsForDiver('d1'))!.autoTagImports,
        isFalse,
      );

      await repository.updateSettingsForDiver(
        'd1',
        const AppSettings(autoTagImports: true),
      );
      expect(
        (await repository.getSettingsForDiver('d1'))!.autoTagImports,
        isTrue,
      );
    });
  });
}
