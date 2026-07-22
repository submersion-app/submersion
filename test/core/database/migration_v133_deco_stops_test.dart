import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

import '../../helpers/test_database.dart';

/// Minimal pre-v133 diver_settings shape: enough columns to insert a row,
/// deliberately without the two deco stop band columns.
const _preV133DiverSettings = '''
  CREATE TABLE diver_settings (
    id TEXT NOT NULL PRIMARY KEY,
    diver_id TEXT NOT NULL,
    show_ceiling_on_profile INTEGER NOT NULL DEFAULT 1,
    default_ceiling_source INTEGER NOT NULL DEFAULT 1
  )
''';

const _insertLegacyRow =
    "INSERT INTO diver_settings "
    "(id, diver_id, show_ceiling_on_profile, default_ceiling_source) "
    "VALUES ('s1', 'd1', 0, 0)";

void main() {
  group('fresh install (onCreate)', () {
    late AppDatabase db;

    setUp(() => db = createTestDatabase());
    tearDown(() => db.close());

    test('diver_settings has the deco stop band columns', () async {
      final rows = await db
          .customSelect("PRAGMA table_info('diver_settings')")
          .get();
      final cols = [for (final r in rows) r.read<String>('name')];
      expect(cols, contains('show_deco_stops_on_profile'));
      expect(cols, contains('default_deco_stop_source'));
    });

    test('deco stop columns default to visible and calculated', () async {
      final rows = await db
          .customSelect("PRAGMA table_info('diver_settings')")
          .get();
      final byName = {
        for (final r in rows)
          r.read<String>('name'): r.read<String?>('dflt_value'),
      };
      expect(byName['show_deco_stops_on_profile'], '1');
      expect(byName['default_deco_stop_source'], '1');
    });
  });

  group('upgrade (onUpgrade)', () {
    test('v133 adds both columns to an existing database, preserving rows and '
        'applying the defaults to legacy rows', () async {
      final nativeDb = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 132');
          rawDb.execute(_preV133DiverSettings);
          rawDb.execute(_insertLegacyRow);
        },
      );

      final db = AppDatabase(nativeDb);
      addTearDown(db.close);

      final cols = await db
          .customSelect("PRAGMA table_info('diver_settings')")
          .get();
      final names = cols.map((c) => c.read<String>('name')).toSet();
      expect(names, contains('show_deco_stops_on_profile'));
      expect(names, contains('default_deco_stop_source'));

      final row = await db
          .customSelect(
            'SELECT show_ceiling_on_profile, default_ceiling_source, '
            'show_deco_stops_on_profile, default_deco_stop_source '
            "FROM diver_settings WHERE id = 's1'",
          )
          .getSingle();

      // The diver's existing ceiling preferences survive untouched.
      expect(row.data['show_ceiling_on_profile'], 0);
      expect(row.data['default_ceiling_source'], 0);
      // The new non-nullable columns take their defaults on the legacy row.
      expect(row.data['show_deco_stops_on_profile'], 1);
      expect(row.data['default_deco_stop_source'], 1);
    });

    test(
      'the migration is idempotent when the columns already exist',
      () async {
        // Exercises the PRAGMA guard branch: no duplicate ALTER, no thrown
        // "duplicate column name" error, and existing values are not reset.
        final nativeDb = NativeDatabase.memory(
          setup: (rawDb) {
            rawDb.execute('PRAGMA user_version = 132');
            rawDb.execute('''
            CREATE TABLE diver_settings (
              id TEXT NOT NULL PRIMARY KEY,
              diver_id TEXT NOT NULL,
              show_ceiling_on_profile INTEGER NOT NULL DEFAULT 1,
              default_ceiling_source INTEGER NOT NULL DEFAULT 1,
              show_deco_stops_on_profile INTEGER NOT NULL DEFAULT 1,
              default_deco_stop_source INTEGER NOT NULL DEFAULT 1
            )
          ''');
            rawDb.execute(
              'INSERT INTO diver_settings (id, diver_id, '
              'show_deco_stops_on_profile, default_deco_stop_source) '
              "VALUES ('s1', 'd1', 0, 0)",
            );
          },
        );

        final db = AppDatabase(nativeDb);
        addTearDown(db.close);

        final cols = await db
            .customSelect("PRAGMA table_info('diver_settings')")
            .get();
        final names = cols.map((c) => c.read<String>('name')).toList();
        expect(
          names.where((n) => n == 'show_deco_stops_on_profile').length,
          1,
          reason: 'show_deco_stops_on_profile should exist exactly once',
        );
        expect(
          names.where((n) => n == 'default_deco_stop_source').length,
          1,
          reason: 'default_deco_stop_source should exist exactly once',
        );

        final row = await db
            .customSelect(
              'SELECT show_deco_stops_on_profile, default_deco_stop_source '
              "FROM diver_settings WHERE id = 's1'",
            )
            .getSingle();
        expect(row.data['show_deco_stops_on_profile'], 0);
        expect(row.data['default_deco_stop_source'], 0);
      },
    );
  });

  group('beforeOpen backstop', () {
    test('heals a database already stamped at currentSchemaVersion that is '
        'missing the deco stop columns', () async {
      // The parallel-branch collision case: another branch shipped the same
      // version number, so onUpgrade never runs for this database.
      final nativeDb = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute(
            'PRAGMA user_version = ${AppDatabase.currentSchemaVersion}',
          );
          rawDb.execute(_preV133DiverSettings);
          rawDb.execute(_insertLegacyRow);
        },
      );

      final db = AppDatabase(nativeDb);
      addTearDown(db.close);

      final cols = await db
          .customSelect("PRAGMA table_info('diver_settings')")
          .get();
      final names = cols.map((c) => c.read<String>('name')).toSet();
      expect(
        names,
        contains('show_deco_stops_on_profile'),
        reason: 'the beforeOpen backstop must add the column',
      );
      expect(names, contains('default_deco_stop_source'));
    });
  });

  test('v133 deco-stops migration stays in the schema ladder', () {
    // Relaxed from an exact-latest tripwire: v134 (media compressed rendition
    // columns) landed on top of v133, so the exact-latest assertion now lives
    // in media_compressed_columns_migration_test.dart.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(133));
    expect(AppDatabase.migrationVersions, contains(133));
  });
}
