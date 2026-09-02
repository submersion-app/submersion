import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/profile_series_pack.dart';
import 'package:submersion/core/database/profile_series_pack_coverage.dart';

import '../../helpers/legacy_profile_fixtures.dart';

/// Two ways the v183 rung could turn a recoverable problem into a database
/// that never opens or a table dropped with samples still only in it.
void main() {
  int scalar(sqlite3.Database raw, String sql) =>
      raw.select(sql).first.values.first! as int;

  bool tableExists(sqlite3.Database raw, String name) => raw.select(
    "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
    [name],
  ).isNotEmpty;

  group('the rung survives a failing purge or drop', () {
    test(
      'a sync_records the purge cannot read does not wedge the ladder',
      () async {
        final raw = sqlite3.sqlite3.openInMemory();
        addTearDown(raw.close);
        legacyDdlAt180(raw, userVersion: 182);
        seedParents(raw);
        seedProfiles(raw);
        // A bookkeeping table without the column the purge deletes on. It
        // stands in for anything these two steps can throw (a busy lock from
        // the second isolate, a shape the residue count cannot read): the
        // point is that the rung must not let it escape onUpgrade, because
        // _runUpgradeLadder rethrows and the ladder then replays the same
        // throw on every relaunch.
        raw.execute(
          'CREATE TABLE sync_records (id TEXT NOT NULL PRIMARY KEY, '
          'record_id TEXT NOT NULL)',
        );

        final db = AppDatabase(
          NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
        );
        addTearDown(db.close);

        await expectLater(db.customSelect('SELECT 1').get(), completes);
        expect(scalar(raw, 'PRAGMA user_version'), 183);
        // The pack itself ran, so no samples are stranded by the failure.
        expect(scalar(raw, 'SELECT COUNT(*) AS n FROM dive_profile_series'), 4);
      },
    );
  });

  group('a dive packs atomically', () {
    test('a group that cannot be written rolls back its whole dive', () async {
      final raw = sqlite3.sqlite3.openInMemory();
      addTearDown(raw.close);
      legacyDdlAt180(raw, userVersion: 182);
      seedParents(raw);
      // Two groups of ONE dive and ONE computer, differing only by source.
      // That is the shape the residue count cannot see: it asks per (dive,
      // computer), so if the first group commits alone the second's rows
      // read as covered and v183 drops the table with them still only in
      // it.
      raw.execute(
        'INSERT INTO dive_profiles (id, dive_id, computer_id, source_id, '
        'is_primary, timestamp, depth) VALUES '
        "('a1', 'd1', 'c1', 's1', 1, 0, 1.0), "
        "('a2', 'd1', 'c1', 's1', 1, 10, 2.0), "
        "('b1', 'd1', 'c1', 's2', 0, 0, 3.0), "
        "('b2', 'd1', 'c1', 's2', 0, 10, 4.0)",
      );

      final db = AppDatabase(
        NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
      );
      addTearDown(db.close);
      await db.customSelect('SELECT 1').get();
      // The rung packed both groups on open; start from empty so the
      // trigger below sees the pack this test is about.
      raw.execute('DELETE FROM dive_profile_series');
      createLegacyProfileTables(raw);
      raw.execute(
        'INSERT INTO dive_profiles (id, dive_id, computer_id, source_id, '
        'is_primary, timestamp, depth) VALUES '
        "('a1', 'd1', 'c1', 's1', 1, 0, 1.0), "
        "('a2', 'd1', 'c1', 's1', 1, 10, 2.0), "
        "('b1', 'd1', 'c1', 's2', 0, 0, 3.0), "
        "('b2', 'd1', 'c1', 's2', 0, 10, 4.0)",
      );
      // Stands in for the process dying between two group inserts: the
      // second group cannot be written, the first already has been.
      raw.execute('''
        CREATE TRIGGER refuse_second_group
        BEFORE INSERT ON dive_profile_series
        WHEN NEW.source_id = 's2'
        BEGIN SELECT RAISE(ABORT, 'no second group'); END
      ''');

      final report = await packLegacyProfileRows(db, nowMs: 1);

      expect(report.failedDives, 1);
      expect(
        scalar(raw, 'SELECT COUNT(*) AS n FROM dive_profile_series'),
        0,
        reason: 'the first group must not survive its dive failing',
      );
      // With nothing packed, the legacy rows are all still awaiting a pack,
      // which is what keeps the table from being dropped.
      final residue = await countLegacyRowsAwaitingPack(db);
      expect(residue.profiles, 4);
      expect(tableExists(raw, 'dive_profiles'), isTrue);
    });
  });
}
