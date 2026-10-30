import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:sqlite3/sqlite3.dart' show Database;

/// Schema v298: checklist_template_sections, replacing the free-text
/// checklist_template_items.category column with a section_id reference
/// (issue #3360). Same shape as v297's trip_checklist_sections rung; see
/// that migration test for the full crash/collision-resilience rationale,
/// not repeated here in full.
void main() {
  void createBaseSchema(Database rawDb, int userVersion) {
    rawDb.execute('PRAGMA user_version = $userVersion');
    rawDb.execute('''
      CREATE TABLE checklist_templates (
        id TEXT NOT NULL PRIMARY KEY,
        diver_id TEXT,
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        hlc TEXT
      )
    ''');
    rawDb.execute('''
      CREATE TABLE checklist_template_items (
        id TEXT NOT NULL PRIMARY KEY,
        template_id TEXT NOT NULL REFERENCES checklist_templates (id),
        title TEXT NOT NULL,
        category TEXT,
        notes TEXT NOT NULL DEFAULT '',
        due_offset_days INTEGER,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        hlc TEXT
      )
    ''');
    rawDb.execute(
      "INSERT INTO checklist_templates (id, name, created_at, updated_at) "
      "VALUES ('tpl1', 'Prep', 0, 0), ('tpl2', 'CCR Build', 0, 0)",
    );
  }

  void insertItem(
    Database rawDb, {
    required String id,
    required String templateId,
    required String title,
    String? category,
    int sortOrder = 0,
  }) {
    final categoryLiteral = category == null ? 'NULL' : "'$category'";
    rawDb.execute(
      'INSERT INTO checklist_template_items '
      '(id, template_id, title, category, sort_order, created_at, updated_at) '
      "VALUES ('$id', '$templateId', '$title', $categoryLiteral, $sortOrder, 0, 0)",
    );
  }

  NativeDatabase setupDb({
    int userVersion = 297,
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

  test('v298 is at or below the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(298));
    expect(AppDatabase.migrationVersions, contains(298));
    expect(
      AppDatabase.minimumCompatibleSchemaVersion,
      greaterThanOrEqualTo(298),
    );
  });

  test(
    'creates checklist_template_sections and section_id, drops category',
    () async {
      final db = AppDatabase(
        setupDb(
          seed: (raw) => insertItem(
            raw,
            id: 'i1',
            templateId: 'tpl1',
            title: 'Book flights',
          ),
        ),
      );
      addTearDown(db.close);

      expect(
        await columnsOf(db, 'checklist_template_sections'),
        containsAll(['id', 'template_id', 'title', 'sort_order', 'hlc']),
      );
      final itemCols = await columnsOf(db, 'checklist_template_items');
      expect(itemCols, contains('section_id'));
      expect(itemCols, isNot(contains('category')));
    },
  );

  test(
    'items sharing a category merge into one section, first-seen casing',
    () async {
      final db = AppDatabase(
        setupDb(
          seed: (raw) {
            insertItem(
              raw,
              id: 'i1',
              templateId: 'tpl2',
              title: 'Cell 1',
              category: 'Cells',
            );
            insertItem(
              raw,
              id: 'i2',
              templateId: 'tpl2',
              title: 'Cell 2',
              category: 'cells',
              sortOrder: 1,
            );
          },
        ),
      );
      addTearDown(db.close);

      final sections = await db
          .customSelect(
            "SELECT * FROM checklist_template_sections "
            "WHERE template_id = 'tpl2'",
          )
          .get();
      expect(sections, hasLength(1));
      expect(sections.single.data['title'], 'Cells');

      final items = await db
          .customSelect(
            "SELECT section_id FROM checklist_template_items "
            "WHERE template_id = 'tpl2'",
          )
          .get();
      expect(items.map((r) => r.data['section_id']).toSet(), {
        sections.single.data['id'],
      });
    },
  );

  test('items with no category stay unsectioned', () async {
    final db = AppDatabase(
      setupDb(
        seed: (raw) =>
            insertItem(raw, id: 'i1', templateId: 'tpl1', title: 'No section'),
      ),
    );
    addTearDown(db.close);

    final item = await db
        .customSelect(
          "SELECT section_id FROM checklist_template_items WHERE id = 'i1'",
        )
        .getSingle();
    expect(item.data['section_id'], isNull);
  });

  test(
    'two templates with the same category text get separate sections',
    () async {
      final db = AppDatabase(
        setupDb(
          seed: (raw) {
            insertItem(
              raw,
              id: 'i1',
              templateId: 'tpl1',
              title: 'A',
              category: 'Gear',
            );
            insertItem(
              raw,
              id: 'i2',
              templateId: 'tpl2',
              title: 'B',
              category: 'Gear',
            );
          },
        ),
      );
      addTearDown(db.close);

      final sections = await db
          .customSelect('SELECT * FROM checklist_template_sections')
          .get();
      expect(sections, hasLength(2));
      expect(sections.map((r) => r.data['template_id']).toSet(), {
        'tpl1',
        'tpl2',
      });
    },
  );

  test('reopening after an interrupted upgrade does not duplicate sections '
      'or lose the item link (deterministic section ids)', () async {
    final dir = Directory.systemTemp.createTempSync(
      'checklist_template_sections',
    );
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = p.join(dir.path, 'test.sqlite');

    final first = AppDatabase(
      NativeDatabase(
        File(path),
        setup: (raw) {
          createBaseSchema(raw, 297);
          insertItem(
            raw,
            id: 'i1',
            templateId: 'tpl2',
            title: 'Cell 1',
            category: 'Cells',
          );
        },
      ),
    );
    final before = await first
        .customSelect('SELECT * FROM checklist_template_sections')
        .get();
    expect(before, hasLength(1));
    final sectionId = before.single.data['id'];
    await first.close();

    // The real risk this guards against: category is gone by now (dropped
    // in the same upgrade that created the section), so a second open has
    // nothing left to backfill from and must leave the existing section and
    // link alone rather than duplicate or lose either.
    final reopened = AppDatabase(NativeDatabase(File(path)));
    addTearDown(reopened.close);

    final after = await reopened
        .customSelect('SELECT * FROM checklist_template_sections')
        .get();
    expect(after, hasLength(1), reason: 'no duplicate section row');
    expect(after.single.data['id'], sectionId);

    final item = await reopened
        .customSelect(
          "SELECT section_id FROM checklist_template_items WHERE id = 'i1'",
        )
        .getSingle();
    expect(item.data['section_id'], sectionId);
  });

  test('a database stamped v298 without the migration ever having run heals '
      'in beforeOpen (parallel-branch version collision)', () async {
    final db = AppDatabase(
      setupDb(
        userVersion: 298,
        seed: (raw) => insertItem(
          raw,
          id: 'i1',
          templateId: 'tpl2',
          title: 'Cell 1',
          category: 'Cells',
        ),
      ),
    );
    addTearDown(db.close);

    expect(
      await columnsOf(db, 'checklist_template_sections'),
      contains('template_id'),
    );
    final itemCols = await columnsOf(db, 'checklist_template_items');
    expect(itemCols, contains('section_id'));
    expect(itemCols, isNot(contains('category')));

    final item = await db
        .customSelect(
          "SELECT section_id FROM checklist_template_items WHERE id = 'i1'",
        )
        .getSingle();
    expect(item.data['section_id'], isNotNull);
  });

  test('a fixture without templates skips the table and the column', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) => rawDb.execute('PRAGMA user_version = 297'),
      ),
    );
    addTearDown(db.close);

    expect(await columnsOf(db, 'checklist_template_sections'), isEmpty);
  });

  test('a fresh database matches the upgraded one', () async {
    final upgraded = AppDatabase(setupDb());
    addTearDown(upgraded.close);
    final fresh = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(fresh.close);

    expect(
      await columnsOf(upgraded, 'checklist_template_sections'),
      await columnsOf(fresh, 'checklist_template_sections'),
    );
    expect(
      await columnsOf(upgraded, 'checklist_template_items'),
      await columnsOf(fresh, 'checklist_template_items'),
    );
  });
}
