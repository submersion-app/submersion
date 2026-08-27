import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

void main() {
  test('v144 is in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(144));
    expect(AppDatabase.migrationVersions, contains(144));
  });

  test('a fresh database has dives.visibility_meters', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db.customSelect("PRAGMA table_info('dives')").get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('visibility_meters'));
  });

  test('a fresh database keeps the legacy dives.visibility column', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db.customSelect("PRAGMA table_info('dives')").get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('visibility'));
  });

  test('a fresh database has the diver_settings calibration columns', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('visibility_scale_preset'));
    expect(names, contains('visibility_scale_excellent_m'));
    expect(names, contains('visibility_scale_good_m'));
    expect(names, contains('visibility_scale_moderate_m'));
  });

  test('the calibration preset defaults to tropical', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    final preset = cols.firstWhere(
      (c) => c.read<String>('name') == 'visibility_scale_preset',
    );
    // Defaulting to tropical reproduces the pre-v144 thresholds, so upgrading
    // re-labels nobody's logbook.
    expect(preset.read<String?>('dflt_value'), contains('tropical'));
  });

  test(
    'a database stranded before v144 gains visibility_meters via beforeOpen',
    () async {
      // Only the columns this migration touches are modelled. The beforeOpen
      // backstop must add visibility_meters even when onUpgrade never ran
      // (v138/v140/v143 are reserved by parallel branches, so a DB can arrive
      // at an intermediate version without this column).
      final nativeDb = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('''
          CREATE TABLE dives (
            id TEXT NOT NULL PRIMARY KEY,
            dive_date_time INTEGER,
            visibility TEXT
          )
        ''');
        },
      );
      final db = AppDatabase(nativeDb);
      addTearDown(db.close);

      final cols = await db.customSelect("PRAGMA table_info('dives')").get();
      expect(
        cols.map((c) => c.read<String>('name')).toSet(),
        contains('visibility_meters'),
      );
    },
  );

  test('a database stranded before v144 gains the calibration columns via '
      'beforeOpen', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('''
          CREATE TABLE diver_settings (
            id TEXT NOT NULL PRIMARY KEY,
            created_at INTEGER,
            updated_at INTEGER
          )
        ''');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('visibility_scale_preset'));
    expect(names, contains('visibility_scale_excellent_m'));
    expect(names, contains('visibility_scale_good_m'));
    expect(names, contains('visibility_scale_moderate_m'));
  });

  test('legacy bucket rows are not backfilled', () async {
    // The whole point of keeping both columns: we do not know where in the
    // 5-15 m band a 'moderate' dive actually fell, so inventing a number
    // would fabricate precision the diver never entered.
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('''
          CREATE TABLE dives (
            id TEXT NOT NULL PRIMARY KEY,
            dive_date_time INTEGER,
            visibility TEXT
          )
        ''');
        rawDb.execute(
          "INSERT INTO dives (id, dive_date_time, visibility) "
          "VALUES ('legacy-1', 0, 'moderate')",
        );
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    final row = await db
        .customSelect(
          "SELECT visibility, visibility_meters FROM dives "
          "WHERE id = 'legacy-1'",
        )
        .getSingle();
    expect(row.read<String?>('visibility'), 'moderate');
    expect(row.read<double?>('visibility_meters'), isNull);
  });

  test('the asserts are no-ops when the tables are absent', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('CREATE TABLE unrelated (id TEXT)');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    // Opening must not throw on a minimal fixture.
    await db.customSelect('SELECT 1').get();
  });
}
