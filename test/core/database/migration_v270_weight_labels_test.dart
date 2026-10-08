import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v270: dive_weights.label and weight_preset_entries.label, a diver's
/// own name for a weight such as "Top pocket" (issue #956).
void main() {
  /// A database at [version] whose weight tables lack the column, each with
  /// one row.
  NativeDatabase setupDb({int version = 269}) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $version');
      rawDb.execute(
        'CREATE TABLE dive_weights (id TEXT NOT NULL PRIMARY KEY, '
        'dive_id TEXT NOT NULL, weight_type TEXT NOT NULL, '
        'amount_kg REAL NOT NULL, '
        "notes TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL)",
      );
      rawDb.execute(
        'CREATE TABLE weight_preset_entries (id TEXT NOT NULL PRIMARY KEY, '
        'preset_id TEXT NOT NULL, weight_type TEXT NOT NULL, '
        "amount_kg REAL NOT NULL, notes TEXT NOT NULL DEFAULT '', "
        'sort_order INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL)',
      );
      rawDb.execute(
        'INSERT INTO dive_weights '
        '(id, dive_id, weight_type, amount_kg, notes, created_at) '
        "VALUES ('w1', 'd1', 'belt', 4.0, 'from subsurface', 1)",
      );
      rawDb.execute(
        'INSERT INTO weight_preset_entries '
        '(id, preset_id, weight_type, amount_kg, created_at) '
        "VALUES ('e1', 'p1', 'trimWeights', 1.0, 1)",
      );
    },
  );

  test('v270 is at or below the current schema version and in the ladder', () {
    // Relaxed once v271 (certification currency, #2267) landed on top; the
    // newest rung owns the exact assertions.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(270));
    expect(AppDatabase.migrationVersions, contains(270));
    expect(
      AppDatabase.migrationStepCount(269),
      AppDatabase.migrationStepCount(270) + 1,
    );
  });

  test('the columns are defaulted, so the sync floor does not move', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, 240);
  });

  test('upgrading from v269 names nothing and keeps notes', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    final weight = await db
        .customSelect('SELECT notes, label FROM dive_weights')
        .getSingle();
    expect(weight.read<String>('label'), '');
    expect(weight.read<String>('notes'), 'from subsurface');
    final entry = await db
        .customSelect('SELECT label FROM weight_preset_entries')
        .getSingle();
    expect(entry.read<String>('label'), '');
  });

  test(
    'a database already stamped 270 without the columns gains them on open',
    () async {
      // A renumbered rung, or a restore of a file whose tables predate it:
      // the beforeOpen backstop adds what the ladder did not.
      final db = AppDatabase(setupDb(version: 270));
      addTearDown(db.close);
      final weight = await db
          .customSelect('SELECT label FROM dive_weights')
          .getSingle();
      expect(weight.read<String>('label'), '');
      final entry = await db
          .customSelect('SELECT label FROM weight_preset_entries')
          .getSingle();
      expect(entry.read<String>('label'), '');
    },
  );
}
