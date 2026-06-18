import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  test('fresh install includes cavern as a built-in dive type', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final rows = await db
        .customSelect('SELECT id, name, is_built_in FROM dive_types')
        .get();
    final ids = rows.map((r) => r.read<String>('id')).toSet();

    expect(ids, contains('cavern'));

    final cavern = rows.firstWhere((r) => r.read<String>('id') == 'cavern');
    expect(cavern.read<String>('name'), 'Cavern');
    expect(cavern.read<int>('is_built_in'), 1);
  });

  test('v87 -> v88 upgrade adds cavern to existing databases', () async {
    final native = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 87');
        rawDb.execute('''
            CREATE TABLE dive_types (
              id TEXT NOT NULL PRIMARY KEY,
              name TEXT NOT NULL,
              is_built_in INTEGER NOT NULL DEFAULT 0,
              sort_order INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
      },
    );
    final db = AppDatabase(native);
    addTearDown(db.close);

    final rows = await db
        .customSelect('SELECT id, name, is_built_in FROM dive_types')
        .get();
    final ids = rows.map((r) => r.read<String>('id')).toSet();

    expect(ids, contains('cavern'));
    final cavern = rows.firstWhere((r) => r.read<String>('id') == 'cavern');
    expect(cavern.read<String>('name'), 'Cavern');
    expect(cavern.read<int>('is_built_in'), 1);
  });

  test(
    'v87 -> v88 upgrade does not fail when user-created cavern type already exists',
    () async {
      final native = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 87');
          rawDb.execute('''
            CREATE TABLE dive_types (
              id TEXT NOT NULL PRIMARY KEY,
              name TEXT NOT NULL,
              is_built_in INTEGER NOT NULL DEFAULT 0,
              sort_order INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          rawDb.execute('''
            INSERT INTO dive_types (id, name, is_built_in, sort_order, created_at, updated_at)
            VALUES ('cavern', 'My Cavern', 0, 99, 0, 0)
          ''');
        },
      );
      final db = AppDatabase(native);
      addTearDown(db.close);

      final rows = await db
          .customSelect(
            'SELECT id, name, is_built_in FROM dive_types WHERE id = ?',
            variables: [const Variable('cavern')],
          )
          .get();

      expect(rows.length, 1);
      // INSERT OR IGNORE preserves the existing user row
      expect(rows.first.read<String>('name'), 'My Cavern');
      expect(rows.first.read<int>('is_built_in'), 0);
    },
  );
}
