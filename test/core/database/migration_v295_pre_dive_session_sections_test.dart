import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:sqlite3/sqlite3.dart' show Database;

/// Schema v295: pre_dive_session_sections, replacing the free-text
/// pre_dive_session_items.section column with a section_id reference
/// (issue #3360). The last of the four checklist-sections table groups;
/// no built-in exclusion needed (sessions are always diver-owned
/// instances, never re-seeded). section_id itself has no SQL FK, matching
/// source_item_id's existing style (two rows sync as independent HLC
/// records with no guaranteed order of arrival).
void main() {
  void createBaseSchema(Database rawDb, int userVersion) {
    rawDb.execute('PRAGMA user_version = $userVersion');
    rawDb.execute('''
      CREATE TABLE pre_dive_sessions (
        id TEXT NOT NULL PRIMARY KEY,
        template_name TEXT NOT NULL,
        strict_order INTEGER NOT NULL DEFAULT 0,
        started_at INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'inProgress',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        hlc TEXT
      )
    ''');
    rawDb.execute('''
      CREATE TABLE pre_dive_session_items (
        id TEXT NOT NULL PRIMARY KEY,
        session_id TEXT NOT NULL REFERENCES pre_dive_sessions (id),
        section TEXT,
        title TEXT NOT NULL,
        notes TEXT NOT NULL DEFAULT '',
        sort_order INTEGER NOT NULL DEFAULT 0,
        item_type TEXT NOT NULL DEFAULT 'check',
        value_label TEXT,
        value_unit TEXT,
        value_min REAL,
        value_max REAL,
        is_required INTEGER NOT NULL DEFAULT 0,
        state TEXT NOT NULL DEFAULT 'pending',
        value_number REAL,
        value_text TEXT,
        note TEXT NOT NULL DEFAULT '',
        completed_at INTEGER,
        equipment_id TEXT,
        overdue_services TEXT,
        source_item_id TEXT,
        source_value_number REAL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        hlc TEXT
      )
    ''');
    rawDb.execute(
      "INSERT INTO pre_dive_sessions "
      "(id, template_name, started_at, created_at, updated_at) VALUES "
      "('s1', 'BWRAF', 0, 0, 0), ('s2', 'CCR Build', 0, 0, 0)",
    );
  }

  void insertItem(
    Database rawDb, {
    required String id,
    required String sessionId,
    required String title,
    String? section,
    int sortOrder = 0,
  }) {
    final sectionLiteral = section == null ? 'NULL' : "'$section'";
    rawDb.execute(
      'INSERT INTO pre_dive_session_items '
      '(id, session_id, title, section, sort_order, created_at, updated_at) '
      "VALUES ('$id', '$sessionId', '$title', $sectionLiteral, $sortOrder, 0, 0)",
    );
  }

  NativeDatabase setupDb({
    int userVersion = 294,
    void Function(Database rawDb)? seed,
  }) {
    return NativeDatabase.memory(
      setup: (rawDb) {
        createBaseSchema(rawDb, userVersion);
        seed?.call(rawDb);
      },
    );
  }

  Future<Set<String>> columnsOf(AppDatabase db, String table) async {
    final cols = await db.customSelect("PRAGMA table_info('$table')").get();
    return cols.map((c) => c.read<String>('name')).toSet();
  }

  test('v295 is the current schema version and the floor', () {
    expect(AppDatabase.currentSchemaVersion, 295);
    expect(AppDatabase.migrationVersions, contains(295));
    expect(AppDatabase.minimumCompatibleSchemaVersion, 295);
  });

  test(
    'creates pre_dive_session_sections and section_id, drops section',
    () async {
      final db = AppDatabase(
        setupDb(
          seed: (raw) =>
              insertItem(raw, id: 'i1', sessionId: 's1', title: 'Weights'),
        ),
      );
      addTearDown(db.close);

      expect(
        await columnsOf(db, 'pre_dive_session_sections'),
        containsAll(['id', 'session_id', 'title', 'sort_order', 'hlc']),
      );
      final itemCols = await columnsOf(db, 'pre_dive_session_items');
      expect(itemCols, contains('section_id'));
      expect(itemCols, isNot(contains('section')));
    },
  );

  test('items sharing a section merge, first-seen casing', () async {
    final db = AppDatabase(
      setupDb(
        seed: (raw) {
          insertItem(
            raw,
            id: 'i1',
            sessionId: 's2',
            title: 'Cell 1',
            section: 'Cells',
          );
          insertItem(
            raw,
            id: 'i2',
            sessionId: 's2',
            title: 'Cell 2',
            section: 'cells',
            sortOrder: 1,
          );
        },
      ),
    );
    addTearDown(db.close);

    final sections = await db
        .customSelect(
          "SELECT * FROM pre_dive_session_sections WHERE session_id = 's2'",
        )
        .get();
    expect(sections, hasLength(1));
    expect(sections.single.data['title'], 'Cells');

    final items = await db
        .customSelect(
          "SELECT section_id FROM pre_dive_session_items "
          "WHERE session_id = 's2'",
        )
        .get();
    expect(items.map((r) => r.data['section_id']).toSet(), {
      sections.single.data['id'],
    });
  });

  test(
    'two sessions with the same section text get separate sections',
    () async {
      final db = AppDatabase(
        setupDb(
          seed: (raw) {
            insertItem(
              raw,
              id: 'i1',
              sessionId: 's1',
              title: 'A',
              section: 'Gear',
            );
            insertItem(
              raw,
              id: 'i2',
              sessionId: 's2',
              title: 'B',
              section: 'Gear',
            );
          },
        ),
      );
      addTearDown(db.close);

      final sections = await db
          .customSelect('SELECT * FROM pre_dive_session_sections')
          .get();
      expect(sections, hasLength(2));
      expect(sections.map((r) => r.data['session_id']).toSet(), {'s1', 's2'});
    },
  );

  test('items with no section stay unsectioned', () async {
    final db = AppDatabase(
      setupDb(
        seed: (raw) =>
            insertItem(raw, id: 'i1', sessionId: 's1', title: 'No section'),
      ),
    );
    addTearDown(db.close);

    final item = await db
        .customSelect(
          "SELECT section_id FROM pre_dive_session_items WHERE id = 'i1'",
        )
        .getSingle();
    expect(item.data['section_id'], isNull);
  });

  test('reopening after an interrupted upgrade does not duplicate sections '
      'or lose the item link (deterministic section ids)', () async {
    final dir = Directory.systemTemp.createTempSync(
      'pre_dive_session_sections',
    );
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = p.join(dir.path, 'test.sqlite');

    final first = AppDatabase(
      NativeDatabase(
        File(path),
        setup: (raw) {
          createBaseSchema(raw, 294);
          insertItem(
            raw,
            id: 'i1',
            sessionId: 's1',
            title: 'Weights',
            section: 'Gear',
          );
        },
      ),
    );
    final before = await first
        .customSelect('SELECT * FROM pre_dive_session_sections')
        .get();
    expect(before, hasLength(1));

    await first.customStatement(
      "UPDATE pre_dive_session_items SET section_id = NULL WHERE id = 'i1'",
    );
    await first.close();

    final reopened = AppDatabase(NativeDatabase(File(path)));
    addTearDown(reopened.close);

    final after = await reopened
        .customSelect('SELECT * FROM pre_dive_session_sections')
        .get();
    expect(after, hasLength(1), reason: 'no duplicate section row');
    expect(after.single.data['id'], before.single.data['id']);
  });

  test('a database stamped v295 without the migration ever having run heals '
      'in beforeOpen (parallel-branch version collision)', () async {
    final db = AppDatabase(
      setupDb(
        userVersion: 295,
        seed: (raw) => insertItem(
          raw,
          id: 'i1',
          sessionId: 's1',
          title: 'Weights',
          section: 'Gear',
        ),
      ),
    );
    addTearDown(db.close);

    final itemCols = await columnsOf(db, 'pre_dive_session_items');
    expect(itemCols, contains('section_id'));
    expect(itemCols, isNot(contains('section')));

    final item = await db
        .customSelect(
          "SELECT section_id FROM pre_dive_session_items WHERE id = 'i1'",
        )
        .getSingle();
    expect(item.data['section_id'], isNotNull);
  });

  test('a fixture without sessions skips the table and the column', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) => rawDb.execute('PRAGMA user_version = 294'),
      ),
    );
    addTearDown(db.close);

    expect(await columnsOf(db, 'pre_dive_session_sections'), isEmpty);
  });

  test('a fresh database matches the upgraded one', () async {
    final upgraded = AppDatabase(setupDb());
    addTearDown(upgraded.close);
    final fresh = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(fresh.close);

    expect(
      await columnsOf(upgraded, 'pre_dive_session_sections'),
      await columnsOf(fresh, 'pre_dive_session_sections'),
    );
    expect(
      await columnsOf(upgraded, 'pre_dive_session_items'),
      await columnsOf(fresh, 'pre_dive_session_items'),
    );
  });
}
