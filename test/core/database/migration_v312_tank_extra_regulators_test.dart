import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Schema v312: dive_tanks.extra_regulator_ids (issue #3375).
void main() {
  /// A v311 database: `dive_tanks` with its first regulator and no extras.
  NativeDatabase setupDb({int userVersion = 311}) {
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = $userVersion');
        rawDb.execute('''
          CREATE TABLE dive_tanks (
            id TEXT NOT NULL PRIMARY KEY,
            dive_id TEXT NOT NULL,
            regulator_equipment_id TEXT
          )
        ''');
        rawDb.execute(
          "INSERT INTO dive_tanks (id, dive_id, regulator_equipment_id) "
          "VALUES ('t1', 'd1', 'reg-1')",
        );
      },
    );
  }

  Future<Map<String, Map<String, Object?>>> columnsOf(
    AppDatabase db,
    String table,
  ) async {
    final cols = await db.customSelect("PRAGMA table_info('$table')").get();
    return {for (final c in cols) c.read<String>('name'): c.data};
  }

  test('v312 is the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(312));
    expect(AppDatabase.migrationVersions, contains(312));
  });

  test('the column is additive, so the sync floor does not move', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, 308);
  });

  test(
    'upgrading from v311 adds the column and keeps the first regulator',
    () async {
      final db = AppDatabase(setupDb());
      addTearDown(db.close);

      final column = (await columnsOf(db, 'dive_tanks'))['extra_regulator_ids'];
      expect(column, isNotNull);
      expect(column!['type'], 'TEXT');
      expect(column['notnull'], 0);

      final row = await db
          .customSelect(
            'SELECT regulator_equipment_id, extra_regulator_ids '
            "FROM dive_tanks WHERE id = 't1'",
          )
          .getSingle();
      expect(row.data['regulator_equipment_id'], 'reg-1');
      expect(row.data['extra_regulator_ids'], isNull);

      final index = await db
          .customSelect(
            "SELECT sql FROM sqlite_master WHERE type = 'index' "
            "AND name = 'idx_dive_tanks_extra_regulators'",
          )
          .getSingleOrNull();
      expect(
        index?.read<String>('sql'),
        contains('WHERE extra_regulator_ids IS NOT NULL'),
      );
    },
  );

  test(
    'a database stamped v312 without the column heals in beforeOpen',
    () async {
      final db = AppDatabase(setupDb(userVersion: 312));
      addTearDown(db.close);

      expect(
        (await columnsOf(db, 'dive_tanks')).keys,
        contains('extra_regulator_ids'),
      );
    },
  );
}
