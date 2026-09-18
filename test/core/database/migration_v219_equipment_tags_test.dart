import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/tag_uniqueness.dart';

/// Schema v219: equipment tags (issue #1942).
void main() {
  /// A v218 database: `tags` with the dive and site scope flags but no
  /// equipment scope, and no `equipment_tags`.
  NativeDatabase setupDb({int userVersion = 218, bool withEquipment = true}) {
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = $userVersion');
        rawDb.execute('CREATE TABLE divers (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dive_sites (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dives (id TEXT PRIMARY KEY)');
        if (withEquipment) {
          rawDb.execute(
            'CREATE TABLE equipment (id TEXT NOT NULL PRIMARY KEY)',
          );
        }
        rawDb.execute('''
          CREATE TABLE tags (
            id TEXT NOT NULL PRIMARY KEY,
            diver_id TEXT,
            name TEXT NOT NULL,
            color TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            hlc TEXT,
            applies_to_dives INTEGER NOT NULL DEFAULT 1
              CHECK (applies_to_dives IN (0, 1)),
            applies_to_sites INTEGER NOT NULL DEFAULT 0
              CHECK (applies_to_sites IN (0, 1))
          )
        ''');
        rawDb.execute('''
          CREATE TABLE dive_tags (
            id TEXT NOT NULL PRIMARY KEY,
            dive_id TEXT NOT NULL,
            tag_id TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            hlc TEXT
          )
        ''');
        rawDb.execute(
          "INSERT INTO tags (id, name, created_at, updated_at, "
          "applies_to_dives, applies_to_sites) "
          "VALUES ('t1', 'Night', 0, 0, 1, 1)",
        );
      },
    );
  }

  Future<Set<String>> columnsOf(AppDatabase db, String table) async {
    final cols = await db.customSelect("PRAGMA table_info('$table')").get();
    return cols.map((c) => c.read<String>('name')).toSet();
  }

  /// Column shape as SQLite reports it, for comparing two databases.
  Future<List<Map<String, Object?>>> tableInfo(
    AppDatabase db,
    String table,
  ) async {
    final cols = await db.customSelect("PRAGMA table_info('$table')").get();
    return [
      for (final c in cols)
        {
          'name': c.data['name'],
          'type': c.data['type'],
          'notnull': c.data['notnull'],
          'dflt_value': c.data['dflt_value'],
          'pk': c.data['pk'],
        },
    ];
  }

  Future<String?> ddlOf(AppDatabase db, String type, String name) async {
    final rows = await db
        .customSelect(
          'SELECT sql FROM sqlite_master WHERE type = ? AND name = ?',
          variables: [Variable<String>(type), Variable<String>(name)],
        )
        .get();
    return rows.isEmpty ? null : rows.single.read<String?>('sql');
  }

  test('v219 is in the ladder', () {
    // The newest rung owns the exact currentSchemaVersion/step-count
    // assertions; relaxed here once v220 (issue #1020) landed on top.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(219));
    expect(AppDatabase.migrationVersions, contains(219));
    expect(AppDatabase.migrationStepCount(218), greaterThanOrEqualTo(1));
    // Additive rung: the sync compatibility floor must not move.
    expect(AppDatabase.minimumCompatibleSchemaVersion, 210);
  });

  test('adds the equipment_tags junction', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    expect(
      await columnsOf(db, 'equipment_tags'),
      containsAll(<String>[
        'id',
        'equipment_id',
        'tag_id',
        'created_at',
        'hlc',
      ]),
    );
  });

  test('existing tags keep their scopes and gain no equipment scope', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    final row = await db
        .customSelect(
          'SELECT applies_to_dives, applies_to_sites, applies_to_equipment '
          "FROM tags WHERE id = 't1'",
        )
        .getSingle();
    expect(row.read<int>('applies_to_dives'), 1);
    expect(row.read<int>('applies_to_sites'), 1);
    expect(row.read<int>('applies_to_equipment'), 0);
  });

  test('creates the equipment_tags unique index', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    expect(await ddlOf(db, 'index', kEquipmentTagsUniqueIndexName), isNotNull);
  });

  test('a fresh database matches the upgraded one', () async {
    final upgraded = AppDatabase(setupDb());
    addTearDown(upgraded.close);
    final fresh = AppDatabase(NativeDatabase.memory());
    addTearDown(fresh.close);

    expect(
      await tableInfo(upgraded, 'equipment_tags'),
      await tableInfo(fresh, 'equipment_tags'),
    );
    expect(
      await ddlOf(upgraded, 'table', 'equipment_tags'),
      await ddlOf(fresh, 'table', 'equipment_tags'),
    );
    expect(
      await ddlOf(upgraded, 'index', kEquipmentTagsUniqueIndexName),
      await ddlOf(fresh, 'index', kEquipmentTagsUniqueIndexName),
    );
    Map<String, Object?> flag(List<Map<String, Object?>> cols) =>
        cols.singleWhere((c) => c['name'] == 'applies_to_equipment');
    expect(
      flag(await tableInfo(upgraded, 'tags')),
      flag(await tableInfo(fresh, 'tags')),
    );
  });

  test(
    'a database stamped v219 without the schema heals in beforeOpen',
    () async {
      // A parallel branch that claimed 219 first carries a device past the
      // rung; the beforeOpen backstop must build what the rung would have.
      final db = AppDatabase(setupDb(userVersion: 219));
      addTearDown(db.close);

      expect(await columnsOf(db, 'tags'), contains('applies_to_equipment'));
      expect(await columnsOf(db, 'equipment_tags'), contains('equipment_id'));
      expect(
        await ddlOf(db, 'index', kEquipmentTagsUniqueIndexName),
        isNotNull,
      );
    },
  );

  test('a fixture without an equipment table skips the junction', () async {
    final db = AppDatabase(setupDb(withEquipment: false));
    addTearDown(db.close);

    expect(await columnsOf(db, 'equipment_tags'), isEmpty);
    expect(await columnsOf(db, 'tags'), contains('applies_to_equipment'));
  });

  test('a duplicate equipment tag pair is rejected by the index', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customStatement(
      "INSERT INTO equipment (id, name, type, created_at, updated_at) "
      "VALUES ('e1', 'Wing', 'bcd', 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO tags (id, name, created_at, updated_at) "
      "VALUES ('t1', 'Rental', 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO equipment_tags (id, equipment_id, tag_id, created_at) "
      "VALUES ('a', 'e1', 't1', 0)",
    );

    await expectLater(
      db.customStatement(
        "INSERT INTO equipment_tags (id, equipment_id, tag_id, created_at) "
        "VALUES ('b', 'e1', 't1', 0)",
      ),
      throwsA(anything),
    );
  });
}
