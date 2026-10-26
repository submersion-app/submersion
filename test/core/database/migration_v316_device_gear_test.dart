import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/dive_computer_gear_identity.dart';

/// Schema v316: one Equipment entry per dive computer and transmitter
/// (issue #3676).
void main() {
  /// A v314 database holding one hand-made transmitter entry.
  NativeDatabase setupDb() {
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 314');
        rawDb.execute('''
          CREATE TABLE transmitters (
            id TEXT NOT NULL PRIMARY KEY,
            diver_id TEXT,
            transmitter_serial TEXT,
            dive_computer_id TEXT,
            channel_index INTEGER,
            label TEXT NOT NULL,
            tank_role TEXT NOT NULL,
            volume_l REAL,
            working_pressure_bar REAL,
            tank_material TEXT,
            preset_name TEXT,
            equipment_id TEXT,
            transmitter_equipment_id TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            hlc TEXT
          )
        ''');
        rawDb.execute(
          'INSERT INTO transmitters (id, transmitter_serial, label, '
          "tank_role, created_at, updated_at) VALUES ('tx1', '4A21F', "
          "'Back gas', 'backGas', 0, 0)",
        );
      },
    );
  }

  test('v316 is in the ladder, at or below the current schema', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(316));
    expect(AppDatabase.migrationVersions, contains(316));
  });

  test('the column is additive, so the sync floor does not move', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, 308);
  });

  test('upgrading from v314 marks every existing entry configured', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    final row = await db
        .customSelect("SELECT is_configured FROM transmitters WHERE id = 'tx1'")
        .getSingle();
    expect(row.read<int>('is_configured'), 1);
  });

  /// A v314-shaped (or v316, for the open-time heal) database whose computer
  /// lost its gear twin, with a hand-added item to adopt and a dive carrying
  /// a transmitter serial nobody registered.
  NativeDatabase richDb({int userVersion = 314}) {
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = $userVersion');
        rawDb.execute('''
          CREATE TABLE equipment (
            id TEXT NOT NULL PRIMARY KEY, diver_id TEXT, name TEXT NOT NULL,
            type TEXT NOT NULL, brand TEXT, model TEXT, serial_number TEXT,
            status TEXT NOT NULL DEFAULT 'active',
            purchase_currency TEXT NOT NULL DEFAULT 'USD',
            notes TEXT NOT NULL DEFAULT '', is_active INTEGER NOT NULL DEFAULT 1,
            created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, hlc TEXT
          )
        ''');
        rawDb.execute('''
          CREATE TABLE dive_computers (
            id TEXT NOT NULL PRIMARY KEY, diver_id TEXT, name TEXT NOT NULL,
            manufacturer TEXT, model TEXT, serial_number TEXT,
            equipment_id TEXT, notes TEXT NOT NULL DEFAULT '',
            created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, hlc TEXT
          )
        ''');
        rawDb.execute('''
          CREATE TABLE dives (
            id TEXT NOT NULL PRIMARY KEY, diver_id TEXT, computer_id TEXT,
            dive_date_time INTEGER NOT NULL DEFAULT 0
          )
        ''');
        rawDb.execute(
          'CREATE TABLE dive_tanks (id TEXT NOT NULL PRIMARY KEY, '
          'dive_id TEXT NOT NULL, transmitter_serial TEXT, tank_role TEXT)',
        );
        rawDb.execute(
          'CREATE TABLE dive_equipment (dive_id TEXT NOT NULL, '
          'equipment_id TEXT NOT NULL, PRIMARY KEY (dive_id, equipment_id))',
        );
        rawDb.execute('''
          CREATE TABLE transmitters (
            id TEXT NOT NULL PRIMARY KEY, diver_id TEXT,
            transmitter_serial TEXT, dive_computer_id TEXT,
            channel_index INTEGER, label TEXT NOT NULL,
            tank_role TEXT NOT NULL, volume_l REAL,
            working_pressure_bar REAL, tank_material TEXT, preset_name TEXT,
            equipment_id TEXT, transmitter_equipment_id TEXT,
            ${userVersion >= 316 ? 'is_configured INTEGER NOT NULL DEFAULT 1,' : ''}
            created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, hlc TEXT
          )
        ''');
        rawDb.execute(
          'INSERT INTO equipment (id, name, type, brand, model, created_at, '
          "updated_at) VALUES ('hand', 'Teric', 'computer', 'Shearwater', "
          "'Teric', 0, 0)",
        );
        rawDb.execute(
          'INSERT INTO equipment (id, name, type, serial_number, created_at, '
          "updated_at) VALUES ('txgear', 'Back gas tx', 'transmitter', "
          "'4A21F', 0, 0)",
        );
        rawDb.execute(
          'INSERT INTO dive_computers (id, name, manufacturer, model, '
          "serial_number, notes, created_at, updated_at) VALUES ('c1', "
          "'Shearwater Teric', 'Shearwater', 'Teric', 'S1', 'Left wrist.', "
          '0, 0)',
        );
        rawDb.execute(
          "INSERT INTO dives (id, computer_id) VALUES ('dive1', 'c1')",
        );
        rawDb.execute(
          'INSERT INTO dive_tanks (id, dive_id, transmitter_serial, '
          "tank_role) VALUES ('tank1', 'dive1', '7C0B19', 'stage')",
        );
        rawDb.execute(
          'INSERT INTO transmitters (id, transmitter_serial, label, '
          'tank_role, equipment_id, transmitter_equipment_id, created_at, '
          "updated_at) VALUES ('tx1', '4A21F', 'Back gas', 'backGas', "
          "NULL, 'txgear', 0, 0)",
        );
      },
    );
  }

  group('upgrading from v314 (#3676)', () {
    test(
      'links a computer whose twin was deleted to the matching item',
      () async {
        final db = AppDatabase(richDb());
        addTearDown(db.close);

        final c = await db
            .customSelect(
              "SELECT equipment_id FROM dive_computers WHERE id = 'c1'",
            )
            .getSingle();
        expect(c.read<String?>('equipment_id'), 'hand');
      },
    );

    test('carries the computer notes onto its item', () async {
      final db = AppDatabase(richDb());
      addTearDown(db.close);

      final e = await db
          .customSelect(
            "SELECT notes, serial_number FROM equipment WHERE id = 'hand'",
          )
          .getSingle();
      expect(e.read<String>('notes'), 'Left wrist.');
      expect(e.read<String?>('serial_number'), 'S1');
    });

    test('registers the unassigned serial as a not-configured row', () async {
      final db = AppDatabase(richDb());
      addTearDown(db.close);

      final row = await db
          .customSelect(
            'SELECT is_configured, transmitter_equipment_id FROM transmitters '
            'WHERE id = ?',
            variables: [Variable<String>(autoTransmitterRowId(null, '7C0B19'))],
          )
          .getSingle();
      expect(row.read<int>('is_configured'), 0);
      expect(
        row.read<String?>('transmitter_equipment_id'),
        transmitterGearSeedId(null, '7C0B19'),
      );
    });

    test('puts the transmitter item on the dive that carries it', () async {
      final db = AppDatabase(richDb());
      addTearDown(db.close);

      final links = await db
          .customSelect(
            "SELECT equipment_id FROM dive_equipment WHERE dive_id = 'dive1'",
          )
          .get();
      expect(
        links.map((r) => r.read<String>('equipment_id')),
        contains(transmitterGearSeedId(null, '7C0B19')),
      );
    });

    test('leaves a hand-made entry and its item alone', () async {
      final db = AppDatabase(richDb());
      addTearDown(db.close);

      final row = await db
          .customSelect(
            'SELECT is_configured, transmitter_equipment_id FROM transmitters '
            "WHERE id = 'tx1'",
          )
          .getSingle();
      expect(row.read<int>('is_configured'), 1);
      expect(row.read<String?>('transmitter_equipment_id'), 'txgear');
    });
  });

  test(
    'opening a current database heals a computer that lost its item',
    () async {
      final db = AppDatabase(richDb(userVersion: 316));
      addTearDown(db.close);

      final c = await db
          .customSelect(
            "SELECT equipment_id FROM dive_computers WHERE id = 'c1'",
          )
          .getSingle();
      expect(c.read<String?>('equipment_id'), 'hand');
      // The serial pass is ladder-only: an open never registers serials.
      final rows = await db
          .customSelect('SELECT COUNT(*) AS n FROM transmitters')
          .getSingle();
      expect(rows.read<int>('n'), 1);
    },
  );

  test(
    'a heal that cannot write never stops the database opening (review)',
    () async {
      final dir = await Directory.systemTemp.createTemp('device_gear_open_');
      addTearDown(() => dir.delete(recursive: true));
      final file = File(p.join(dir.path, 'test.db'));

      final first = AppDatabase(NativeDatabase(file));
      // A computer whose diver no longer exists: minting its item violates the
      // diver foreign key, which INSERT OR IGNORE does not suppress.
      await first.customStatement('PRAGMA foreign_keys = OFF');
      await first.customStatement(
        'INSERT INTO dive_computers (id, diver_id, name, created_at, '
        "updated_at) VALUES ('c1', 'ghost', 'Teric', 0, 0)",
      );
      await first.close();

      final second = AppDatabase(NativeDatabase(file));
      addTearDown(second.close);
      final rows = await second
          .customSelect('SELECT COUNT(*) AS n FROM dive_computers')
          .getSingle();
      expect(rows.read<int>('n'), 1);
    },
  );
}
