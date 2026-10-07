import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/dive_role_link_uniqueness.dart';

/// The role junctions (v272, issue #1221).
void main() {
  /// A v271 database: the parents exist, the two junctions do not.
  NativeDatabase setupDb() => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 271');
      rawDb.execute('CREATE TABLE divers (id TEXT PRIMARY KEY)');
      rawDb.execute('CREATE TABLE dives (id TEXT PRIMARY KEY)');
      rawDb.execute('CREATE TABLE buddies (id TEXT PRIMARY KEY)');
      rawDb.execute("INSERT INTO dives (id) VALUES ('d1')");
      rawDb.execute("INSERT INTO buddies (id) VALUES ('b1')");
    },
  );

  Future<Set<String>> columnsOf(AppDatabase db, String table) async {
    final cols = await db.customSelect("PRAGMA table_info('$table')").get();
    return cols.map((c) => c.read<String>('name')).toSet();
  }

  test('v272 is at or below the current schema version and in the ladder', () {
    // Relaxed once v273 (TDI's own structure, #3072) landed on top; the
    // newest rung owns the exact assertion.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(272));
    expect(AppDatabase.migrationVersions, contains(272));
    expect(AppDatabase.migrationStepCount(271), greaterThanOrEqualTo(1));
    expect(AppDatabase.minimumCompatibleSchemaVersion, 240);
  });

  test('creates both junctions with their columns', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    expect(await columnsOf(db, 'dive_diver_roles'), {
      'id',
      'dive_id',
      'role_id',
      'created_at',
      'hlc',
    });
    expect(await columnsOf(db, 'dive_buddy_roles'), {
      'id',
      'dive_id',
      'buddy_id',
      'role_id',
      'created_at',
      'hlc',
    });
  });

  test('the natural keys are unique', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    await db.customStatement(
      'INSERT INTO dive_diver_roles (id, dive_id, role_id, created_at) '
      "VALUES ('r1', 'd1', 'diveMaster', 0)",
    );
    await expectLater(
      db.customStatement(
        'INSERT INTO dive_diver_roles (id, dive_id, role_id, created_at) '
        "VALUES ('r2', 'd1', 'diveMaster', 0)",
      ),
      throwsA(anything),
    );
    await db.customStatement(
      'INSERT INTO dive_buddy_roles '
      '(id, dive_id, buddy_id, role_id, created_at) '
      "VALUES ('x1', 'd1', 'b1', 'diveGuide', 0)",
    );
    await expectLater(
      db.customStatement(
        'INSERT INTO dive_buddy_roles '
        '(id, dive_id, buddy_id, role_id, created_at) '
        "VALUES ('x2', 'd1', 'b1', 'diveGuide', 0)",
      ),
      throwsA(anything),
    );
  });

  test('the uniqueness assert is idempotent', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    await assertDiveRoleLinkUniqueness(db);
    await assertDiveRoleLinkUniqueness(db);
    final rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' AND name IN "
          "('$kDiveDiverRolesUniqueIndexName', "
          "'$kDiveBuddyRolesUniqueIndexName')",
        )
        .get();
    expect(rows, hasLength(2));
  });
}
