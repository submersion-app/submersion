import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

// Minimal v112-shape fixture: only the tables the v119 migration and its
// beforeOpen backstop touch. Other backstops self-guard when their tables
// are absent.
NativeDatabase _v112Db({int? userVersion}) {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = ${userVersion ?? 112}');
      rawDb.execute('''CREATE TABLE divers (id TEXT PRIMARY KEY NOT NULL,
          name TEXT NOT NULL, created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL)''');
      rawDb.execute('''CREATE TABLE equipment (id TEXT PRIMARY KEY NOT NULL,
          diver_id TEXT, name TEXT NOT NULL, type TEXT NOT NULL,
          buoyancy_kg REAL, weight_kg REAL, thickness TEXT,
          created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
          hlc TEXT)''');
      rawDb.execute(
        "INSERT INTO equipment (id, name, type, created_at, updated_at) "
        "VALUES ('e1', 'Wing', 'bcd', 1000, 1000)",
      );
    },
  );
}

Future<Set<String>> _columns(AppDatabase db, String table) async {
  final rows = await db.customSelect("PRAGMA table_info('$table')").get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

void main() {
  test('fresh database has the equipment.lift_capacity_kg column', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(await _columns(db, 'equipment'), contains('lift_capacity_kg'));
  });

  test('real onUpgrade from v112 adds the column, preserving rows', () async {
    final db = AppDatabase(_v112Db());
    addTearDown(db.close);
    expect(await _columns(db, 'equipment'), contains('lift_capacity_kg'));
    final rows = await db.customSelect('SELECT id FROM equipment').get();
    expect(rows.single.read<String>('id'), 'e1');
  });

  test('beforeOpen backstop heals a DB at currentSchemaVersion missing '
      'lift_capacity_kg', () async {
    final db = AppDatabase(
      _v112Db(userVersion: AppDatabase.currentSchemaVersion),
    );
    addTearDown(db.close);
    expect(await _columns(db, 'equipment'), contains('lift_capacity_kg'));
  });

  test('version ladder includes 119', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(119));
    expect(AppDatabase.migrationVersions, contains(119));
  });
}
