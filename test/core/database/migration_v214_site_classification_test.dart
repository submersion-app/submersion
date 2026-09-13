import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/site_classification_uniqueness.dart';
import 'package:submersion/core/database/site_type_seed.dart';

void main() {
  /// A pre-v214 database: `tags` without the scope flags, no site tables.
  NativeDatabase setupDb({int userVersion = 213}) {
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = $userVersion');
        rawDb.execute('CREATE TABLE divers (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dive_sites (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dives (id TEXT PRIMARY KEY)');
        rawDb.execute('''
          CREATE TABLE tags (
            id TEXT NOT NULL PRIMARY KEY,
            diver_id TEXT,
            name TEXT NOT NULL,
            color TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            hlc TEXT
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
          "INSERT INTO tags (id, name, created_at, updated_at) "
          "VALUES ('t1', 'Night', 0, 0)",
        );
      },
    );
  }

  Future<Set<String>> columnsOf(AppDatabase db, String table) async {
    final cols = await db.customSelect("PRAGMA table_info('$table')").get();
    return cols.map((c) => c.read<String>('name')).toSet();
  }

  Future<Set<String>> indexNames(AppDatabase db) async {
    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
        .get();
    return rows.map((r) => r.read<String>('name')).toSet();
  }

  test('v214 is the current schema version and is in the ladder', () {
    // This is the newest rung, so it owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 214);
    expect(AppDatabase.migrationVersions, contains(214));
    // Additive rung: the sync compatibility floor must not move.
    expect(AppDatabase.minimumCompatibleSchemaVersion, 210);
  });

  test('creates the three site classification tables', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    expect(
      await columnsOf(db, 'site_types'),
      containsAll(<String>[
        'id',
        'diver_id',
        'name',
        'is_built_in',
        'sort_order',
        'created_at',
        'updated_at',
        'hlc',
      ]),
    );
    expect(
      await columnsOf(db, 'site_site_types'),
      containsAll(<String>[
        'id',
        'site_id',
        'site_type_id',
        'created_at',
        'hlc',
      ]),
    );
    expect(
      await columnsOf(db, 'site_tags'),
      containsAll(<String>['id', 'site_id', 'tag_id', 'created_at', 'hlc']),
    );
  });

  test('existing tags become dives-only', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    final row = await db
        .customSelect(
          "SELECT applies_to_dives, applies_to_sites FROM tags WHERE id = 't1'",
        )
        .getSingle();
    expect(row.read<int>('applies_to_dives'), 1);
    expect(row.read<int>('applies_to_sites'), 0);
  });

  test('seeds every built-in site type with its stable slug', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    final rows = await db
        .customSelect(
          'SELECT id, is_built_in FROM site_types ORDER BY sort_order',
        )
        .get();
    expect(
      rows.map((r) => r.read<String>('id')).toList(),
      kBuiltInSiteTypes.map((t) => t.id).toList(),
    );
    expect(rows.every((r) => r.read<int>('is_built_in') == 1), isTrue);
  });

  test('creates both junction unique indexes', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    expect(
      await indexNames(db),
      containsAll(<String>[
        kSiteSiteTypesUniqueIndexName,
        kSiteTagsUniqueIndexName,
      ]),
    );
  });

  test('a fresh database matches the upgraded one', () async {
    final fresh = AppDatabase(NativeDatabase.memory());
    addTearDown(fresh.close);

    final rows = await fresh
        .customSelect('SELECT COUNT(*) AS n FROM site_types')
        .getSingle();
    expect(rows.read<int>('n'), kBuiltInSiteTypes.length);
    expect(
      await indexNames(fresh),
      containsAll(<String>[
        kSiteSiteTypesUniqueIndexName,
        kSiteTagsUniqueIndexName,
      ]),
    );
    expect(
      await columnsOf(fresh, 'tags'),
      containsAll(<String>['applies_to_dives', 'applies_to_sites']),
    );
  });

  test('a duplicate junction pair is rejected by the index', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customStatement(
      "INSERT INTO dive_sites (id, name, created_at, updated_at) "
      "VALUES ('s1', 'Site', 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO site_site_types (id, site_id, site_type_id, created_at) "
      "VALUES ('a', 's1', 'wreck', 0)",
    );

    await expectLater(
      db.customStatement(
        "INSERT INTO site_site_types (id, site_id, site_type_id, created_at) "
        "VALUES ('b', 's1', 'wreck', 0)",
      ),
      throwsA(anything),
    );
  });
}
