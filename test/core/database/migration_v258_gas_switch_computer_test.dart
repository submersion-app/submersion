import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v258: gas_switches.computer_id, the computer whose reading a
/// switch came from (issue #2582).
void main() {
  /// A database at [version] holding one switch to a computer's cylinder and
  /// one to a cylinder no computer owns; [withColumn] gives gas_switches the
  /// v258 column already, both switches unattributed.
  NativeDatabase setupDb({int version = 257, bool withColumn = false}) =>
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = $version');
          // The parent table the column references; beforeOpen runs with
          // foreign keys enforced.
          rawDb.execute(
            'CREATE TABLE dive_computers (id TEXT NOT NULL PRIMARY KEY)',
          );
          rawDb.execute("INSERT INTO dive_computers (id) VALUES ('c1')");
          rawDb.execute(
            'CREATE TABLE dive_tanks (id TEXT NOT NULL PRIMARY KEY, '
            'dive_id TEXT NOT NULL, computer_id TEXT)',
          );
          rawDb.execute(
            'CREATE TABLE gas_switches (id TEXT NOT NULL PRIMARY KEY, '
            'dive_id TEXT NOT NULL, timestamp INTEGER NOT NULL, '
            'tank_id TEXT NOT NULL, depth REAL, created_at INTEGER NOT NULL, '
            'hlc TEXT${withColumn ? ', computer_id TEXT' : ''})',
          );
          rawDb.execute(
            "INSERT INTO dive_tanks (id, dive_id, computer_id) VALUES "
            "('t1', 'd1', 'c1'), ('t2', 'd1', NULL)",
          );
          rawDb.execute(
            'INSERT INTO gas_switches '
            '(id, dive_id, timestamp, tank_id, created_at) VALUES '
            "('s1', 'd1', 0, 't1', 1), ('s2', 'd1', 60, 't2', 1)",
          );
        },
      );

  Future<List<String?>> switchComputers(AppDatabase db) async => [
    for (final r
        in await db
            .customSelect('SELECT computer_id FROM gas_switches ORDER BY id')
            .get())
      r.read<String?>('computer_id'),
  ];

  test('v258 is at or below the current schema version and in the ladder', () {
    // Sits below v259 (dive_tanks.usage_duration, #1496), which main
    // shipped first and which owns the exact assertions.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(258));
    expect(AppDatabase.migrationVersions, containsAll([257, 258, 259]));
    expect(
      AppDatabase.migrationStepCount(257),
      AppDatabase.migrationStepCount(258) + 1,
    );
    expect(AppDatabase.minimumCompatibleSchemaVersion, 240);
  });

  test(
    'upgrading from v257 attributes each switch to its cylinder\'s computer',
    () async {
      final db = AppDatabase(setupDb());
      addTearDown(db.close);
      expect(await switchComputers(db), ['c1', null]);
    },
  );

  test('a database already at v259 without the column gains it, backfill '
      'included, via beforeOpen', () async {
    final db = AppDatabase(setupDb(version: 259));
    addTearDown(db.close);
    expect(await switchComputers(db), ['c1', null]);
  });

  test('a database that has the column keeps an unattributed switch '
      'unattributed: it is one the diver entered', () async {
    final db = AppDatabase(setupDb(version: 259, withColumn: true));
    addTearDown(db.close);
    expect(await switchComputers(db), [null, null]);
  });

  group('a dive more than one computer recorded', () {
    /// A v257 database with dive d1 recorded by computers c1 (primary) and
    /// c2. Consolidation merged c2's cylinder of the same gas into c1's t1
    /// and remapped c2's switch to it, so t1 carries a switch of each
    /// computer; t2 is c2's own cylinder, which matched nothing. Dive d2 is
    /// c1's alone. [primary] picks which source row is primary (null: none
    /// is; 'file': a file-imported source naming no computer), and
    /// [secondSourceRow] false leaves c2 only a profile series, as a profile
    /// attached before #2002 did.
    NativeDatabase setupMultiDb({
      String? primary = 'c1',
      bool secondSourceRow = true,
    }) => NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 257');
        rawDb.execute(
          'CREATE TABLE dive_computers (id TEXT NOT NULL PRIMARY KEY)',
        );
        rawDb.execute("INSERT INTO dive_computers (id) VALUES ('c1'), ('c2')");
        rawDb.execute(
          'CREATE TABLE dive_data_sources (id TEXT NOT NULL PRIMARY KEY, '
          'dive_id TEXT NOT NULL, computer_id TEXT, '
          'is_primary INTEGER NOT NULL DEFAULT 0)',
        );
        rawDb.execute(
          'CREATE TABLE dive_profile_series (id TEXT NOT NULL PRIMARY KEY, '
          'dive_id TEXT NOT NULL, computer_id TEXT, '
          'is_primary INTEGER NOT NULL DEFAULT 1)',
        );
        rawDb.execute(
          'INSERT INTO dive_data_sources (id, dive_id, computer_id, '
          'is_primary) VALUES '
          "('src1', 'd1', 'c1', ${primary == 'c1' ? 1 : 0}), "
          "('src3', 'd2', 'c1', 1)",
        );
        if (primary == 'file') {
          rawDb.execute(
            'INSERT INTO dive_data_sources (id, dive_id, computer_id, '
            "is_primary) VALUES ('src0', 'd1', NULL, 1)",
          );
        }
        if (secondSourceRow) {
          rawDb.execute(
            'INSERT INTO dive_data_sources (id, dive_id, computer_id, '
            'is_primary) VALUES '
            "('src2', 'd1', 'c2', ${primary == 'c2' ? 1 : 0})",
          );
        }
        rawDb.execute(
          'INSERT INTO dive_profile_series (id, dive_id, computer_id, '
          "is_primary) VALUES ('p2', 'd1', 'c2', 0)",
        );
        rawDb.execute(
          'CREATE TABLE dive_tanks (id TEXT NOT NULL PRIMARY KEY, '
          'dive_id TEXT NOT NULL, computer_id TEXT)',
        );
        rawDb.execute(
          'CREATE TABLE gas_switches (id TEXT NOT NULL PRIMARY KEY, '
          'dive_id TEXT NOT NULL, timestamp INTEGER NOT NULL, '
          'tank_id TEXT NOT NULL, depth REAL, created_at INTEGER NOT NULL, '
          'hlc TEXT)',
        );
        rawDb.execute(
          "INSERT INTO dive_tanks (id, dive_id, computer_id) VALUES "
          "('t1', 'd1', 'c1'), ('t2', 'd1', 'c2'), ('t3', 'd2', 'c1')",
        );
        rawDb.execute(
          'INSERT INTO gas_switches '
          '(id, dive_id, timestamp, tank_id, created_at) VALUES '
          "('s1', 'd1', 600, 't1', 1), ('s2', 'd1', 640, 't1', 1), "
          "('s3', 'd1', 900, 't2', 1), ('s4', 'd2', 600, 't3', 1)",
        );
      },
    );

    test('leaves a switch to the primary\'s cylinder unattributed: a '
        'consolidation may have merged another computer\'s into it', () async {
      final db = AppDatabase(setupMultiDb());
      addTearDown(db.close);
      // s1 and s2 could be either computer's, so they keep applying to
      // both; s3 is on c2's own cylinder; d2 is c1's alone.
      expect(await switchComputers(db), [null, null, 'c2', 'c1']);
    });

    test('counts a computer that left only a profile series', () async {
      final db = AppDatabase(setupMultiDb(secondSourceRow: false));
      addTearDown(db.close);
      expect(await switchComputers(db), [null, null, 'c2', 'c1']);
    });

    test('attributes every computer\'s own cylinder under a file-imported '
        'primary: its cylinders, which name no computer, were the merge '
        'targets', () async {
      // The issue's own case: a MacDive primary with two computers folded
      // in. t1 and t2 are c1's and c2's own cylinders here.
      final db = AppDatabase(setupMultiDb(primary: 'file'));
      addTearDown(db.close);
      expect(await switchComputers(db), ['c1', 'c1', 'c2', 'c1']);
    });

    test('attributes nothing on it when no source is primary', () async {
      final db = AppDatabase(setupMultiDb(primary: null));
      addTearDown(db.close);
      expect(await switchComputers(db), [null, null, null, 'c1']);
    });
  });
}
