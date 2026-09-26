import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/equipment_share_uniqueness.dart';

/// Schema v232: equipment sharing (issue #2046).
void main() {
  /// A v231 database without the sharing tables. Minimal parents, as the
  /// v219 fixture: the beforeOpen backstops heal every older rung.
  NativeDatabase setupDb({int userVersion = 231, bool withEquipment = true}) {
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

  test('v232 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 232);
    expect(AppDatabase.migrationVersions, contains(232));
    expect(AppDatabase.migrationStepCount(231), 1);
    // Additive rung: the sync compatibility floor must not move.
    expect(AppDatabase.minimumCompatibleSchemaVersion, 224);
  });

  test('adds equipment_shares and equipment_ownership_events', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    expect(
      await columnsOf(db, 'equipment_shares'),
      containsAll(['id', 'equipment_id', 'diver_id', 'created_at', 'hlc']),
    );
    expect(
      await columnsOf(db, 'equipment_ownership_events'),
      containsAll([
        'id',
        'equipment_id',
        'kind',
        'from_diver_id',
        'to_diver_id',
        'occurred_at',
        'hlc',
      ]),
    );
  });

  test(
    'shares cascade from item and diver; events detach from a diver',
    () async {
      final db = AppDatabase(setupDb());
      addTearDown(db.close);
      final shares = await ddlOf(db, 'table', 'equipment_shares');
      expect(shares, contains('REFERENCES equipment (id) ON DELETE CASCADE'));
      expect(shares, contains('REFERENCES divers (id) ON DELETE CASCADE'));
      final events = await ddlOf(db, 'table', 'equipment_ownership_events');
      expect(events, contains('REFERENCES equipment (id) ON DELETE CASCADE'));
      expect(events, contains('REFERENCES divers (id) ON DELETE SET NULL'));
    },
  );

  test('creates the share unique index and both lookup indexes', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    expect(
      await ddlOf(db, 'index', kEquipmentSharesUniqueIndexName),
      isNotNull,
    );
    expect(await ddlOf(db, 'index', 'idx_equipment_shares_diver'), isNotNull);
    expect(
      await ddlOf(db, 'index', 'idx_equipment_ownership_events_equipment'),
      isNotNull,
    );
  });

  test('a fresh database matches the upgraded one', () async {
    final upgraded = AppDatabase(setupDb());
    final fresh = AppDatabase(NativeDatabase.memory());
    addTearDown(upgraded.close);
    addTearDown(fresh.close);
    for (final table in const [
      'equipment_shares',
      'equipment_ownership_events',
    ]) {
      expect(await tableInfo(upgraded, table), await tableInfo(fresh, table));
      expect(
        await ddlOf(upgraded, 'table', table),
        await ddlOf(fresh, 'table', table),
      );
    }
    expect(
      await ddlOf(upgraded, 'index', kEquipmentSharesUniqueIndexName),
      await ddlOf(fresh, 'index', kEquipmentSharesUniqueIndexName),
    );
  });

  test(
    'a database stamped v232 without the schema heals in beforeOpen',
    () async {
      final db = AppDatabase(setupDb(userVersion: 232));
      addTearDown(db.close);
      expect(await columnsOf(db, 'equipment_shares'), contains('diver_id'));
      expect(
        await columnsOf(db, 'equipment_ownership_events'),
        contains('kind'),
      );
      expect(
        await ddlOf(db, 'index', kEquipmentSharesUniqueIndexName),
        isNotNull,
      );
    },
  );

  test('a fixture without an equipment table skips both tables', () async {
    final db = AppDatabase(setupDb(withEquipment: false));
    addTearDown(db.close);
    expect(await columnsOf(db, 'equipment_shares'), isEmpty);
    expect(await columnsOf(db, 'equipment_ownership_events'), isEmpty);
  });

  test('a duplicate share pair is rejected by the index', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    for (final id in ['d1', 'd2']) {
      await db.customStatement(
        'INSERT INTO divers (id, name, created_at, updated_at) '
        "VALUES ('$id', '$id', 0, 0)",
      );
    }
    await db.customStatement(
      'INSERT INTO equipment (id, name, type, created_at, updated_at, '
      "diver_id) VALUES ('e1', 'e1', 'bcd', 0, 0, 'd1')",
    );
    await db.customStatement(
      'INSERT INTO equipment_shares (id, equipment_id, diver_id, created_at) '
      "VALUES ('s1', 'e1', 'd2', 0)",
    );
    await expectLater(
      db.customStatement(
        'INSERT INTO equipment_shares (id, equipment_id, diver_id, '
        "created_at) VALUES ('s2', 'e1', 'd2', 1)",
      ),
      throwsA(anything),
    );
  });
}
