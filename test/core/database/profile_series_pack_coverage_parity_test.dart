import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/legacy_sample_staging.dart';
import 'package:submersion/core/database/profile_series_pack.dart';
import 'package:submersion/core/database/profile_series_pack_coverage.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';

import '../../helpers/legacy_profile_fixtures.dart';
import '../../helpers/test_database.dart';

/// Coverage ("is this legacy row already represented by a series row") is
/// answered twice, in two languages: in Dart by the packer, to decide
/// whether to WRITE a series, and in SQL by `legacyRowCoveredSql`, to decide
/// whether to DELETE the staged rows and whether a legacy table may be
/// dropped. The two have to give the same answer for every row.
///
/// Where they disagree the damage is always the same shape: the Dart side
/// calls a group covered so nothing is written, the SQL side calls it
/// uncovered so nothing is cleared, and the staging table never drains. The
/// pack then re-runs over those rows on every sync apply for the life of the
/// install while the peer's samples are never visible.
void main() {
  group('staging path', () {
    late AppDatabase db;
    late ProfileSeriesRepository series;
    late TankPressureSeriesRepository tankSeries;
    final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

    Future<int> stagedProfiles() async =>
        (await db
                .customSelect(
                  'SELECT COUNT(*) AS n FROM $kLegacyProfileStagingTable',
                )
                .getSingle())
            .read<int>('n');

    Future<int> stagedTanks() async =>
        (await db
                .customSelect(
                  'SELECT COUNT(*) AS n FROM $kLegacyTankStagingTable',
                )
                .getSingle())
            .read<int>('n');

    setUp(() async {
      db = await setUpTestDatabase();
      series = ProfileSeriesRepository();
      tankSeries = TankPressureSeriesRepository();
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: 'dive-1',
              diveDateTime: now,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion.insert(
              id: 'comp-1',
              name: 'comp-1',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.diveTanks)
          .insert(DiveTanksCompanion.insert(id: 'tank-a', diveId: 'dive-1'));
      await ensureLegacyStagingTables(db);
    });

    tearDown(tearDownTestDatabase);

    test('unattributed staged pressures drain against a series that names a '
        'computer', () async {
      // The motivating case the docstring names: consolidation's
      // stampComputerWhereNull put a computer on this device's series while a
      // peer below the floor still holds the same readings unattributed.
      await tankSeries.insertSeries(
        diveId: 'dive-1',
        tankId: 'tank-a',
        computerId: 'comp-1',
        samples: const [
          TankPressureSample(timestamp: 0, pressure: 200.0),
          TankPressureSample(timestamp: 60, pressure: 199.0),
        ],
        now: now,
      );
      await stageLegacyTankRows(db, [
        for (var t = 0; t < 2; t++)
          {
            'id': 'q$t',
            'diveId': 'dive-1',
            'tankId': 'tank-a',
            'timestamp': t * 60,
            'pressure': 200.0 - t,
          },
      ]);

      await packStagedLegacyRows(db);

      // The pack's in-Dart check treats the null computer as a wildcard and
      // writes nothing, so the clear has to agree and drain the rows. Today
      // the clear demands an exact match and leaves them staged forever.
      expect(await stagedTanks(), 0);
      expect(await hasStagedLegacyRows(db), isFalse);
    });

    test('a staged row naming a computer this device does not hold is not '
        'swallowed by the null wildcard', () async {
      // This device already holds dive-1 from comp-1.
      await series.insertSeries(
        diveId: 'dive-1',
        computerId: 'comp-1',
        samples: const [
          ProfileSample(timestamp: 0, depth: 1.0),
          ProfileSample(timestamp: 60, depth: 2.0),
        ],
        now: now,
      );
      // The peer's rows name a SECOND computer whose dive_computers row has
      // not merged here yet. `_resolvedParent` collapses that dangling id to
      // null, but the row still names a genuinely different source: the
      // wildcard is for a row that names NO computer, so these must be
      // packed as their own unattributed series rather than declared covered
      // by comp-1's.
      await stageLegacyProfileRows(db, [
        for (var t = 0; t < 2; t++)
          {
            'id': 'p$t',
            'diveId': 'dive-1',
            'computerId': 'comp-absent',
            'isPrimary': true,
            'timestamp': t * 60,
            'depth': 10.0 + t,
          },
      ]);

      await packStagedLegacyRows(db);

      final all = await series.getSeriesForDive('dive-1');
      expect(all, hasLength(2));
      final unattributed = all.where((s) => s.computerId == null);
      expect(unattributed, hasLength(1));
      expect(await stagedProfiles(), 0);
    });

    test('a staged is_primary SQLite cannot read as a number packs and '
        'drains', () async {
      // The staging table takes a peer's JSON. `is_primary` is declared
      // INTEGER NOT NULL, but SQLite's INTEGER affinity leaves text it
      // cannot convert as TEXT, so a peer that sends anything other than a
      // number or a bool lands a string in the column. Dart's `_boolOf`
      // reads any non-num as primary while the clear's
      // `CASE WHEN p.is_primary` applies SQLite's own truthiness and reads
      // it as demoted, so the two disagree and the rows never clear.
      await stageLegacyProfileRows(db, [
        for (var t = 0; t < 2; t++)
          {
            'id': 'p$t',
            'diveId': 'dive-1',
            'isPrimary': 'yes',
            'timestamp': t * 60,
            'depth': 5.0 + t,
          },
      ]);
      final stored = await db
          .customSelect(
            'SELECT typeof(is_primary) AS t FROM $kLegacyProfileStagingTable '
            'LIMIT 1',
          )
          .getSingle();
      expect(
        stored.read<String>('t'),
        'text',
        reason: 'the scenario needs the value to survive as text',
      );

      await packStagedLegacyRows(db);

      expect(await series.getSeriesForDive('dive-1'), hasLength(1));
      expect(await stagedProfiles(), 0);
      expect(await hasStagedLegacyRows(db), isFalse);
    });
  });

  group('migration path', () {
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

    test('an unreadable OPTIONAL field costs its own value, not the dive\'s '
        'whole profile', () async {
      // SQLite carries a storage class per VALUE, not per column, so a
      // REAL-affinity column can hold text SQLite could not convert, from a
      // hand-repaired or bit-rotted file. `timestamp` and `depth` are what
      // makes a sample, so a bad one there correctly costs the dive. Every
      // other column is one optional field of one sample, and dropping the
      // dive's ENTIRE profile over it is a permanent loss: nothing reads the
      // legacy tables after v183.
      final open = await openLegacy();
      seedParents(open.raw);
      open.raw.execute(
        'INSERT INTO dive_profiles (id, dive_id, timestamp, depth, pressure, '
        "is_primary) VALUES ('p1', 'd1', 0, 5.0, 'bar?', 1), "
        "('p2', 'd1', 60, 6.0, 190.0, 1)",
      );

      final report = await packLegacyProfileRows(open.db, nowMs: 1);

      expect(report.profileSeries, 1);
      expect(report.failedDives, 0);
      final samples = await open.db
          .customSelect(
            'SELECT sample_count FROM dive_profile_series WHERE dive_id = ?',
            variables: const [Variable<String>('d1')],
          )
          .getSingle();
      expect(samples.read<int>('sample_count'), 2);
    });

    test('a text depth costs its own row, not the dive', () async {
      // An unreadable timestamp or depth means the ROW holds no sample,
      // which is the same thing a null in either column means, and nulls
      // have always been stepped over as skippedRows. Failing the whole
      // dive instead is worse than it looks: the dive is kept back for "a
      // later open to retry", but the retry reads the same byte and fails
      // the same way, so the profile is never visible and the legacy table
      // that holds it can never be dropped.
      final open = await openLegacy();
      seedParents(open.raw);
      open.raw.execute(
        'INSERT INTO dive_profiles (id, dive_id, timestamp, depth, is_primary) '
        "VALUES ('bad', 'd1', 0, 'deep', 1), ('ok1', 'd1', 60, 6.0, 1), "
        "('ok2', 'd1', 120, 7.0, 1)",
      );

      final report = await packLegacyProfileRows(open.db, nowMs: 1);

      expect(report.failedDives, 0);
      expect(report.skippedRows, 1);
      expect(report.profileSeries, 1);
      final samples = await open.db
          .customSelect(
            'SELECT sample_count FROM dive_profile_series WHERE dive_id = ?',
            variables: const [Variable<String>('d1')],
          )
          .getSingle();
      expect(samples.read<int>('sample_count'), 2);
    });

    test('a text timestamp on a pressure row costs its own row, not the '
        'dive', () async {
      // The tank loop's twin of the case above. Reported by Copilot on
      // PR #1444.
      final open = await openLegacy();
      seedParents(open.raw);
      open.raw.execute(
        'INSERT INTO tank_pressure_profiles (id, dive_id, tank_id, timestamp, '
        "pressure, computer_id) VALUES ('q1', 'd1', 't1', 'noon', 200.0, NULL),"
        " ('q2', 'd1', 't1', 60, 190.0, NULL), "
        "('q3', 'd1', 't1', 120, 180.0, NULL)",
      );

      final report = await packLegacyProfileRows(open.db, nowMs: 1);

      expect(report.failedDives, 0);
      expect(report.skippedRows, 1);
      expect(report.tankSeries, 1);
    });

    test('a text timestamp on an ORPHAN pressure row does not abort the '
        'whole pack', () async {
      // The orphan adoption is a prologue: it runs before the first dive's
      // transaction and OUTSIDE the per-dive try/catch the rest of the
      // design rests on, so a throw there costs every dive, on this open
      // and on every later one. It reads MIN(timestamp) as an int, and
      // SQLite's MIN over a group whose only values are TEXT returns TEXT,
      // which drift parses and throws a FormatException on. Reported by
      // Copilot on PR #1444.
      final open = await openLegacy();
      seedParents(open.raw);
      // Orphan tank id, so the adoption pre-pass actually reaches this
      // group, with a timestamp SQLite kept as text.
      open.raw.execute(
        'INSERT INTO tank_pressure_profiles (id, dive_id, tank_id, timestamp, '
        "pressure, computer_id) VALUES ('q1', 'd1', 'gone', 'noon', 200.0, "
        'NULL)',
      );
      open.raw.execute(
        'INSERT INTO dive_profiles (id, dive_id, timestamp, depth, is_primary) '
        "VALUES ('p1', 'd1', 0, 5.0, 1), ('p2', 'd1', 60, 6.0, 1)",
      );

      final report = await packLegacyProfileRows(open.db, nowMs: 1);

      // The profile side has nothing wrong with it and must still land.
      expect(report.profileSeries, 1);
    });

    test('an unreadable row does not keep the legacy table alive', () async {
      // The residue count gates dropping the legacy table, and it already
      // excludes a row that can NEVER be packed so the table is not kept
      // forever. A row whose timestamp or depth SQLite cannot read as a
      // number is exactly that, the same as the null the count already
      // steps over.
      final open = await openLegacy();
      seedParents(open.raw);
      open.raw.execute(
        'INSERT INTO dive_profiles (id, dive_id, timestamp, depth, is_primary) '
        "VALUES ('bad', 'd1', 0, 'deep', 1), ('ok1', 'd1', 60, 6.0, 1)",
      );
      open.raw.execute(
        'INSERT INTO tank_pressure_profiles (id, dive_id, tank_id, timestamp, '
        "pressure, computer_id) VALUES ('q1', 'd1', 't1', 'noon', 200.0, NULL),"
        " ('q2', 'd1', 't1', 60, 190.0, NULL)",
      );

      await packLegacyProfileRows(open.db, nowMs: 1);

      final residue = await countLegacyRowsAwaitingPack(open.db);
      expect(residue.profiles, 0);
      expect(residue.tanks, 0);
    });
  });
}
