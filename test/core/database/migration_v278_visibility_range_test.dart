import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Schema v278: dives.visibility_min_meters / visibility_max_meters (issue
/// #3226).
void main() {
  Future<Set<String>> diveColumns(AppDatabase db) async {
    final cols = await db.customSelect("PRAGMA table_info('dives')").get();
    return cols.map((c) => c.read<String>('name')).toSet();
  }

  test('v278 is at or below the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(278));
    expect(AppDatabase.migrationVersions, contains(278));
    expect(
      AppDatabase.migrationStepCount(277),
      AppDatabase.migrationStepCount(278) + 1,
    );
  });

  test('this rung is additive and never was the sync floor', () {
    // v278 is additive; v279 (#2361) later raised the floor for an
    // unrelated reason, so assert only that 278 itself was never the floor.
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(278));
  });

  test('a fresh database has both range columns', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(
      await diveColumns(db),
      containsAll(['visibility_min_meters', 'visibility_max_meters']),
    );
  });

  test('upgrading from v277 adds both columns and keeps visibility', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute('PRAGMA user_version = 277');
          raw.execute(
            'CREATE TABLE dives (id TEXT NOT NULL PRIMARY KEY, '
            'dive_date_time INTEGER, visibility TEXT, visibility_meters REAL)',
          );
          raw.execute(
            "INSERT INTO dives (id, dive_date_time, visibility_meters) "
            "VALUES ('d1', 0, 6.5)",
          );
        },
      ),
    );
    addTearDown(db.close);

    expect(
      await diveColumns(db),
      containsAll(['visibility_min_meters', 'visibility_max_meters']),
    );
    final row = await db
        .customSelect(
          'SELECT visibility_meters AS m, visibility_min_meters AS lo, '
          'visibility_max_meters AS hi FROM dives',
        )
        .getSingle();
    expect(row.read<double>('m'), 6.5);
    expect(row.read<double?>('lo'), isNull);
    expect(row.read<double?>('hi'), isNull);
  });
}
