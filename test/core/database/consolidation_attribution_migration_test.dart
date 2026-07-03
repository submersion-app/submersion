import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.customStatement('PRAGMA foreign_keys = ON');
  });

  tearDown(() async => db.close());

  Future<Set<String>> columnsOf(String table) async {
    final rows = await db.customSelect("PRAGMA table_info('$table')").get();
    return rows.map((r) => r.read<String>('name')).toSet();
  }

  test('v97 adds computer_id to the three attribution tables', () async {
    expect(await columnsOf('dive_tanks'), contains('computer_id'));
    expect(await columnsOf('tank_pressure_profiles'), contains('computer_id'));
    expect(await columnsOf('dive_profile_events'), contains('computer_id'));
  });

  test('v97 is in the migration ladder', () {
    // v97 was the latest when written; issue #164's checklist migration
    // superseded it at v98, so this is a ladder-membership check, not an
    // exact-latest assertion (matches the superseded-tripwire convention of
    // the earlier migration_v9x tests).
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(97));
    expect(AppDatabase.migrationVersions, contains(97));
  });

  test('deleting a computer nulls attribution instead of cascading', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: 'comp-1',
            name: 'Perdix',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'dive-1',
            diveDateTime: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 'tank-1',
            diveId: 'dive-1',
            computerId: const Value('comp-1'),
          ),
        );
    await (db.delete(
      db.diveComputers,
    )..where((t) => t.id.equals('comp-1'))).go();
    final tank = await (db.select(
      db.diveTanks,
    )..where((t) => t.id.equals('tank-1'))).getSingle();
    expect(tank.computerId, isNull);
  });

  test(
    'v96 -> v97 upgrade adds computer_id to the three attribution tables',
    () async {
      // Hand-built pre-v97 shapes (no computer_id column), matching the
      // columns those tables had before the multi-computer consolidation
      // migration. Exercises the actual onUpgrade ALTER TABLE loop, unlike
      // the onCreate-only tests above.
      final nativeDb = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 96');
          rawDb.execute('''
            CREATE TABLE dive_tanks (
              id TEXT NOT NULL PRIMARY KEY,
              dive_id TEXT NOT NULL,
              o2_percent REAL NOT NULL DEFAULT 21.0,
              he_percent REAL NOT NULL DEFAULT 0.0,
              tank_order INTEGER NOT NULL DEFAULT 0,
              tank_role TEXT NOT NULL DEFAULT 'backGas'
            )
          ''');
          rawDb.execute(
            "INSERT INTO dive_tanks (id, dive_id) VALUES ('tank-1', 'dive-1')",
          );
          rawDb.execute('''
            CREATE TABLE tank_pressure_profiles (
              id TEXT NOT NULL PRIMARY KEY,
              dive_id TEXT NOT NULL,
              tank_id TEXT NOT NULL,
              timestamp INTEGER NOT NULL,
              pressure REAL NOT NULL
            )
          ''');
          rawDb.execute(
            "INSERT INTO tank_pressure_profiles "
            "(id, dive_id, tank_id, timestamp, pressure) "
            "VALUES ('tpp-1', 'dive-1', 'tank-1', 0, 200.0)",
          );
          rawDb.execute('''
            CREATE TABLE dive_profile_events (
              id TEXT NOT NULL PRIMARY KEY,
              dive_id TEXT NOT NULL,
              timestamp INTEGER NOT NULL,
              event_type TEXT NOT NULL,
              severity TEXT NOT NULL DEFAULT 'info',
              source TEXT NOT NULL DEFAULT 'imported',
              created_at INTEGER NOT NULL
            )
          ''');
          rawDb.execute(
            "INSERT INTO dive_profile_events "
            "(id, dive_id, timestamp, event_type, created_at) "
            "VALUES ('evt-1', 'dive-1', 0, 'ascentRate', 1)",
          );
        },
      );

      final upgradedDb = AppDatabase(nativeDb);
      addTearDown(() => upgradedDb.close());

      Future<Set<String>> upgradedColumnsOf(String table) async {
        final rows = await upgradedDb
            .customSelect("PRAGMA table_info('$table')")
            .get();
        return rows.map((r) => r.read<String>('name')).toSet();
      }

      expect(await upgradedColumnsOf('dive_tanks'), contains('computer_id'));
      expect(
        await upgradedColumnsOf('tank_pressure_profiles'),
        contains('computer_id'),
      );
      expect(
        await upgradedColumnsOf('dive_profile_events'),
        contains('computer_id'),
      );

      // Pre-existing rows get NULL (= primary source / manual entry), not
      // some other default.
      final tankRow = await upgradedDb
          .customSelect(
            "SELECT computer_id FROM dive_tanks WHERE id = 'tank-1'",
          )
          .getSingle();
      expect(tankRow.data['computer_id'], isNull);
    },
  );

  test('v97 migration is idempotent when computer_id already exists', () async {
    // Exercises the PRAGMA guard branch: a database where the v97 columns
    // are already present (e.g. an interrupted upgrade) must not fail on a
    // duplicate ALTER, and must not clobber existing values.
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 96');
        rawDb.execute('''
            CREATE TABLE dive_tanks (
              id TEXT NOT NULL PRIMARY KEY,
              dive_id TEXT NOT NULL,
              o2_percent REAL NOT NULL DEFAULT 21.0,
              he_percent REAL NOT NULL DEFAULT 0.0,
              tank_order INTEGER NOT NULL DEFAULT 0,
              tank_role TEXT NOT NULL DEFAULT 'backGas',
              computer_id TEXT
            )
          ''');
        rawDb.execute(
          "INSERT INTO dive_tanks (id, dive_id, computer_id) "
          "VALUES ('tank-1', 'dive-1', 'comp-1')",
        );
        rawDb.execute('''
            CREATE TABLE tank_pressure_profiles (
              id TEXT NOT NULL PRIMARY KEY,
              dive_id TEXT NOT NULL,
              tank_id TEXT NOT NULL,
              timestamp INTEGER NOT NULL,
              pressure REAL NOT NULL,
              computer_id TEXT
            )
          ''');
        rawDb.execute('''
            CREATE TABLE dive_profile_events (
              id TEXT NOT NULL PRIMARY KEY,
              dive_id TEXT NOT NULL,
              timestamp INTEGER NOT NULL,
              event_type TEXT NOT NULL,
              severity TEXT NOT NULL DEFAULT 'info',
              source TEXT NOT NULL DEFAULT 'imported',
              created_at INTEGER NOT NULL,
              computer_id TEXT
            )
          ''');
      },
    );

    final upgradedDb = AppDatabase(nativeDb);
    addTearDown(() => upgradedDb.close());

    final cols = await upgradedDb
        .customSelect("PRAGMA table_info('dive_tanks')")
        .get();
    final names = cols.map((c) => c.read<String>('name')).toList();

    // Column present exactly once (no duplicate ALTER).
    expect(names.where((n) => n == 'computer_id').length, 1);

    // The pre-existing value is preserved, not reset to NULL.
    final row = await upgradedDb
        .customSelect("SELECT computer_id FROM dive_tanks WHERE id = 'tank-1'")
        .getSingle();
    expect(row.data['computer_id'], 'comp-1');
  });
}
