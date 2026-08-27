import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// v170 renames diver_settings.sac_unit to gas_consumption_display, maps its
/// unit spellings onto lanes, and points saved dive-table layouts that named
/// the old sacRate column at the lane the diver was seeing (spec D4).
///
/// Stamped at 169 so only this rung runs; 165-169 belong to other branches.
NativeDatabase _dbAt169() {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 169');
      rawDb.execute('''
        CREATE TABLE diver_settings (
          id TEXT NOT NULL PRIMARY KEY,
          diver_id TEXT NOT NULL,
          sac_unit TEXT NOT NULL DEFAULT 'litersPerMin',
          created_at INTEGER,
          updated_at INTEGER
        )
      ''');
      rawDb.execute('''
        CREATE TABLE view_configs (
          id TEXT NOT NULL PRIMARY KEY,
          diver_id TEXT NOT NULL,
          view_mode TEXT NOT NULL,
          config_json TEXT NOT NULL,
          updated_at INTEGER NOT NULL,
          hlc TEXT
        )
      ''');
      rawDb.execute(
        "INSERT INTO diver_settings (id, diver_id, sac_unit) VALUES "
        "('ds-vol', 'd-vol', 'litersPerMin'), "
        "('ds-prs', 'd-prs', 'pressurePerMin'), "
        "('ds-odd', 'd-odd', 'furlongs')",
      );
      const layout =
          '{"columns":[{"field":"diveNumber"},{"field":"sacRate"}],'
          '"sortField":"sacRate"}';
      rawDb.execute(
        "INSERT INTO view_configs (id, diver_id, view_mode, config_json, "
        "updated_at, hlc) VALUES "
        "('vc-vol', 'd-vol', 'table', '$layout', 1, 'h-vol'), "
        "('vc-prs', 'd-prs', 'table', '$layout', 1, 'h-prs'), "
        "('vc-odd', 'd-odd', 'table', '$layout', 1, 'h-odd')",
      );
    },
  );
}

Future<String> _display(AppDatabase db, String id) async {
  final row = await db
      .customSelect(
        "SELECT gas_consumption_display AS d FROM diver_settings "
        "WHERE id = '$id'",
      )
      .getSingle();
  return row.read<String>('d');
}

Future<({String json, String? hlc})> _layout(AppDatabase db, String id) async {
  final row = await db
      .customSelect(
        "SELECT config_json, hlc FROM view_configs WHERE id = '$id'",
      )
      .getSingle();
  return (json: row.read<String>('config_json'), hlc: row.read<String?>('hlc'));
}

void main() {
  test('v170 is in the migration ladder and is the compatibility floor', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(170));
    expect(AppDatabase.migrationVersions, contains(170));
    // Renaming a synced column and changing its value set are both breaking
    // under the #1089 rules, so peers below 170 are held until they update.
    expect(AppDatabase.minimumCompatibleSchemaVersion, 170);
  });

  test(
    'a fresh database has gas_consumption_display defaulting to both',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final cols = await db
          .customSelect("PRAGMA table_info('diver_settings')")
          .get();
      final byName = {for (final c in cols) c.read<String>('name'): c};
      expect(byName.containsKey('gas_consumption_display'), isTrue);
      expect(byName.containsKey('sac_unit'), isFalse);
      expect(
        byName['gas_consumption_display']!.read<String?>('dflt_value'),
        contains('both'),
      );
    },
  );

  test(
    'the 169 -> 170 upgrade renames the column and maps the values',
    () async {
      final db = AppDatabase(_dbAt169());
      addTearDown(db.close);

      final cols = await db
          .customSelect("PRAGMA table_info('diver_settings')")
          .get();
      final names = cols.map((c) => c.read<String>('name')).toSet();
      expect(names, contains('gas_consumption_display'));
      expect(names, isNot(contains('sac_unit')));

      expect(await _display(db, 'ds-vol'), 'rmv');
      expect(await _display(db, 'ds-prs'), 'sac');
      // An unrecognized value cannot fail the migration; it lands on both.
      expect(await _display(db, 'ds-odd'), 'both');
    },
  );

  test(
    'saved layouts follow the lane the diver was on, without an HLC bump',
    () async {
      final db = AppDatabase(_dbAt169());
      addTearDown(db.close);

      final vol = await _layout(db, 'vc-vol');
      expect(
        vol.json,
        '{"columns":[{"field":"diveNumber"},{"field":"rmv"}],'
        '"sortField":"rmv"}',
      );
      expect(vol.hlc, 'h-vol');

      final prs = await _layout(db, 'vc-prs');
      expect(prs.json, contains('"field":"sac"'));
      expect(prs.json, contains('"sortField":"sac"'));
      expect(prs.json, isNot(contains('sacRate')));
      expect(prs.hlc, 'h-prs');

      // The unknown-value diver landed on both; their old column shows SAC.
      final odd = await _layout(db, 'vc-odd');
      expect(odd.json, contains('"field":"sac"'));
      expect(odd.hlc, 'h-odd');
    },
  );

  test(
    'the column assert is idempotent and heals a stranded database',
    () async {
      // A database that reached 170 by restore or sync-adopt never runs
      // onUpgrade; beforeOpen re-asserts the rename. Opening a database that
      // already carries the current version proves the assert does not try
      // to rename or add twice.
      final native = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('''
          CREATE TABLE diver_settings (
            id TEXT NOT NULL PRIMARY KEY,
            diver_id TEXT NOT NULL,
            sac_unit TEXT NOT NULL DEFAULT 'litersPerMin',
            created_at INTEGER,
            updated_at INTEGER
          )
        ''');
          rawDb.execute(
            "INSERT INTO diver_settings (id, diver_id, sac_unit) "
            "VALUES ('ds1', 'd1', 'litersPerMin')",
          );
        },
      );
      final db = AppDatabase(native);
      addTearDown(db.close);

      expect(await _display(db, 'ds1'), 'rmv');
      final cols = await db
          .customSelect("PRAGMA table_info('diver_settings')")
          .get();
      final names = cols.map((c) => c.read<String>('name')).toList();
      expect(names.where((n) => n == 'gas_consumption_display').length, 1);
    },
  );

  test('the asserts no-op when the tables are absent', () async {
    final native = NativeDatabase.memory(
      setup: (rawDb) => rawDb.execute('CREATE TABLE unrelated (id TEXT)'),
    );
    final db = AppDatabase(native);
    addTearDown(db.close);

    await expectLater(db.customSelect('SELECT 1').get(), completes);
  });
}
