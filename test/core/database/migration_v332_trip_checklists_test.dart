import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:sqlite3/sqlite3.dart' show Database;

/// Schema v332: trip_checklists, splitting one trip's single flat
/// checklist into several named ones (issue #3356). `trip_id` on
/// `trip_checklist_sections`/`trip_checklist_items` is replaced by
/// `checklist_id`, backfilled by creating one default "Checklist" row per
/// trip that already has sections or items.
void main() {
  /// Base schema at the pre-v332 shape: trips, plus
  /// trip_checklist_sections/items still carrying `trip_id` directly
  /// (the v297-331 shape).
  void createBaseSchema(Database rawDb, int userVersion) {
    rawDb.execute('PRAGMA user_version = $userVersion');
    rawDb.execute('CREATE TABLE trips (id TEXT NOT NULL PRIMARY KEY)');
    rawDb.execute('''
      CREATE TABLE trip_checklist_sections (
        id TEXT NOT NULL PRIMARY KEY,
        trip_id TEXT NOT NULL REFERENCES trips (id),
        title TEXT NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        hlc TEXT
      )
    ''');
    rawDb.execute('''
      CREATE TABLE trip_checklist_items (
        id TEXT NOT NULL PRIMARY KEY,
        trip_id TEXT NOT NULL REFERENCES trips (id),
        title TEXT NOT NULL,
        section_id TEXT REFERENCES trip_checklist_sections (id) ON DELETE SET NULL,
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
    rawDb.execute(
      'CREATE INDEX idx_trip_checklist_items_trip_id '
      'ON trip_checklist_items(trip_id)',
    );
    rawDb.execute(
      'CREATE INDEX idx_trip_checklist_sections_trip_id '
      'ON trip_checklist_sections(trip_id)',
    );
    rawDb.execute("INSERT INTO trips (id) VALUES ('trip1'), ('trip2')");
  }

  void insertSection(
    Database rawDb, {
    required String id,
    required String tripId,
    required String title,
  }) {
    rawDb.execute(
      'INSERT INTO trip_checklist_sections '
      '(id, trip_id, title, created_at, updated_at) '
      "VALUES ('$id', '$tripId', '$title', 0, 0)",
    );
  }

  void insertItem(
    Database rawDb, {
    required String id,
    required String tripId,
    required String title,
    String? sectionId,
  }) {
    final sectionLiteral = sectionId == null ? 'NULL' : "'$sectionId'";
    rawDb.execute(
      'INSERT INTO trip_checklist_items '
      '(id, trip_id, title, section_id, created_at, updated_at) '
      "VALUES ('$id', '$tripId', '$title', $sectionLiteral, 0, 0)",
    );
  }

  NativeDatabase setupDb({
    int userVersion = 331,
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

  Future<List<QueryRow>> checklistsForTrip(AppDatabase db, String tripId) => db
      .customSelect(
        'SELECT * FROM trip_checklists WHERE trip_id = ?',
        variables: [Variable.withString(tripId)],
      )
      .get();

  test('v332 is at or below the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(332));
    expect(AppDatabase.migrationVersions, contains(332));
  });

  test('a trip with existing sections and items gets one default checklist, '
      'and both tables switch to checklist_id', () async {
    final db = AppDatabase(
      setupDb(
        seed: (raw) {
          insertSection(raw, id: 's1', tripId: 'trip1', title: 'Cells');
          insertItem(
            raw,
            id: 'i1',
            tripId: 'trip1',
            title: 'O-rings',
            sectionId: 's1',
          );
          insertItem(raw, id: 'i2', tripId: 'trip1', title: 'Passport');
        },
      ),
    );
    addTearDown(db.close);

    final checklists = await checklistsForTrip(db, 'trip1');
    expect(checklists, hasLength(1));
    expect(checklists.single.data['name'], 'Checklist');
    final checklistId = checklists.single.data['id'];

    expect(
      await columnsOf(db, 'trip_checklist_sections'),
      allOf(contains('checklist_id'), isNot(contains('trip_id'))),
    );
    expect(
      await columnsOf(db, 'trip_checklist_items'),
      allOf(contains('checklist_id'), isNot(contains('trip_id'))),
    );

    final section = await db
        .customSelect(
          'SELECT checklist_id FROM trip_checklist_sections WHERE id = ?',
          variables: [Variable.withString('s1')],
        )
        .getSingle();
    expect(section.data['checklist_id'], checklistId);

    final items = await db
        .customSelect(
          'SELECT id, checklist_id FROM trip_checklist_items '
          'ORDER BY id',
        )
        .get();
    expect(items.map((r) => r.data['checklist_id']).toSet(), {checklistId});
  });

  test('a trip with neither sections nor items gets no checklist', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    expect(await checklistsForTrip(db, 'trip1'), isEmpty);
    expect(await checklistsForTrip(db, 'trip2'), isEmpty);
  });

  test('two trips each get their own default checklist', () async {
    final db = AppDatabase(
      setupDb(
        seed: (raw) {
          insertItem(raw, id: 'i1', tripId: 'trip1', title: 'A');
          insertItem(raw, id: 'i2', tripId: 'trip2', title: 'B');
        },
      ),
    );
    addTearDown(db.close);

    final checklist1 = await checklistsForTrip(db, 'trip1');
    final checklist2 = await checklistsForTrip(db, 'trip2');
    expect(checklist1, hasLength(1));
    expect(checklist2, hasLength(1));
    expect(checklist1.single.data['id'], isNot(checklist2.single.data['id']));
  });

  test(
    'reopening after an interrupted upgrade does not duplicate the '
    'default checklist or lose the link (deterministic checklist ids)',
    () async {
      // A real file, not memory: NativeDatabase.memory cannot be reopened,
      // and the risk this guards against is specifically a process that
      // dies mid-upgrade and restarts against the same file.
      final dir = Directory.systemTemp.createTempSync('trip_checklists');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = p.join(dir.path, 'test.sqlite');

      final first = AppDatabase(
        NativeDatabase(
          File(path),
          setup: (raw) {
            createBaseSchema(raw, 331);
            insertItem(raw, id: 'i1', tripId: 'trip1', title: 'Passport');
          },
        ),
      );
      final before = await checklistsForTrip(first, 'trip1');
      expect(before, hasLength(1));
      final checklistId = before.single.data['id'];
      await first.close();

      final reopened = AppDatabase(NativeDatabase(File(path)));
      addTearDown(reopened.close);

      final after = await checklistsForTrip(reopened, 'trip1');
      expect(after, hasLength(1), reason: 'no duplicate checklist row');
      expect(after.single.data['id'], checklistId);

      final item = await reopened
          .customSelect(
            "SELECT checklist_id FROM trip_checklist_items WHERE id = 'i1'",
          )
          .getSingle();
      expect(item.data['checklist_id'], checklistId);
    },
  );

  test('a database stamped v332 without the migration ever having run '
      'heals in beforeOpen (parallel-branch version collision)', () async {
    final db = AppDatabase(
      setupDb(
        userVersion: 332,
        seed: (raw) => insertItem(raw, id: 'i1', tripId: 'trip1', title: 'A'),
      ),
    );
    addTearDown(db.close);

    final checklists = await checklistsForTrip(db, 'trip1');
    expect(checklists, hasLength(1));
    final item = await db
        .customSelect(
          "SELECT checklist_id FROM trip_checklist_items WHERE id = 'i1'",
        )
        .getSingle();
    expect(item.data['checklist_id'], checklists.single.data['id']);
  });

  test('a fixture without trips skips the table and the column', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) => rawDb.execute('PRAGMA user_version = 291'),
      ),
    );
    addTearDown(db.close);

    expect(
      await db.customSelect('SELECT * FROM trip_checklists').get(),
      isEmpty,
    );
  });

  test('a fresh database matches the upgraded one', () async {
    final upgraded = AppDatabase(setupDb());
    addTearDown(upgraded.close);
    final fresh = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(fresh.close);

    expect(
      await columnsOf(upgraded, 'trip_checklists'),
      await columnsOf(fresh, 'trip_checklists'),
    );
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
