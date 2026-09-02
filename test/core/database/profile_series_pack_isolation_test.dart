import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/profile_series_pack.dart';

import '../../helpers/legacy_profile_fixtures.dart';

/// One unreadable legacy VALUE must cost its own row and nothing more.
///
/// The rungs and the beforeOpen backstop catch whatever the packer throws,
/// which keeps the database openable but leaves every dive the packer had
/// not reached yet unpacked, on this open and on every later one. Nothing
/// reads `dive_profiles` after v183, so those profiles would be invisible
/// while the dive still looked whole.
///
/// An unreadable timestamp, depth or pressure means the ROW holds no
/// sample, which is what a null in the same column has always meant, so it
/// is counted in `skippedRows` and the rest of the dive still packs. Costing
/// the whole dive instead only looked like a deferred retry: the dive was
/// held back for a later open that reads the same byte and fails the same
/// way, so its good samples were never visible either. Failure at DIVE
/// granularity is still real, for a group the codec or the database refuses
/// to write, and is pinned by `migration_v183_rung_resilience_test.dart`
/// and `backstop_resilience_test.dart`.
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

  /// A row whose `depth` holds text. SQLite's REAL affinity keeps a
  /// non-numeric string as TEXT, the way a bit-rotted or hand-repaired
  /// table would, and the packer reads it as no sample at all.
  void unreadableProfileRow(sqlite3.Database raw, String id, String diveId) {
    raw.execute(
      'INSERT INTO dive_profiles (id, dive_id, computer_id, source_id, '
      "is_primary, timestamp, depth) VALUES (?, ?, 'c1', 's1', 1, 0, 'deep')",
      [id, diveId],
    );
  }

  void profileRow(sqlite3.Database raw, String id, String diveId) {
    raw.execute(
      'INSERT INTO dive_profiles (id, dive_id, computer_id, source_id, '
      "is_primary, timestamp, depth) VALUES (?, ?, 'c1', 's1', 1, 0, 5.0)",
      [id, diveId],
    );
  }

  Future<List<String>> packedDiveIds(AppDatabase db, String table) async {
    final rows = await db
        .customSelect('SELECT dive_id FROM $table ORDER BY dive_id')
        .get();
    return [for (final r in rows) r.read<String>('dive_id')];
  }

  test('an unreadable row does not stop the dives after it', () async {
    final open = await openLegacy();
    seedParents(open.raw);
    // d1 sorts first, and the scan walks dives in dive_id order.
    unreadableProfileRow(open.raw, 'p1', 'd1');
    profileRow(open.raw, 'p2', 'd2');

    final report = await packLegacyProfileRows(open.db, nowMs: 1);

    expect(report.profileSeries, 1);
    expect(report.failedDives, 0);
    expect(report.skippedRows, 1);
    expect(await packedDiveIds(open.db, 'dive_profile_series'), ['d2']);
  });

  test(
    'an unreadable profile row does not stop the tank pressure pack',
    () async {
      final open = await openLegacy();
      seedParents(open.raw);
      unreadableProfileRow(open.raw, 'p1', 'd1');
      open.raw.execute(
        'INSERT INTO tank_pressure_profiles (id, dive_id, tank_id, timestamp, '
        "pressure, computer_id) VALUES ('tp1', 'd1', 't1', 0, 200.0, 'c1')",
      );

      final report = await packLegacyProfileRows(open.db, nowMs: 1);

      expect(report.failedDives, 0);
      expect(report.skippedRows, 1);
      expect(report.tankSeries, 1);
      expect(await packedDiveIds(open.db, 'tank_pressure_series'), ['d1']);
    },
  );

  test(
    'an unreadable tank row does not stop the tank dives after it',
    () async {
      final open = await openLegacy();
      seedParents(open.raw);
      open.raw.execute(
        "INSERT INTO dive_tanks (id, dive_id) VALUES ('t3', 'd2')",
      );
      open.raw.execute(
        'INSERT INTO tank_pressure_profiles (id, dive_id, tank_id, timestamp, '
        "pressure, computer_id) VALUES ('tp1', 'd1', 't1', 0, 'shallow', 'c1')",
      );
      open.raw.execute(
        'INSERT INTO tank_pressure_profiles (id, dive_id, tank_id, timestamp, '
        "pressure, computer_id) VALUES ('tp2', 'd2', 't3', 0, 200.0, 'c1')",
      );

      final report = await packLegacyProfileRows(open.db, nowMs: 1);

      expect(report.failedDives, 0);
      expect(report.skippedRows, 1);
      expect(report.tankSeries, 1);
      expect(await packedDiveIds(open.db, 'tank_pressure_series'), ['d2']);
    },
  );

  test('a clean pack reports no failures', () async {
    final open = await openLegacy();
    seedParents(open.raw);
    profileRow(open.raw, 'p1', 'd1');
    profileRow(open.raw, 'p2', 'd2');

    final report = await packLegacyProfileRows(open.db, nowMs: 1);

    expect(report.profileSeries, 2);
    expect(report.failedDives, 0);
  });
}
