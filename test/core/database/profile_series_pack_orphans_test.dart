import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/profile_series_pack.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_series_identity.dart';

import '../../helpers/legacy_profile_fixtures.dart';

/// What the packer does with legacy rows whose parents are gone, and with
/// legacy tables that never had the identity columns.
void main() {
  const codec = ProfileSeriesCodec();

  /// A database at v182 whose legacy tables are empty at open. Rows are
  /// seeded through the raw handle afterwards, both because the beforeOpen
  /// backstop packs every unpacked dive and because the same open runs the
  /// v183 rung, which drops the two (still empty) legacy tables once it
  /// finds nothing left to pack; this recreates them on the open connection
  /// so seeding afterwards has a table to write into.
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

  void profileRow(
    sqlite3.Database raw,
    String id,
    String diveId, {
    String? computerId,
    String? sourceId,
  }) {
    raw.execute(
      'INSERT INTO dive_profiles (id, dive_id, computer_id, source_id, '
      'is_primary, timestamp, depth) VALUES (?, ?, ?, ?, 1, 0, 5.0)',
      [id, diveId, computerId, sourceId],
    );
  }

  group('orphans', () {
    test('skips a profile row whose dive is gone and counts it', () async {
      final open = await openLegacy();
      seedParents(open.raw);
      profileRow(open.raw, 'p1', 'd1', computerId: 'c1', sourceId: 's1');
      profileRow(open.raw, 'p2', 'ghost');

      final report = await packLegacyProfileRows(open.db, nowMs: 1);
      expect(report.profileSeries, 1);
      expect(report.skippedOrphans, 1);
      final series = await open.db
          .customSelect('SELECT dive_id FROM dive_profile_series')
          .get();
      expect(series.map((r) => r.read<String>('dive_id')), ['d1']);
    });

    test('nulls a dangling computer id rather than failing its key', () async {
      final open = await openLegacy();
      seedParents(open.raw);
      profileRow(open.raw, 'p1', 'd1', computerId: 'nope', sourceId: 's1');

      final report = await packLegacyProfileRows(open.db, nowMs: 1);
      expect(report.profileSeries, 1);
      expect(report.skippedOrphans, 0);
      final row = await open.db
          .customSelect('SELECT * FROM dive_profile_series')
          .getSingle();
      expect(row.readNullable<String>('computer_id'), isNull);
      expect(row.read<String>('source_id'), 's1');
      expect(
        row.read<String>('id'),
        profileSeriesMigratedId(
          diveId: 'd1',
          computerId: null,
          sourceId: 's1',
          isPrimary: true,
        ),
        reason: 'the derived id uses the resolved members',
      );
    });

    test('skips a pressure row whose tank is gone and counts it', () async {
      final open = await openLegacy();
      seedParents(open.raw);
      // Both of d1's tanks are matched exactly, so there is nothing for the
      // stale id to be adopted into and it stays an orphan. When a tank IS
      // free the packer adopts instead of skipping; see
      // profile_series_pack_orphan_tank_test.dart.
      open.raw.execute(
        'INSERT INTO tank_pressure_profiles (id, dive_id, tank_id, timestamp, '
        "pressure, computer_id) VALUES ('q1', 'd1', 't1', 0, 200.0, 'c1'), "
        "('q3', 'd1', 't2', 0, 205.0, 'c1'), "
        "('q2', 'd1', 'no-tank', 0, 210.0, NULL)",
      );

      final report = await packLegacyProfileRows(open.db, nowMs: 1);
      expect(report.tankSeries, 2);
      expect(report.skippedOrphans, 1);
      final series = await open.db
          .customSelect(
            'SELECT tank_id FROM tank_pressure_series ORDER BY tank_id',
          )
          .get();
      expect(series.map((r) => r.read<String>('tank_id')), ['t1', 't2']);
    });
  });

  group('legacy tables without identity columns', () {
    /// Rebuilds `dive_profiles` with [columns] only, on an already open
    /// database. A real database restored from a very old backup reaches the
    /// packer in this shape. The rebuild happens after [openLegacy] has
    /// already recreated the (full) legacy table and reuses its open
    /// executor, so this only has to narrow the column set before seeding.
    Future<({AppDatabase db, sqlite3.Database raw})> rebuiltProfiles(
      String columns,
    ) async {
      final open = await openLegacy();
      open.raw.execute("INSERT INTO dives (id) VALUES ('d1')");
      open.raw.execute('DROP TABLE dive_profiles');
      open.raw.execute('CREATE TABLE dive_profiles ($columns)');
      return open;
    }

    test(
      'packs a table with no identity columns as one primary series',
      () async {
        final open = await rebuiltProfiles(
          'id TEXT NOT NULL PRIMARY KEY, dive_id TEXT NOT NULL, '
          'timestamp INTEGER NOT NULL, depth REAL NOT NULL',
        );
        open.raw.execute(
          'INSERT INTO dive_profiles (id, dive_id, timestamp, depth) VALUES '
          "('p1', 'd1', 0, 0.0), ('p2', 'd1', 5, 4.0)",
        );
        final db = open.db;

        final report = await packLegacyProfileRows(db, nowMs: 1);
        expect(report.profileSeries, 1);
        final row = await db
            .customSelect('SELECT * FROM dive_profile_series')
            .getSingle();
        expect(row.readNullable<String>('computer_id'), isNull);
        expect(row.readNullable<String>('source_id'), isNull);
        expect(row.read<int>('is_primary'), 1);
        expect(codec.decode(row.read('samples')), [
          const ProfileSample(timestamp: 0, depth: 0.0),
          const ProfileSample(timestamp: 5, depth: 4.0),
        ]);
      },
    );

    test('skips a table that has no timestamp column at all', () async {
      final open = await rebuiltProfiles(
        'id TEXT NOT NULL PRIMARY KEY, dive_id TEXT NOT NULL, '
        'depth REAL NOT NULL',
      );
      open.raw.execute(
        "INSERT INTO dive_profiles (id, dive_id, depth) VALUES ('p1', 'd1', 3)",
      );
      final db = open.db;

      final report = await packLegacyProfileRows(db, nowMs: 1);
      expect(report.profileSeries, 0);
      final count = await db
          .customSelect('SELECT COUNT(*) AS n FROM dive_profile_series')
          .getSingle();
      expect(count.read<int>('n'), 0);
    });
  });
}
