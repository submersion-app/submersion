import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Issue #1720: a diver upgrading to a beta reported that gear had vanished
/// from many dives, and the first suspicion was the schema ladder. It was not
/// the cause -- every rung from v199 on is `ALTER TABLE ADD COLUMN` or
/// `CREATE TABLE IF NOT EXISTS` -- but nothing pinned that, and the risk is
/// real and permanent: `dive_equipment.equipment_id` is
/// `REFERENCES equipment(id) ON DELETE CASCADE`, so any rung that rebuilds
/// `equipment` the SQLite way (create new, copy, drop old) would take every
/// dive's gear with it while foreign keys are on. A junction row carries no
/// clock and cannot be recovered from a peer, so the loss would be silent and
/// final.
///
/// This walks real gear links up the ladder and insists they arrive.
void main() {
  /// A v199 database holding two dives, three pieces of gear and the links
  /// between them. Minimal on purpose: each rung guards on the tables it
  /// touches, so a fixture only needs the ones under test.
  NativeDatabase strandedAt(int version) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $version');
      rawDb.execute('''
        CREATE TABLE divers (
          id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL,
          created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)
      ''');
      rawDb.execute('''
        CREATE TABLE dives (
          id TEXT NOT NULL PRIMARY KEY, diver_id TEXT,
          dive_date_time INTEGER NOT NULL,
          notes TEXT NOT NULL DEFAULT '',
          created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)
      ''');
      rawDb.execute('''
        CREATE TABLE equipment (
          id TEXT NOT NULL PRIMARY KEY, diver_id TEXT, name TEXT NOT NULL,
          type TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'active',
          purchase_currency TEXT NOT NULL DEFAULT 'USD',
          notes TEXT NOT NULL DEFAULT '', is_active INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, hlc TEXT)
      ''');
      rawDb.execute('''
        CREATE TABLE dive_equipment (
          dive_id TEXT NOT NULL
            REFERENCES dives(id) ON DELETE CASCADE,
          equipment_id TEXT NOT NULL
            REFERENCES equipment(id) ON DELETE CASCADE,
          PRIMARY KEY (dive_id, equipment_id))
      ''');
      rawDb.execute("INSERT INTO divers VALUES ('dr1', 'Diver', 1, 1)");
      for (final id in ['dv1', 'dv2']) {
        rawDb.execute(
          "INSERT INTO dives (id, diver_id, dive_date_time, created_at, "
          "updated_at) VALUES ('$id', 'dr1', 1, 1, 1)",
        );
      }
      // The two types the reporter named, plus one more.
      for (final (id, type) in [
        ('e-bcd', 'bcd'),
        ('e-smb', 'smb'),
        ('e-reg', 'regulator'),
      ]) {
        rawDb.execute(
          "INSERT INTO equipment (id, diver_id, name, type, created_at, "
          "updated_at) VALUES ('$id', 'dr1', '$id', '$type', 1, 1)",
        );
      }
      for (final dive in ['dv1', 'dv2']) {
        for (final gear in ['e-bcd', 'e-smb', 'e-reg']) {
          rawDb.execute("INSERT INTO dive_equipment VALUES ('$dive', '$gear')");
        }
      }
    },
  );

  Future<Set<String>> gearLinks(AppDatabase db) async {
    final rows = await db
        .customSelect('SELECT dive_id, equipment_id FROM dive_equipment')
        .get();
    return {
      for (final r in rows)
        '${r.read<String>('dive_id')}|${r.read<String>('equipment_id')}',
    };
  }

  test('every gear link survives the ladder from v199 to current', () async {
    final db = AppDatabase(strandedAt(199));
    addTearDown(db.close);

    // Forces the open, and with it onUpgrade and every beforeOpen backstop.
    expect(
      await db
          .customSelect('PRAGMA user_version')
          .getSingle()
          .then((r) => r.read<int>('user_version')),
      AppDatabase.currentSchemaVersion,
    );

    expect(await gearLinks(db), {
      'dv1|e-bcd',
      'dv1|e-smb',
      'dv1|e-reg',
      'dv2|e-bcd',
      'dv2|e-smb',
      'dv2|e-reg',
    });
    final equipment = await db.customSelect('SELECT id FROM equipment').get();
    expect(
      equipment.map((r) => r.read<String>('id')),
      containsAll(['e-bcd', 'e-smb', 'e-reg']),
      reason: 'a rebuilt equipment table would cascade the links away',
    );
  });

  test('foreign keys are on after the ladder, so a cascade would have '
      'fired if a rung had dropped the parent', () async {
    final db = AppDatabase(strandedAt(199));
    addTearDown(db.close);

    expect(
      await db
          .customSelect('PRAGMA foreign_keys')
          .getSingle()
          .then((r) => r.read<int>('foreign_keys')),
      1,
      reason: 'the previous test would pass vacuously with cascades disabled',
    );
  });
}
