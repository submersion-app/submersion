import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  /// A pre-v208 database: `dive_data_sources` without the reference, and no
  /// `imported_files` table at all.
  NativeDatabase setupDb({int userVersion = 207}) {
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = $userVersion');
        rawDb.execute('CREATE TABLE dives (id TEXT PRIMARY KEY)');
        rawDb.execute('''
          CREATE TABLE dive_data_sources (
            id TEXT NOT NULL PRIMARY KEY,
            dive_id TEXT NOT NULL,
            is_primary INTEGER NOT NULL DEFAULT 0,
            imported_at INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            source_file_name TEXT,
            source_file_format TEXT
          )
        ''');
      },
    );
  }

  Future<Set<String>> columnsOf(AppDatabase db, String table) async {
    final cols = await db.customSelect("PRAGMA table_info('$table')").get();
    return cols.map((c) => c.read<String>('name')).toSet();
  }

  test('v208 is the current schema version and is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, 208);
    expect(AppDatabase.migrationVersions, contains(208));
  });

  test('creates imported_files as a synced blob table', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    expect(
      await columnsOf(db, 'imported_files'),
      containsAll(<String>[
        'id',
        'bytes',
        'file_name',
        'byte_count',
        'created_at',
        'updated_at',
        'hlc',
      ]),
    );
  });

  test('adds imported_file_id to dive_data_sources', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    expect(
      await columnsOf(db, 'dive_data_sources'),
      contains('imported_file_id'),
    );
  });

  test('pre-existing rows read the new column back as null', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    await db.customStatement("INSERT INTO dives (id) VALUES ('d1')");
    await db.customStatement(
      "INSERT INTO dive_data_sources "
      "(id, dive_id, is_primary, imported_at, created_at, source_file_name, source_file_format) "
      "VALUES ('s1', 'd1', 1, 0, 0, 'dive.uddf', 'uddf')",
    );
    final row = await db
        .customSelect(
          "SELECT imported_file_id FROM dive_data_sources WHERE id = 's1'",
        )
        .getSingle();
    expect(row.readNullable<String>('imported_file_id'), isNull);
  });

  test(
    'the beforeOpen backstop heals a database already stamped 208',
    () async {
      // A device that reached 208 through a parallel branch never enters the
      // `from < 208` rung, so the table and the reference have to be asserted
      // on every open as well.
      final db = AppDatabase(setupDb(userVersion: 208));
      addTearDown(db.close);

      expect(await columnsOf(db, 'imported_files'), contains('bytes'));
      expect(
        await columnsOf(db, 'dive_data_sources'),
        contains('imported_file_id'),
      );
    },
  );

  test('the reference column is indexed for the orphan sweep', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    final indexes = await db
        .customSelect("PRAGMA index_list('dive_data_sources')")
        .get();
    expect(
      indexes.map((r) => r.read<String>('name')),
      contains('idx_dive_data_sources_imported_file'),
    );
  });
}
