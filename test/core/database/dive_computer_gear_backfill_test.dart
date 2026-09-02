import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/dive_computer_gear_backfill.dart';
import 'package:submersion/core/database/dive_computer_gear_identity.dart';

/// The v175 backfill mints a gear twin per registered computer and links it to
/// every dive that computer logged. The fixture is stamped at 168 so the ladder
/// runs the real migration.
NativeDatabase _seeded() {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 168');
      rawDb.execute('''
        CREATE TABLE dive_computers (
          id TEXT NOT NULL PRIMARY KEY,
          diver_id TEXT,
          name TEXT NOT NULL,
          manufacturer TEXT,
          model TEXT,
          serial_number TEXT,
          dive_count INTEGER NOT NULL DEFAULT 0,
          is_favorite INTEGER NOT NULL DEFAULT 0,
          notes TEXT NOT NULL DEFAULT '',
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      rawDb.execute('''
        CREATE TABLE dives (
          id TEXT NOT NULL PRIMARY KEY,
          diver_id TEXT,
          computer_id TEXT,
          dive_date_time INTEGER NOT NULL DEFAULT 0
        )
      ''');
      rawDb.execute('''
        CREATE TABLE dive_data_sources (
          id TEXT NOT NULL PRIMARY KEY,
          dive_id TEXT NOT NULL,
          computer_id TEXT,
          is_primary INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL DEFAULT 0
        )
      ''');
      rawDb.execute('''
        CREATE TABLE dive_equipment (
          dive_id TEXT NOT NULL,
          equipment_id TEXT NOT NULL,
          PRIMARY KEY (dive_id, equipment_id)
        )
      ''');
      rawDb.execute('''
        CREATE TABLE equipment (
          id TEXT NOT NULL PRIMARY KEY,
          diver_id TEXT,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          brand TEXT,
          model TEXT,
          serial_number TEXT,
          status TEXT NOT NULL DEFAULT 'active',
          purchase_currency TEXT NOT NULL DEFAULT 'USD',
          notes TEXT NOT NULL DEFAULT '',
          is_active INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          hlc TEXT
        )
      ''');

      rawDb.execute(
        "INSERT INTO dive_computers (id, diver_id, name, manufacturer, model, "
        "created_at, updated_at) VALUES "
        "('c1', 'd1', 'My Perdix', 'Shearwater', 'Perdix 2', 1, 1)",
      );
      rawDb.execute(
        "INSERT INTO dive_computers (id, diver_id, name, manufacturer, model, "
        "created_at, updated_at) VALUES "
        "('c2', 'd1', 'My NERD', 'Shearwater', 'NERD 2', 1, 1)",
      );
      // dive1: primary c1 only. dive2: two sources, c1 primary and c2.
      rawDb.execute(
        "INSERT INTO dives (id, diver_id, computer_id) "
        "VALUES ('dive1', 'd1', 'c1')",
      );
      rawDb.execute(
        "INSERT INTO dives (id, diver_id, computer_id) "
        "VALUES ('dive2', 'd1', 'c1')",
      );
      rawDb.execute(
        "INSERT INTO dive_data_sources (id, dive_id, computer_id, is_primary, "
        "created_at) VALUES ('s1', 'dive1', 'c1', 1, 1)",
      );
      rawDb.execute(
        "INSERT INTO dive_data_sources (id, dive_id, computer_id, is_primary, "
        "created_at) VALUES ('s2', 'dive2', 'c1', 1, 1)",
      );
      rawDb.execute(
        "INSERT INTO dive_data_sources (id, dive_id, computer_id, is_primary, "
        "created_at) VALUES ('s3', 'dive2', 'c2', 0, 1)",
      );
    },
  );
}

Future<Set<String>> _equipmentOn(AppDatabase db, String diveId) async {
  final rows = await db
      .customSelect(
        'SELECT equipment_id FROM dive_equipment WHERE dive_id = ?',
        variables: [Variable<String>(diveId)],
      )
      .get();
  return rows.map((r) => r.read<String>('equipment_id')).toSet();
}

void main() {
  test('mints a twin per computer and links its dives', () async {
    final db = AppDatabase(_seeded());
    addTearDown(db.close);

    final c1Twin = diveComputerGearId('c1');
    final c2Twin = diveComputerGearId('c2');

    final computers = await db
        .customSelect('SELECT id, equipment_id FROM dive_computers ORDER BY id')
        .get();
    expect(computers[0].read<String?>('equipment_id'), c1Twin);
    expect(computers[1].read<String?>('equipment_id'), c2Twin);

    expect(await _equipmentOn(db, 'dive1'), {c1Twin});
    // A multi-source dive gets BOTH computers: dives.computer_id holds only
    // the primary, so the union with dive_data_sources is what catches c2.
    expect(await _equipmentOn(db, 'dive2'), {c1Twin, c2Twin});
  });

  test(
    'minted twins are computer-type gear carrying the device identity',
    () async {
      final db = AppDatabase(_seeded());
      addTearDown(db.close);

      final row = await db
          .customSelect(
            'SELECT name, type, brand, model FROM equipment WHERE id = ?',
            variables: [Variable<String>(diveComputerGearId('c1'))],
          )
          .getSingle();
      expect(row.read<String>('type'), 'computer');
      expect(row.read<String>('name'), 'My Perdix');
      expect(row.read<String>('brand'), 'Shearwater');
      expect(row.read<String>('model'), 'Perdix 2');
    },
  );

  test('is idempotent when re-run', () async {
    // A crash mid-ladder leaves user_version unchanged and re-runs every step
    // from the top on a fresh connection, so each step is idempotent by
    // contract. Re-running the function directly is the property that matters;
    // a second open would not re-enter the rung at all, since the backfill is
    // ladder-only by design.
    final db = AppDatabase(_seeded());
    addTearDown(db.close);

    await backfillDiveComputerGearTwins(db);
    await backfillDiveComputerGearTwins(db);

    final count = await db
        .customSelect('SELECT COUNT(*) AS c FROM equipment')
        .getSingle();
    expect(count.read<int>('c'), 2);

    final links = await db
        .customSelect('SELECT COUNT(*) AS c FROM dive_equipment')
        .getSingle();
    // dive1 -> c1, dive2 -> c1 and c2.
    expect(links.read<int>('c'), 3);
  });

  test(
    'adopts an unambiguous hand-created gear item instead of minting',
    () async {
      final native = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 168');
          rawDb.execute('''
          CREATE TABLE dive_computers (
            id TEXT NOT NULL PRIMARY KEY,
            diver_id TEXT,
            name TEXT NOT NULL,
            manufacturer TEXT,
            model TEXT,
            serial_number TEXT,
            dive_count INTEGER NOT NULL DEFAULT 0,
            is_favorite INTEGER NOT NULL DEFAULT 0,
            notes TEXT NOT NULL DEFAULT '',
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
          rawDb.execute('''
          CREATE TABLE equipment (
            id TEXT NOT NULL PRIMARY KEY,
            diver_id TEXT,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            brand TEXT,
            model TEXT,
            serial_number TEXT,
            status TEXT NOT NULL DEFAULT 'active',
            purchase_currency TEXT NOT NULL DEFAULT 'USD',
            notes TEXT NOT NULL DEFAULT '',
            is_active INTEGER NOT NULL DEFAULT 1,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
          rawDb.execute(
            "INSERT INTO dive_computers (id, diver_id, name, manufacturer, "
            "model, created_at, updated_at) VALUES "
            "('c1', 'd1', 'My Perdix', 'Shearwater', 'Perdix 2', 1, 1)",
          );
          rawDb.execute(
            "INSERT INTO equipment (id, diver_id, name, type, brand, model, "
            "created_at, updated_at) VALUES "
            "('hand-made', 'd1', 'Perdix', 'computer', 'Shearwater', "
            "'Perdix 2', 1, 1)",
          );
        },
      );
      final db = AppDatabase(native);
      addTearDown(db.close);

      final row = await db
          .customSelect(
            "SELECT equipment_id FROM dive_computers WHERE id = 'c1'",
          )
          .getSingle();
      expect(row.read<String?>('equipment_id'), 'hand-made');
      final count = await db
          .customSelect('SELECT COUNT(*) AS c FROM equipment')
          .getSingle();
      expect(count.read<int>('c'), 1);
    },
  );
  test(
    'is local-only: minted rows carry no HLC and never go out incrementally',
    () async {
      // Deliberate, and load-bearing. Every input is already synced and the twin
      // id is derived, so each device produces identical rows when its own ladder
      // runs. Stamping an HLC here would push one record per computer plus one
      // per (dive, computer) pair from every device in the fleet, to make peers
      // agree on rows they each derive anyway. Incremental export filters
      // equipment on `hlc > watermark`, so a null HLC is exactly what keeps these
      // writes off the wire; a base export ignores the watermark and still
      // carries them.
      final db = AppDatabase(_seeded());
      addTearDown(db.close);

      final rows = await db
          .customSelect("SELECT hlc FROM equipment WHERE type = 'computer'")
          .get();
      expect(rows, hasLength(2));
      for (final row in rows) {
        expect(row.read<String?>('hlc'), isNull);
      }
    },
  );
}
