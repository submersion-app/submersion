import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// v262: diver_settings columns for settings that now sync (issue #2948):
/// the certification and course list view modes, and the profile "metrics
/// follow viewport" and pSCR ratio preferences, which were device-local.
void main() {
  Future<Map<String, Map<String, Object?>>> settingsColumns(
    AppDatabase db,
  ) async {
    final cols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    return {for (final c in cols) c.read<String>('name'): c.data};
  }

  NativeDatabase strandedAt(int? userVersion) => NativeDatabase.memory(
    setup: (rawDb) {
      if (userVersion != null) {
        rawDb.execute('PRAGMA user_version = $userVersion');
      }
      rawDb.execute('''
        CREATE TABLE diver_settings (
          id TEXT NOT NULL PRIMARY KEY,
          created_at INTEGER,
          updated_at INTEGER
        )
      ''');
    },
  );

  const newColumns = [
    'certification_list_view_mode',
    'course_list_view_mode',
    'profile_metrics_follow_viewport',
    'pscr_ratio',
  ];

  test('v262 is in the ladder, between v261 and v263', () {
    // Relaxed once v263 (distance unit, #3004) landed on top; the newest
    // rung owns the exact assertion.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(262));
    const ladder = AppDatabase.migrationVersions;
    expect(ladder, contains(262));
    expect(ladder.indexOf(262), ladder.indexOf(261) + 1);
    expect(
      AppDatabase.migrationStepCount(261),
      AppDatabase.migrationStepCount(262) + 1,
    );
  });

  test('the columns are additive, so the sync floor does not move', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, 240);
  });

  test('a fresh database has the view modes defaulted and the moved '
      'preferences nullable', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final cols = await settingsColumns(db);
    for (final name in [
      'certification_list_view_mode',
      'course_list_view_mode',
    ]) {
      expect(cols[name]!['notnull'], 1, reason: name);
      expect(cols[name]!['dflt_value'], contains('detailed'), reason: name);
    }
    for (final name in ['profile_metrics_follow_viewport', 'pscr_ratio']) {
      expect(cols[name]!['notnull'], 0, reason: name);
      expect(cols[name]!['dflt_value'], isNull, reason: name);
    }
  });

  test('a database stranded before v262 gains the columns', () async {
    final db = AppDatabase(strandedAt(null));
    addTearDown(db.close);
    expect((await settingsColumns(db)).keys, containsAll(newColumns));
  });

  test(
    'a database already current without them regains them via beforeOpen',
    () async {
      final db = AppDatabase(strandedAt(AppDatabase.currentSchemaVersion));
      addTearDown(db.close);
      expect((await settingsColumns(db)).keys, containsAll(newColumns));
    },
  );
}
