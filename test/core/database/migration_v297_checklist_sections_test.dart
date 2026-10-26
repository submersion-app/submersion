import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:sqlite3/sqlite3.dart' show Database;

/// Schema v297: trip_checklist_sections, replacing the free-text
/// trip_checklist_items.category column with a section_id reference
/// (issue #3360). Add + backfill + drop all land in this one rung (no
/// separate "stage B"; see docs/design/plans/2026-10-18-checklist-sections-
/// plan.md's migration-safety section for why a historical two-release
/// split does not apply to a migration written from scratch).
void main() {
  /// Base schema (trips + pre-migration trip_checklist_items with
  /// `category`) shared by every fixture below.
  void createBaseSchema(Database rawDb, int userVersion) {
    rawDb.execute('PRAGMA user_version = $userVersion');
    rawDb.execute('CREATE TABLE trips (id TEXT NOT NULL PRIMARY KEY)');
    rawDb.execute('''
      CREATE TABLE trip_checklist_items (
        id TEXT NOT NULL PRIMARY KEY,
        trip_id TEXT NOT NULL REFERENCES trips (id),
        title TEXT NOT NULL,
        category TEXT,
        notes TEXT NOT NULL DEFAULT '',
        due_date INTEGER,
        is_done INTEGER NOT NULL DEFAULT 0,
        completed_at INTEGER,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        hlc TEXT
      )
    ''');
    rawDb.execute("INSERT INTO trips (id) VALUES ('trip1'), ('trip2')");
  }

  void insertItem(
    Database rawDb, {
    required String id,
    required String tripId,
    required String title,
    String? category,
    int sortOrder = 0,
  }) {
    final categoryLiteral = category == null ? 'NULL' : "'$category'";
    rawDb.execute(
      'INSERT INTO trip_checklist_items '
      '(id, trip_id, title, category, sort_order, created_at, updated_at) '
      "VALUES ('$id', '$tripId', '$title', $categoryLiteral, $sortOrder, 0, 0)",
    );
  }

  /// An in-memory v291 database, optionally seeded with items via [seed].
  NativeDatabase setupDb({
    int userVersion = 291,
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

  test('v297 is at or below the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(297));
    expect(AppDatabase.migrationVersions, contains(297));
    expect(
      AppDatabase.minimumCompatibleSchemaVersion,
      greaterThanOrEqualTo(297),
    );
  });

  test(
    'creates trip_checklist_sections and section_id, drops category',
    () async {
      final db = AppDatabase(
        setupDb(
          seed: (raw) =>
              insertItem(raw, id: 'i1', tripId: 'trip1', title: 'O-rings'),
        ),
      );
      addTearDown(db.close);

      expect(
        await columnsOf(db, 'trip_checklist_sections'),
        containsAll(['id', 'trip_id', 'title', 'sort_order', 'hlc']),
      );
      final itemCols = await columnsOf(db, 'trip_checklist_items');
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
              tripId: 'trip1',
              title: 'Cell 1',
              category: 'Cells',
            );
            insertItem(
              raw,
              id: 'i2',
              tripId: 'trip1',
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
            "SELECT * FROM trip_checklist_sections WHERE trip_id = 'trip1'",
          )
          .get();
      expect(sections, hasLength(1));
      expect(sections.single.data['title'], 'Cells');

      final items = await db
          .customSelect(
            "SELECT section_id FROM trip_checklist_items "
            "WHERE trip_id = 'trip1'",
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
        seed: (raw) {
          insertItem(raw, id: 'i1', tripId: 'trip1', title: 'Passport');
          insertItem(
            raw,
            id: 'i2',
            tripId: 'trip1',
            title: 'Blank category',
            category: '',
          );
        },
      ),
    );
    addTearDown(db.close);

    final items = await db
        .customSelect(
          "SELECT section_id FROM trip_checklist_items "
          "WHERE trip_id = 'trip1'",
        )
        .get();
    expect(items.every((r) => r.data['section_id'] == null), isTrue);
    expect(
      await db.customSelect('SELECT * FROM trip_checklist_sections').get(),
      isEmpty,
    );
  });

  test('two trips with the same category text get separate sections', () async {
    final db = AppDatabase(
      setupDb(
        seed: (raw) {
          insertItem(
            raw,
            id: 'i1',
            tripId: 'trip1',
            title: 'A',
            category: 'Gear',
          );
          insertItem(
            raw,
            id: 'i2',
            tripId: 'trip2',
            title: 'B',
            category: 'Gear',
          );
        },
      ),
    );
    addTearDown(db.close);

    final sections = await db
        .customSelect('SELECT * FROM trip_checklist_sections')
        .get();
    expect(sections, hasLength(2));
    expect(sections.map((r) => r.data['trip_id']).toSet(), {'trip1', 'trip2'});
  });

  test('reopening after an interrupted upgrade does not duplicate sections '
      'or lose the item link (deterministic section ids)', () async {
    // A real file, not memory: NativeDatabase.memory cannot be reopened,
    // and the risk this guards against is specifically a process that
    // dies between the backfill UPDATE and the user_version stamp, then
    // restarts against the same file.
    final dir = Directory.systemTemp.createTempSync('checklist_sections');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = p.join(dir.path, 'test.sqlite');

    final first = AppDatabase(
      NativeDatabase(
        File(path),
        setup: (raw) {
          createBaseSchema(raw, 291);
          insertItem(
            raw,
            id: 'i1',
            tripId: 'trip1',
            title: 'Cell 1',
            category: 'Cells',
          );
        },
      ),
    );
    final before = await first
        .customSelect('SELECT * FROM trip_checklist_sections')
        .get();
    expect(before, hasLength(1));
    final sectionId = before.single.data['id'];
    await first.close();

    // The real risk this guards against: category is gone by now (dropped
    // in the same upgrade that created the section), so a second open has
    // nothing left to backfill from and must leave the existing section and
    // link alone rather than duplicate or lose either. beforeOpen
    // re-asserts schema and backfill on every open regardless.
    final reopened = AppDatabase(NativeDatabase(File(path)));
    addTearDown(reopened.close);

    final after = await reopened
        .customSelect('SELECT * FROM trip_checklist_sections')
        .get();
    expect(after, hasLength(1), reason: 'no duplicate section row');
    expect(after.single.data['id'], sectionId);

    final item = await reopened
        .customSelect(
          "SELECT section_id FROM trip_checklist_items WHERE id = 'i1'",
        )
        .getSingle();
    expect(item.data['section_id'], sectionId);
  });

  test('a database stamped v297 without the migration ever having run heals '
      'in beforeOpen (parallel-branch version collision)', () async {
    final db = AppDatabase(
      setupDb(
        userVersion: 297,
        seed: (raw) => insertItem(
          raw,
          id: 'i1',
          tripId: 'trip1',
          title: 'Cell 1',
          category: 'Cells',
        ),
      ),
    );
    addTearDown(db.close);

    expect(await columnsOf(db, 'trip_checklist_sections'), contains('trip_id'));
    final itemCols = await columnsOf(db, 'trip_checklist_items');
    expect(itemCols, contains('section_id'));
    expect(itemCols, isNot(contains('category')));

    final item = await db
        .customSelect(
          "SELECT section_id FROM trip_checklist_items WHERE id = 'i1'",
        )
        .getSingle();
    expect(item.data['section_id'], isNotNull);
  });

  test('a fixture without trips skips the table and the column', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) => rawDb.execute('PRAGMA user_version = 291'),
      ),
    );
    addTearDown(db.close);

    expect(await columnsOf(db, 'trip_checklist_sections'), isEmpty);
  });

  test('a fresh database matches the upgraded one', () async {
    final upgraded = AppDatabase(setupDb());
    addTearDown(upgraded.close);
    final fresh = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(fresh.close);

    expect(
      await columnsOf(upgraded, 'trip_checklist_sections'),
      await columnsOf(fresh, 'trip_checklist_sections'),
    );
    expect(
      await columnsOf(upgraded, 'trip_checklist_items'),
      await columnsOf(fresh, 'trip_checklist_items'),
    );
  });
}
