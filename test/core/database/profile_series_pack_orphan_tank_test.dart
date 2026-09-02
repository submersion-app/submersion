import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/profile_series_pack.dart';
import 'package:submersion/core/database/profile_series_pack_coverage.dart';

import '../../helpers/legacy_profile_fixtures.dart';

/// A reparse, re-import or consolidation can regenerate a dive's tanks with
/// fresh uuids while its pressure rows keep the old tank id. The v102 rung
/// heals that in the legacy table, and `GasAnalysisService` tolerates it at
/// read time by adopting an orphan into an unmatched tank of the same dive.
///
/// The packer has to do the same. `tank_pressure_series.tank_id` is a NOT
/// NULL foreign key, so an orphan cannot be packed as it stands, and every
/// reader now reads series: skipping it drops the pressure curve and the
/// per-cylinder SAC of every such dive, and its rows keep the legacy table
/// alive forever because the residue count can never cover them.
void main() {
  Future<({AppDatabase db, sqlite3.Database raw})> openLegacy() async {
    final raw = sqlite3.sqlite3.openInMemory();
    addTearDown(raw.close);
    legacyDdlAt180(raw, userVersion: 182);
    final db = AppDatabase(
      NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
    );
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();
    createLegacyProfileTables(raw);
    return (db: db, raw: raw);
  }

  void pressure(
    sqlite3.Database raw,
    String id,
    String tankId,
    int timestamp,
    double bar,
  ) {
    raw.execute(
      'INSERT INTO tank_pressure_profiles (id, dive_id, tank_id, timestamp, '
      'pressure, computer_id) VALUES (?, ?, ?, ?, ?, NULL)',
      [id, 'd1', tankId, timestamp, bar],
    );
  }

  Future<List<String>> seriesTanks(AppDatabase db) async {
    final rows = await db
        .customSelect(
          'SELECT tank_id FROM tank_pressure_series ORDER BY tank_id',
        )
        .get();
    return [for (final r in rows) r.read<String>('tank_id')];
  }

  test('a stale tank id is adopted by an unmatched tank of the dive', () async {
    final open = await openLegacy();
    seedParents(open.raw); // d1 with tanks t1 and t2, neither matched below
    pressure(open.raw, 'q1', 'regenerated', 0, 200.0);
    pressure(open.raw, 'q2', 'regenerated', 60, 190.0);

    final report = await packLegacyProfileRows(open.db, nowMs: 1);

    expect(report.tankSeries, 1);
    expect(report.skippedOrphans, 0);
    expect(await seriesTanks(open.db), ['t1']);
    // Nothing is left behind, so the legacy table can finally be dropped.
    final residue = await countLegacyRowsAwaitingPack(open.db);
    expect(residue.tanks, 0);
  });

  test('orphans pair with unmatched tanks in first-sample order', () async {
    final open = await openLegacy();
    seedParents(open.raw);
    // The later orphan must take the later tank, matching the v102 rung.
    pressure(open.raw, 'q1', 'stale-b', 120, 180.0);
    pressure(open.raw, 'q2', 'stale-a', 0, 200.0);

    await packLegacyProfileRows(open.db, nowMs: 1);

    final rows = await open.db
        .customSelect(
          'SELECT tank_id, start_timestamp FROM tank_pressure_series '
          'ORDER BY start_timestamp',
        )
        .get();
    expect([for (final r in rows) r.read<String>('tank_id')], ['t1', 't2']);
  });

  test('a tank still present keeps its own rows', () async {
    final open = await openLegacy();
    seedParents(open.raw);
    pressure(open.raw, 'q1', 't2', 0, 210.0);
    pressure(open.raw, 'q2', 'stale', 0, 200.0);

    final report = await packLegacyProfileRows(open.db, nowMs: 1);

    expect(report.tankSeries, 2);
    // t2 matched exactly; the orphan takes the one tank left over.
    expect(await seriesTanks(open.db), ['t1', 't2']);
  });

  test('an orphan with no tank left to adopt is still skipped', () async {
    final open = await openLegacy();
    open.raw.execute("INSERT INTO dives (id) VALUES ('d1')");
    open.raw.execute(
      "INSERT INTO dive_tanks (id, dive_id) VALUES ('t1', 'd1')",
    );
    pressure(open.raw, 'q1', 't1', 0, 210.0);
    pressure(open.raw, 'q2', 'stale', 0, 200.0);

    final report = await packLegacyProfileRows(open.db, nowMs: 1);

    expect(report.tankSeries, 1);
    expect(report.skippedOrphans, 1);
    expect(await seriesTanks(open.db), ['t1']);
  });

  test('a pressure row whose dive is gone is still skipped', () async {
    final open = await openLegacy();
    seedParents(open.raw);
    open.raw.execute(
      'INSERT INTO tank_pressure_profiles (id, dive_id, tank_id, timestamp, '
      "pressure, computer_id) VALUES ('q1', 'ghost', 't1', 0, 200.0, NULL)",
    );

    final report = await packLegacyProfileRows(open.db, nowMs: 1);

    expect(report.tankSeries, 0);
    expect(report.skippedOrphans, 1);
  });
}
