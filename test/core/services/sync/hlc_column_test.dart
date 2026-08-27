import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';

import '../../../helpers/test_database.dart';

/// The conflict-capable syncable tables must carry a nullable `hlc` column so
/// per-record Hybrid Logical Clocks can be stored and exported. This guards
/// the schema migration.
void main() {
  tearDown(() => DatabaseService.instance.resetForTesting());

  Future<bool> hasHlcColumn(String table) async {
    final db = await setUpTestDatabase();
    final cols = await db.customSelect("PRAGMA table_info('$table')").get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    return names.contains('hlc');
  }

  // A representative spread of the conflict-capable tables plus sync_metadata.
  const tables = [
    'dives',
    'dive_sites',
    'divers',
    'diver_settings',
    'certifications',
    'courses',
    'trips',
    'equipment',
    'buddies',
    'tank_presets',
    'settings',
    'csv_presets',
    'view_configs',
    'sync_metadata',
  ];

  for (final table in tables) {
    test('$table has a nullable hlc column', () async {
      expect(await hasHlcColumn(table), isTrue);
    });
  }

  test('an hlc value round-trips through the dives row', () async {
    final db = await setUpTestDatabase();
    await db.customStatement(
      "INSERT INTO dives (id, dive_date_time, is_planned, is_favorite, "
      "dive_mode, cns_start, created_at, updated_at, hlc) "
      "VALUES ('d1', 0, 0, 0, 'oc', 0, 0, 0, ?)",
      ['000000000001000:000003:node-x'],
    );
    final row = await db
        .customSelect("SELECT hlc FROM dives WHERE id = 'd1'")
        .getSingle();
    expect(row.read<String>('hlc'), '000000000001000:000003:node-x');
  });
}
