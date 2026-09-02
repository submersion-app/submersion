import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:submersion/core/database/database.dart';

import '../../helpers/legacy_profile_fixtures.dart';
import 'migration_v183_drop_legacy_tables_test.dart'
    show syncBookkeepingDdl, seedSyncBookkeeping;

/// The bookkeeping purge is unconditional by design: those rows describe two
/// entities this build no longer exports, so they are dead whatever else is
/// true of the database. Gating it on the legacy TABLES being present tied it
/// to something unrelated, and a device that reached 183 by a parallel
/// branch's rung of the same number (which dropped the tables itself) then
/// carried the rows forever: pending sync_records that can never be
/// acknowledged, and tombstones riding every base publish.
void main() {
  List<String> entityTypes(sqlite3.Database raw, String table) => raw
      .select('SELECT entity_type FROM $table ORDER BY entity_type')
      .map((r) => r['entity_type'] as String)
      .toList();

  test(
    'a 183 database with no legacy tables still purges the bookkeeping',
    () async {
      final raw = sqlite3.sqlite3.openInMemory();
      addTearDown(raw.close);
      // Already at 183 with the legacy tables gone: what a parallel branch's
      // own rung of the same number leaves behind.
      legacyDdlAt180(raw, userVersion: 183);
      seedParents(raw);
      raw.execute('DROP TABLE dive_profiles');
      raw.execute('DROP TABLE tank_pressure_profiles');
      syncBookkeepingDdl(raw);
      seedSyncBookkeeping(raw);

      final db = AppDatabase(
        NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
      );
      addTearDown(db.close);
      await db.customSelect('SELECT 1').get();

      expect(entityTypes(raw, 'sync_records'), ['dives']);
      // The tombstones stay: the receive-side shim still needs them to stop
      // a peer below the floor resurrecting a row this device deleted.
      expect(entityTypes(raw, 'deletion_log'), [
        'diveProfiles',
        'dives',
        'tankPressureProfiles',
      ]);
    },
  );
}
