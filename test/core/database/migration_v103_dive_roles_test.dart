import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  group('v103 dive_roles migration', () {
    test('fresh database has dive_roles with 9 built-in seeds and '
        'dives.diver_role column', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(() => db.close());

      final seeds = await db
          .customSelect(
            'SELECT id, name, is_built_in, sort_order FROM dive_roles '
            'ORDER BY sort_order',
          )
          .get();
      expect(seeds.length, 9);
      expect(seeds.map((r) => r.read<String>('id')).toList(), [
        'buddy',
        'diveGuide',
        'instructor',
        'student',
        'diveMaster',
        'solo',
        'rearGuard',
        'supportDiver',
        'safetyDiver',
      ]);
      expect(seeds.every((r) => r.read<int>('is_built_in') == 1), isTrue);

      final diveCols = await db
          .customSelect("PRAGMA table_info('dives')")
          .get();
      expect(
        diveCols.map((c) => c.read<String>('name')),
        contains('diver_role'),
      );
    });

    test('real onUpgrade from v102 creates dive_roles, seeds built-ins, '
        'and adds dives.diver_role preserving rows', () async {
      final nativeDb = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 102');
          // Minimal v102-shaped dives table: only the columns this test and
          // the beforeOpen index backstops touch. If ensurePerformanceIndexes
          // fails on a missing column, add that column here.
          // dive_roles references divers; the FK parent must exist for the
          // seed insert to run with foreign_keys ON.
          rawDb.execute('''
            CREATE TABLE divers (
              id TEXT PRIMARY KEY NOT NULL,
              name TEXT NOT NULL,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          rawDb.execute('''
            CREATE TABLE dives (
              id TEXT PRIMARY KEY NOT NULL,
              diver_id TEXT,
              dive_date_time INTEGER NOT NULL,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              buddy TEXT,
              hlc TEXT
            )
          ''');
          rawDb.execute(
            "INSERT INTO dives (id, dive_date_time, created_at, updated_at) "
            "VALUES ('d1', 1000, 1000, 1000)",
          );
        },
      );
      final db = AppDatabase(nativeDb);
      addTearDown(() => db.close());

      final seeds = await db.customSelect('SELECT id FROM dive_roles').get();
      expect(seeds.length, 9);

      final diveCols = await db
          .customSelect("PRAGMA table_info('dives')")
          .get();
      expect(
        diveCols.map((c) => c.read<String>('name')),
        contains('diver_role'),
      );

      final rows = await db
          .customSelect('SELECT id, diver_role FROM dives')
          .get();
      expect(rows.length, 1);
      expect(rows.single.read<String?>('diver_role'), isNull);
    });

    test('beforeOpen backstop heals a database already at '
        'currentSchemaVersion that is missing the v103 objects', () async {
      final nativeDb = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute(
            'PRAGMA user_version = ${AppDatabase.currentSchemaVersion}',
          );
          // dive_roles references divers; the FK parent must exist for the
          // seed insert to run with foreign_keys ON.
          rawDb.execute('''
            CREATE TABLE divers (
              id TEXT PRIMARY KEY NOT NULL,
              name TEXT NOT NULL,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          rawDb.execute('''
            CREATE TABLE dives (
              id TEXT PRIMARY KEY NOT NULL,
              diver_id TEXT,
              dive_date_time INTEGER NOT NULL,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              buddy TEXT,
              hlc TEXT
            )
          ''');
        },
      );
      final db = AppDatabase(nativeDb);
      addTearDown(() => db.close());

      final seeds = await db.customSelect('SELECT id FROM dive_roles').get();
      expect(seeds.length, 9);
      final diveCols = await db
          .customSelect("PRAGMA table_info('dives')")
          .get();
      expect(
        diveCols.map((c) => c.read<String>('name')),
        contains('diver_role'),
      );
    });

    test('version ladder includes 103', () {
      expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(103));
      expect(AppDatabase.migrationVersions, contains(103));
    });
  });
}
