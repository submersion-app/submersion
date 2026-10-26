import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:sqlite3/sqlite3.dart' show Database;

/// Schema v299: pre_dive_checklist_template_sections, replacing the
/// free-text pre_dive_checklist_template_items.section column with a
/// section_id reference (issue #3360). Built-in templates (CCR Build) get
/// stable, human-readable section ids via
/// kSeedBuiltInPreDiveTemplateSectionsSql /
/// kAssignBuiltInPreDiveSectionIdsSql rather than this rung's generic
/// hash-id backfill, which is scoped to exclude them.
void main() {
  void createBaseSchema(Database rawDb, int userVersion) {
    rawDb.execute('PRAGMA user_version = $userVersion');
    rawDb.execute('CREATE TABLE divers (id TEXT NOT NULL PRIMARY KEY)');
    rawDb.execute('''
      CREATE TABLE pre_dive_checklist_templates (
        id TEXT NOT NULL PRIMARY KEY,
        diver_id TEXT,
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        category TEXT,
        strict_order INTEGER NOT NULL DEFAULT 0,
        is_built_in INTEGER NOT NULL DEFAULT 0,
        builtin_key TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        hlc TEXT
      )
    ''');
    rawDb.execute('''
      CREATE TABLE pre_dive_checklist_template_items (
        id TEXT NOT NULL PRIMARY KEY,
        template_id TEXT NOT NULL REFERENCES pre_dive_checklist_templates (id),
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
        equipment_id TEXT,
        source_item_id TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        hlc TEXT
      )
    ''');
    rawDb.execute(
      "INSERT INTO pre_dive_checklist_templates "
      "(id, name, is_built_in, created_at, updated_at) VALUES "
      "('tpl1', 'Custom', 0, 0, 0), "
      "('builtin-predive-ccr-build', 'CCR Build', 1, 0, 0)",
    );
  }

  void insertItem(
    Database rawDb, {
    required String id,
    required String templateId,
    required String title,
    String? section,
    int sortOrder = 0,
  }) {
    final sectionLiteral = section == null ? 'NULL' : "'$section'";
    rawDb.execute(
      'INSERT INTO pre_dive_checklist_template_items '
      '(id, template_id, title, section, sort_order, created_at, updated_at) '
      "VALUES ('$id', '$templateId', '$title', $sectionLiteral, $sortOrder, 0, 0)",
    );
  }

  NativeDatabase setupDb({
    int userVersion = 298,
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

  test('v299 is at or below the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(299));
    expect(AppDatabase.migrationVersions, contains(299));
    expect(
      AppDatabase.minimumCompatibleSchemaVersion,
      greaterThanOrEqualTo(299),
    );
  });

  test('creates pre_dive_checklist_template_sections and section_id, drops '
      'section', () async {
    final db = AppDatabase(
      setupDb(
        seed: (raw) =>
            insertItem(raw, id: 'i1', templateId: 'tpl1', title: 'Pack mask'),
      ),
    );
    addTearDown(db.close);

    expect(
      await columnsOf(db, 'pre_dive_checklist_template_sections'),
      containsAll(['id', 'template_id', 'title', 'sort_order', 'hlc']),
    );
    final itemCols = await columnsOf(db, 'pre_dive_checklist_template_items');
    expect(itemCols, contains('section_id'));
    expect(itemCols, isNot(contains('section')));
  });

  test(
    'non-built-in items sharing a section merge, first-seen casing',
    () async {
      final db = AppDatabase(
        setupDb(
          seed: (raw) {
            insertItem(
              raw,
              id: 'i1',
              templateId: 'tpl1',
              title: 'Mask',
              section: 'Gear',
            );
            insertItem(
              raw,
              id: 'i2',
              templateId: 'tpl1',
              title: 'Fins',
              section: 'gear',
              sortOrder: 1,
            );
          },
        ),
      );
      addTearDown(db.close);

      final sections = await db
          .customSelect(
            "SELECT * FROM pre_dive_checklist_template_sections "
            "WHERE template_id = 'tpl1'",
          )
          .get();
      expect(sections, hasLength(1));
      expect(sections.single.data['title'], 'Gear');
    },
  );

  test('built-in CCR Build items get the stable, human-readable section ids, '
      'not hash ids from the generic backfill', () async {
    final db = AppDatabase(
      setupDb(
        seed: (raw) {
          insertItem(
            raw,
            id: 'builtin-predive-ccr-0',
            templateId: 'builtin-predive-ccr-build',
            title: 'Scrubber packed',
            section: 'Assembly',
          );
          insertItem(
            raw,
            id: 'builtin-predive-ccr-4',
            templateId: 'builtin-predive-ccr-build',
            title: 'Cell 1 mV in air',
            section: 'Cells',
            sortOrder: 4,
          );
        },
      ),
    );
    addTearDown(db.close);

    final assembly = await db
        .customSelect(
          "SELECT section_id FROM pre_dive_checklist_template_items "
          "WHERE id = 'builtin-predive-ccr-0'",
        )
        .getSingle();
    expect(assembly.data['section_id'], 'builtin-predive-ccr-build-assembly');
    final cells = await db
        .customSelect(
          "SELECT section_id FROM pre_dive_checklist_template_items "
          "WHERE id = 'builtin-predive-ccr-4'",
        )
        .getSingle();
    expect(cells.data['section_id'], 'builtin-predive-ccr-build-cells');

    // No duplicate hash-id section alongside the stable one: every
    // section row under this template is one of the six stable ids.
    final sections = await db
        .customSelect(
          "SELECT id FROM pre_dive_checklist_template_sections "
          "WHERE template_id = 'builtin-predive-ccr-build'",
        )
        .get();
    expect(
      sections.every(
        (r) =>
            (r.data['id'] as String).startsWith('builtin-predive-ccr-build-'),
      ),
      isTrue,
    );
  });

  test('items with no section stay unsectioned', () async {
    final db = AppDatabase(
      setupDb(
        seed: (raw) =>
            insertItem(raw, id: 'i1', templateId: 'tpl1', title: 'No section'),
      ),
    );
    addTearDown(db.close);

    final item = await db
        .customSelect(
          "SELECT section_id FROM pre_dive_checklist_template_items "
          "WHERE id = 'i1'",
        )
        .getSingle();
    expect(item.data['section_id'], isNull);
  });

  test('reopening after an interrupted upgrade does not duplicate sections '
      'or lose the item link (deterministic section ids)', () async {
    final dir = Directory.systemTemp.createTempSync(
      'pre_dive_template_sections',
    );
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = p.join(dir.path, 'test.sqlite');

    final first = AppDatabase(
      NativeDatabase(
        File(path),
        setup: (raw) {
          createBaseSchema(raw, 298);
          insertItem(
            raw,
            id: 'i1',
            templateId: 'tpl1',
            title: 'Mask',
            section: 'Gear',
          );
        },
      ),
    );
    // Scoped to the custom template: the built-in CCR Build template's six
    // stable-id sections seed unconditionally on first open too, and are not
    // what this test is pinning.
    final before = await first
        .customSelect(
          'SELECT * FROM pre_dive_checklist_template_sections '
          "WHERE template_id = 'tpl1'",
        )
        .get();
    expect(before, hasLength(1));
    final sectionId = before.single.data['id'];
    await first.close();

    // The real risk this guards against: the old free-text section is gone
    // by now (dropped in the same upgrade that created the row), so a
    // second open has nothing left to backfill from and must leave the
    // existing section and link alone rather than duplicate or lose either.
    final reopened = AppDatabase(NativeDatabase(File(path)));
    addTearDown(reopened.close);

    final after = await reopened
        .customSelect(
          'SELECT * FROM pre_dive_checklist_template_sections '
          "WHERE template_id = 'tpl1'",
        )
        .get();
    expect(after, hasLength(1), reason: 'no duplicate section row');
    expect(after.single.data['id'], sectionId);

    final item = await reopened
        .customSelect(
          "SELECT section_id FROM pre_dive_checklist_template_items "
          "WHERE id = 'i1'",
        )
        .getSingle();
    expect(item.data['section_id'], sectionId);
  });

  test('a database stamped v299 without the migration ever having run heals '
      'in beforeOpen (parallel-branch version collision)', () async {
    final db = AppDatabase(
      setupDb(
        userVersion: 299,
        seed: (raw) => insertItem(
          raw,
          id: 'i1',
          templateId: 'tpl1',
          title: 'Mask',
          section: 'Gear',
        ),
      ),
    );
    addTearDown(db.close);

    final itemCols = await columnsOf(db, 'pre_dive_checklist_template_items');
    expect(itemCols, contains('section_id'));
    expect(itemCols, isNot(contains('section')));

    final item = await db
        .customSelect(
          "SELECT section_id FROM pre_dive_checklist_template_items "
          "WHERE id = 'i1'",
        )
        .getSingle();
    expect(item.data['section_id'], isNotNull);
  });

  test(
    'a fixture with nothing at all still gets the table via the unconditional '
    'pre-dive schema self-heal',
    () async {
      // Unlike the trip-checklist/checklist-template rungs, pre-dive's own
      // _assertPreDiveChecklistSchema (v128, parallel-branch self-heal) is
      // unconditional: every beforeOpen recreates
      // pre_dive_checklist_templates/items regardless of what the fixture
      // started with. This backstop runs right after that self-heal (issue
      // #3360), so "no templates table" is not a reachable fixture for
      // pre-dive the way it is for the other three table groups.
      final db = AppDatabase(
        NativeDatabase.memory(
          setup: (rawDb) => rawDb.execute('PRAGMA user_version = 298'),
        ),
      );
      addTearDown(db.close);

      expect(
        await columnsOf(db, 'pre_dive_checklist_template_sections'),
        isNotEmpty,
      );
    },
  );

  test('a fresh database matches the upgraded one', () async {
    final upgraded = AppDatabase(setupDb());
    addTearDown(upgraded.close);
    final fresh = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(fresh.close);

    expect(
      await columnsOf(upgraded, 'pre_dive_checklist_template_sections'),
      await columnsOf(fresh, 'pre_dive_checklist_template_sections'),
    );
    expect(
      await columnsOf(upgraded, 'pre_dive_checklist_template_items'),
      await columnsOf(fresh, 'pre_dive_checklist_template_items'),
    );
  });
}
