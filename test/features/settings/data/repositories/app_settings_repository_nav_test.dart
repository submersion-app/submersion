import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
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
      await repo.setNavPrimaryIds(['equipment', 'buddies', 'statistics']);
      expect(await repo.getNavPrimaryIdsRaw(), [
        'equipment',
        'buddies',
        'statistics',
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
}
