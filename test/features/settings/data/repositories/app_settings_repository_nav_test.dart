import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppSettingsRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    repo = AppSettingsRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('AppSettingsRepository nav primary ids', () {
    test('returns null when never set', () async {
      expect(await repo.getNavPrimaryIdsRaw(), isNull);
    });

    test('round-trip stores and reads the list unchanged', () async {
      await repo.setNavPrimaryIds(['equipment', 'buddies', 'insights']);
      expect(await repo.getNavPrimaryIdsRaw(), [
        'equipment',
        'buddies',
        'insights',
      ]);
    });

    test('overwrite replaces the previous value', () async {
      await repo.setNavPrimaryIds(['a', 'b', 'c']);
      await repo.setNavPrimaryIds(['x', 'y', 'z']);
      expect(await repo.getNavPrimaryIdsRaw(), ['x', 'y', 'z']);
    });

    test('empty list is stored and returned as empty', () async {
      await repo.setNavPrimaryIds(const []);
      expect(await repo.getNavPrimaryIdsRaw(), const <String>[]);
    });

    test('returns null when stored value is not valid JSON', () async {
      // Manually insert a non-JSON value to exercise the error path.
      final db = DatabaseService.instance.database;
      final now = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.settings)
          .insertOnConflictUpdate(
            SettingsCompanion.insert(
              key: 'nav_primary_ids',
              value: const Value('not-json'),
              updatedAt: now,
            ),
          );
      expect(await repo.getNavPrimaryIdsRaw(), isNull);
    });
  });

  group('device-local keys are not queued for sync', () {
    Future<Set<String>> pendingSettingsKeys() async => {
      for (final r in await SyncRepository().getPendingRecords())
        if (r.entityType == 'settings') r.recordId,
    };

    test('nav layout writes queue nothing', () async {
      await repo.setNavPrimaryIds(['dives']);
      await repo.setNavRailIds(['dives']);
      await repo.setNavAlwaysHideLabels(true);
      expect(
        (await pendingSettingsKeys()).intersection({
          'nav_primary_ids',
          'nav_rail_ids',
          'nav_always_hide_labels',
        }),
        isEmpty,
      );
      expect(await repo.getNavAlwaysHideLabels(), isTrue);
    });

    test('a synced key is still queued', () async {
      await repo.setRawSetting('share_new_records_by_default', 'true');
      expect(
        await pendingSettingsKeys(),
        contains('share_new_records_by_default'),
      );
    });
  });
}
