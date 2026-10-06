import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v265: insight_observation_dismissals and
/// diver_settings.insights_muted_observation_rules (issue #2381).
void main() {
  /// A database at [version] with only the tables v265 touches.
  NativeDatabase setupDb({int version = 264, bool withParents = true}) =>
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = $version');
          if (!withParents) return;
          rawDb.execute('CREATE TABLE divers (id TEXT NOT NULL PRIMARY KEY)');
          rawDb.execute(
            'CREATE TABLE diver_settings (id TEXT NOT NULL PRIMARY KEY, '
            'diver_id TEXT NOT NULL, created_at INTEGER NOT NULL, '
            'updated_at INTEGER NOT NULL)',
          );
          rawDb.execute("INSERT INTO diver_settings VALUES ('s1', 'd1', 0, 0)");
        },
      );

  Future<Map<String, bool>> columnsOf(AppDatabase db, String table) async {
    final cols = await db.customSelect("PRAGMA table_info('$table')").get();
    return {
      for (final c in cols) c.read<String>('name'): c.read<int>('notnull') == 0,
    };
  }

  test('version bookkeeping', () {
    // Relaxed once v266 (media site attachment columns, #1039) landed on
    // top; the newest rung owns the exact assertions.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(265));
    expect(AppDatabase.migrationVersions, contains(265));
    expect(
      AppDatabase.migrationStepCount(264),
      AppDatabase.migrationStepCount(265) + 1,
    );
    expect(AppDatabase.minimumCompatibleSchemaVersion, 240);
  });

  test('upgrading from v264 adds the table and the nullable column', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();
    final table = await columnsOf(db, 'insight_observation_dismissals');
    expect(table.keys.toSet(), {
      'id',
      'diver_id',
      'rule_id',
      'fingerprint',
      'dismissed_at',
      'created_at',
      'updated_at',
      'hlc',
    });
    expect(table['dismissed_at'], isTrue, reason: 'dismissed_at is nullable');
    final settings = await columnsOf(db, 'diver_settings');
    expect(settings['insights_muted_observation_rules'], isTrue);
    final row = await db
        .customSelect(
          'SELECT insights_muted_observation_rules AS m FROM diver_settings',
        )
        .getSingle();
    expect(row.readNullable<String>('m'), isNull);
  });

  test('a fixture without the parents gains no table', () async {
    final db = AppDatabase(setupDb(withParents: false));
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();
    expect(await columnsOf(db, 'insight_observation_dismissals'), isEmpty);
  });

  test('the backstop heals a current-version file missing both', () async {
    final db = AppDatabase(setupDb(version: AppDatabase.currentSchemaVersion));
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();
    expect(
      await columnsOf(db, 'insight_observation_dismissals'),
      contains('fingerprint'),
    );
    expect(
      await columnsOf(db, 'diver_settings'),
      contains('insights_muted_observation_rules'),
    );
  });

  test('a fresh database has both', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(
      await columnsOf(db, 'insight_observation_dismissals'),
      contains('rule_id'),
    );
    expect(
      await columnsOf(db, 'diver_settings'),
      contains('insights_muted_observation_rules'),
    );
  });
}
