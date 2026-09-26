import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Schema v229: trip-scale gas logistics, phase 1 (issue #2325). Two children
/// of trips, trip_cylinders and trip_cylinder_events, and the
/// dive_tanks.trip_cylinder_id link.
void main() {
  /// Pre-v229 dive_tanks: only the columns the rung and its assertions touch.
  const preV229DiveTanks = '''
    CREATE TABLE dive_tanks (
      id TEXT NOT NULL PRIMARY KEY,
      dive_id TEXT NOT NULL,
      o2_percent REAL NOT NULL DEFAULT 21.0,
      he_percent REAL NOT NULL DEFAULT 0.0,
      tank_order INTEGER NOT NULL DEFAULT 0,
      computer_id TEXT
    )
  ''';

  /// A v226 database with every parent the new tables reference, the tables
  /// the beforeOpen backstops touch, one pre-v229 tank row, and neither new
  /// table. If a backstop throws on a missing column of one of these stub
  /// tables, add that column here, as the v221 fixture did for tags.
  NativeDatabase setupDb({
    int userVersion = 228,
    bool withTrips = true,
    bool linkColumnAlreadyAdded = false,
  }) {
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = $userVersion');
        rawDb.execute('CREATE TABLE divers (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dive_sites (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dives (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dive_centers (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE equipment (id TEXT NOT NULL PRIMARY KEY)');
        if (withTrips) {
          rawDb.execute('CREATE TABLE trips (id TEXT PRIMARY KEY)');
        }
        rawDb.execute(preV229DiveTanks);
        rawDb.execute(
          "INSERT INTO dive_tanks (id, dive_id, o2_percent, computer_id) "
          "VALUES ('t1', 'd1', 32.0, 'dc1')",
        );
        if (linkColumnAlreadyAdded) {
          rawDb.execute(
            'ALTER TABLE dive_tanks ADD COLUMN trip_cylinder_id TEXT',
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
              CHECK (applies_to_sites IN (0, 1)),
            applies_to_equipment INTEGER NOT NULL DEFAULT 0
              CHECK (applies_to_equipment IN (0, 1))
          )
        ''');
      },
    );
  }

  Future<Set<String>> columnsOf(AppDatabase db, String table) async {
    final cols = await db.customSelect("PRAGMA table_info('$table')").get();
    return cols.map((c) => c.read<String>('name')).toSet();
  }

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

  /// on_delete action of the dive_tanks foreign key that starts at [column].
  Future<String?> tankLinkAction(AppDatabase db, String column) async {
    final links = await db
        .customSelect("PRAGMA foreign_key_list('dive_tanks')")
        .get();
    for (final l in links) {
      if (l.read<String>('from') == column) {
        return l.read<String>('on_delete').toUpperCase();
      }
    }
    return null;
  }

  const cylinderColumns = <String>[
    'id',
    'trip_id',
    'equipment_id',
    'label',
    'volume',
    'working_pressure',
    'material',
    'preset_name',
    'sort_order',
    'notes',
    'created_at',
    'updated_at',
    'hlc',
  ];

  const eventColumns = <String>[
    'id',
    'trip_cylinder_id',
    'kind',
    'occurred_at',
    'bottle_label',
    'pressure',
    'o2_percent',
    'he_percent',
    'analyzed_o2',
    'analyzed_he',
    'dive_center_id',
    'cost',
    'currency',
    'is_package',
    'note',
    'created_at',
    'updated_at',
    'hlc',
  ];

  test('v229 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 229);
    expect(AppDatabase.migrationVersions, contains(229));
    expect(AppDatabase.migrationStepCount(228), 1);
    // Additive rung: the sync compatibility floor must not move.
    expect(AppDatabase.minimumCompatibleSchemaVersion, 224);
  });

  test('adds trip_cylinders and trip_cylinder_events', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    expect(await columnsOf(db, 'trip_cylinders'), containsAll(cylinderColumns));
    expect(
      await columnsOf(db, 'trip_cylinder_events'),
      containsAll(eventColumns),
    );
  });

  test('adds dive_tanks.trip_cylinder_id and keeps the existing row', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    expect(await columnsOf(db, 'dive_tanks'), contains('trip_cylinder_id'));

    // Column only: an existing tank keeps its attribution and reads back
    // with no slot, never an invented one.
    final row = await db
        .customSelect(
          "SELECT computer_id, trip_cylinder_id FROM dive_tanks WHERE id = 't1'",
        )
        .getSingle();
    expect(row.data['computer_id'], 'dc1');
    expect(row.data['trip_cylinder_id'], isNull);
  });

  test('the links carry the actions the spec fixes', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    final slots = await ddlOf(db, 'table', 'trip_cylinders');
    expect(slots, contains('REFERENCES trips (id)'));
    expect(slots, contains('REFERENCES equipment (id) ON DELETE SET NULL'));

    final events = await ddlOf(db, 'table', 'trip_cylinder_events');
    expect(
      events,
      contains('REFERENCES trip_cylinders (id) ON DELETE CASCADE'),
    );
    expect(events, contains('REFERENCES dive_centers (id) ON DELETE SET NULL'));

    expect(await tankLinkAction(db, 'trip_cylinder_id'), 'SET NULL');
  });

  test('a fresh database matches the upgraded one', () async {
    final upgraded = AppDatabase(setupDb());
    addTearDown(upgraded.close);
    final fresh = AppDatabase(NativeDatabase.memory());
    addTearDown(fresh.close);

    for (final table in const ['trip_cylinders', 'trip_cylinder_events']) {
      expect(await tableInfo(upgraded, table), await tableInfo(fresh, table));
      expect(
        await ddlOf(upgraded, 'table', table),
        await ddlOf(fresh, 'table', table),
      );
    }
    expect(
      await tankLinkAction(upgraded, 'trip_cylinder_id'),
      await tankLinkAction(fresh, 'trip_cylinder_id'),
    );
  });

  test('the rung is idempotent when the link column already exists', () async {
    // An interrupted upgrade, or a database that reached this version from
    // a parallel branch, leaves the column already added. The guard must
    // skip the ALTER rather than fail on a duplicate column.
    final db = AppDatabase(setupDb(linkColumnAlreadyAdded: true));
    addTearDown(db.close);

    final cols = await db.customSelect("PRAGMA table_info('dive_tanks')").get();
    final names = cols.map((c) => c.read<String>('name')).toList();
    expect(names.where((n) => n == 'trip_cylinder_id'), hasLength(1));
  });

  test(
    'a database stamped v229 without the tables heals in beforeOpen',
    () async {
      // A parallel branch that claimed 229 first carries a device past the
      // rung; the beforeOpen backstop must build what the rung would have.
      final db = AppDatabase(setupDb(userVersion: 229));
      addTearDown(db.close);

      expect(await columnsOf(db, 'trip_cylinders'), contains('trip_id'));
      expect(
        await columnsOf(db, 'trip_cylinder_events'),
        contains('trip_cylinder_id'),
      );
      expect(await columnsOf(db, 'dive_tanks'), contains('trip_cylinder_id'));
    },
  );

  test('a fixture without trips skips the tables and the column', () async {
    // A partial fixture written for an older rung must not gain tables whose
    // foreign keys point nowhere, nor a link column with no parent.
    final db = AppDatabase(setupDb(withTrips: false));
    addTearDown(db.close);

    expect(await columnsOf(db, 'trip_cylinders'), isEmpty);
    expect(await columnsOf(db, 'trip_cylinder_events'), isEmpty);
    expect(
      await columnsOf(db, 'dive_tanks'),
      isNot(contains('trip_cylinder_id')),
    );
  });
}
