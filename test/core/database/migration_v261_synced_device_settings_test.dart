import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// v261: diver_settings columns for settings that now sync (issue #2948):
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

  test('v261 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 261);
    expect(AppDatabase.migrationVersions, contains(261));
    expect(AppDatabase.migrationStepCount(260), 1);
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

  test('a database stranded before v261 gains the columns', () async {
    final db = AppDatabase(strandedAt(null));
    addTearDown(db.close);
    expect((await settingsColumns(db)).keys, containsAll(newColumns));
  });

  test(
    'a database already at v261 without them regains them via beforeOpen',
    () async {
      final db = AppDatabase(strandedAt(AppDatabase.currentSchemaVersion));
      addTearDown(db.close);
      expect((await settingsColumns(db)).keys, containsAll(newColumns));
    },
  );
}
