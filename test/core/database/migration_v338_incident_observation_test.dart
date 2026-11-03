import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v338: incidents gains observation_id (issue #3062), the gear
/// check-in that recorded the fault behind a near-miss. Every existing report
/// stays as it was, with no link.
void main() {
  NativeDatabase dbAt(int version, {bool withColumn = false}) =>
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = $version');
          rawDb.execute(
            'CREATE TABLE equipment_observations ('
            'id TEXT NOT NULL PRIMARY KEY, diver_id TEXT, '
            'equipment_id TEXT NOT NULL, dive_id TEXT, '
            'observed_at INTEGER NOT NULL, status TEXT NOT NULL, '
            "issue_tags TEXT NOT NULL DEFAULT '[]', "
            "note TEXT NOT NULL DEFAULT '', "
            'created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, '
            'hlc TEXT)',
          );
          rawDb.execute(
            'CREATE TABLE incidents ('
            'id TEXT NOT NULL PRIMARY KEY, diver_id TEXT, dive_id TEXT, '
            'equipment_id TEXT, occurred_at INTEGER NOT NULL, '
            'category TEXT NOT NULL, severity TEXT NOT NULL, '
            'narrative TEXT NOT NULL, contributing_factors TEXT, '
            'lessons_learned TEXT, created_at INTEGER NOT NULL, '
            'updated_at INTEGER NOT NULL, '
            'hlc TEXT${withColumn ? ', observation_id TEXT' : ''})',
          );
          rawDb.execute(
            'INSERT INTO incidents (id, occurred_at, category, severity, '
            'narrative, created_at, updated_at) '
            "VALUES ('i1', 1, 'equipment', 'minor', 'Free flow', 1, 1)",
          );
        },
      );

  test('v338 is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(338));
    expect(AppDatabase.migrationVersions, contains(338));
  });

  test('the column is additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(338));
  });

  test('upgrading leaves every report unlinked and intact', () async {
    final db = AppDatabase(dbAt(336));
    addTearDown(db.close);
    final row = await db
        .customSelect('SELECT narrative, observation_id FROM incidents')
        .getSingle();
    expect(row.read<String>('narrative'), 'Free flow');
    expect(row.read<String?>('observation_id'), isNull);
  });

  test(
    'the link clears, and the report stays, when its check-in goes',
    () async {
      final db = AppDatabase(dbAt(336));
      addTearDown(db.close);
      final keys = await db
          .customSelect("PRAGMA foreign_key_list('incidents')")
          .get();
      final key = keys.singleWhere(
        (k) => k.read<String>('from') == 'observation_id',
      );
      expect(key.read<String>('table'), 'equipment_observations');
      expect(key.read<String>('on_delete'), 'SET NULL');
    },
  );

  test('a database already carrying the column is left alone', () async {
    final db = AppDatabase(dbAt(336, withColumn: true));
    addTearDown(db.close);
    final columns =
        (await db.customSelect("PRAGMA table_info('incidents')").get())
            .map((c) => c.read<String>('name'))
            .where((n) => n == 'observation_id');
    expect(columns, hasLength(1));
  });

  test('the backstop restores the column at v338', () async {
    final db = AppDatabase(dbAt(AppDatabase.currentSchemaVersion));
    addTearDown(db.close);
    final row = await db
        .customSelect('SELECT observation_id FROM incidents')
        .getSingle();
    expect(row.read<String?>('observation_id'), isNull);
  });
}
