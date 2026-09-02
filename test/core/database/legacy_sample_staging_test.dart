import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/legacy_sample_staging.dart';
import 'package:submersion/core/database/profile_series_pack.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_series_identity.dart';

import '../../helpers/test_database.dart';

/// [ensureLegacyStagingTables] / [stageLegacyProfileRows] /
/// [stageLegacyTankRows] / [packStagedLegacyRows]: the receive-side shim that
/// replaces the dropped `dive_profiles` / `tank_pressure_profiles` tables
/// (v183, plan 2e task 2) for an older peer's row-per-sample rows.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    final now = DateTime.now().millisecondsSinceEpoch;
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
            name: 'Comp 1',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: 'src-1',
            diveId: 'dive-1',
            computerId: const Value('comp-1'),
            isPrimary: const Value(true),
            importedAt: DateTime.fromMillisecondsSinceEpoch(now),
            createdAt: DateTime.fromMillisecondsSinceEpoch(now),
          ),
        );
    await db
        .into(db.diveTanks)
        .insert(DiveTanksCompanion.insert(id: 'tank-a', diveId: 'dive-1'));
  });

  tearDown(tearDownTestDatabase);

  test('wire rows land in the staging table with snake_case columns', () async {
    await ensureLegacyStagingTables(db);
    final n = await stageLegacyProfileRows(db, [
      {
        'id': 'p1',
        'diveId': 'dive-1',
        'computerId': null,
        'sourceId': null,
        'isPrimary': true,
        'timestamp': 0,
        'depth': 0.0,
        'ppO2': 1.2,
        'o2SensorMv1': 55,
        'heartRateSource': 'chest',
        'unknownKey': 42,
      },
      {
        'id': 'p2',
        'diveId': 'dive-1',
        'isPrimary': true,
        'timestamp': 30,
        'depth': 12.0,
      },
    ]);
    expect(n, 2);
    final rows = await db
        .customSelect(
          'SELECT id, dive_id, is_primary, pp_o2, o2_sensor_mv1, '
          'heart_rate_source FROM dive_profiles_inbound ORDER BY timestamp',
        )
        .get();
    expect(rows.first.data['pp_o2'], 1.2);
    expect(rows.first.data['o2_sensor_mv1'], 55);
    expect(rows.first.data['heart_rate_source'], 'chest');
    expect(rows.first.data['is_primary'], 1);
  });

  test(
    'packStagedLegacyRows packs into series and empties the staging tables',
    () async {
      await ensureLegacyStagingTables(db);
      await stageLegacyProfileRows(db, [
        {
          'id': 'p1',
          'diveId': 'dive-1',
          'isPrimary': true,
          'timestamp': 0,
          'depth': 0.0,
        },
        {
          'id': 'p2',
          'diveId': 'dive-1',
          'isPrimary': true,
          'timestamp': 30,
          'depth': 12.0,
        },
      ]);
      await stageLegacyTankRows(db, [
        {
          'id': 't1',
          'diveId': 'dive-1',
          'tankId': 'tank-a',
          'timestamp': 0,
          'pressure': 200.0,
        },
      ]);
      final report = await packStagedLegacyRows(db);
      expect(report.profileSeries, 1);
      expect(report.tankSeries, 1);
      final series = await ProfileSeriesRepository().getSeriesForDive('dive-1');
      expect(series.single.samples.map((s) => s.depth), [0.0, 12.0]);
      expect(
        series.single.id,
        profileSeriesMigratedId(
          diveId: 'dive-1',
          computerId: null,
          sourceId: null,
          isPrimary: true,
        ),
      );
      expect(
        (await db
                .customSelect('SELECT COUNT(*) AS n FROM dive_profiles_inbound')
                .getSingle())
            .data['n'],
        0,
      );
      expect(
        (await db
                .customSelect(
                  'SELECT COUNT(*) AS n FROM tank_pressure_profiles_inbound',
                )
                .getSingle())
            .data['n'],
        0,
      );
    },
  );

  test('a staged row whose dive has not arrived yet stays staged and packs '
      'on the next call', () async {
    await ensureLegacyStagingTables(db);
    await stageLegacyProfileRows(db, [
      {
        'id': 'p-early',
        'diveId': 'dive-2',
        'isPrimary': true,
        'timestamp': 0,
        'depth': 5.0,
      },
    ]);

    // dive-2 is not here yet: during a restore the dive rows can arrive in a
    // later changeset than its samples. The pack skips the row as an orphan,
    // and emptying the staging table would discard the only copy the peer
    // ever sends.
    final first = await packStagedLegacyRows(db);
    expect(first.profileSeries, 0);
    expect(first.skippedOrphans, 1);
    expect(
      (await db
              .customSelect('SELECT COUNT(*) AS n FROM dive_profiles_inbound')
              .getSingle())
          .data['n'],
      1,
    );

    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'dive-2',
            diveDateTime: now,
            createdAt: now,
            updatedAt: now,
          ),
        );

    final second = await packStagedLegacyRows(db);
    expect(second.profileSeries, 1);
    expect(
      (await ProfileSeriesRepository().getSeriesForDive(
        'dive-2',
      )).single.samples.single.depth,
      5.0,
    );
    expect(
      (await db
              .customSelect('SELECT COUNT(*) AS n FROM dive_profiles_inbound')
              .getSingle())
          .data['n'],
      0,
    );
  });

  test('a dive that already has a series ignores staged rows, and the staging '
      'is still emptied', () async {
    await ProfileSeriesRepository().insertSeries(
      diveId: 'dive-1',
      samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
      now: 1000,
    );
    final before = (await ProfileSeriesRepository().getSeriesForDive(
      'dive-1',
    )).single;

    await ensureLegacyStagingTables(db);
    await stageLegacyProfileRows(db, [
      {
        'id': 'p-stale',
        'diveId': 'dive-1',
        'isPrimary': true,
        'timestamp': 0,
        'depth': 99.0,
      },
    ]);
    final report = await packStagedLegacyRows(db);
    expect(report.profileSeries, 0);

    final after = (await ProfileSeriesRepository().getSeriesForDive(
      'dive-1',
    )).single;
    expect(after.id, before.id);
    expect(
      after.samples.map((s) => s.depth),
      before.samples.map((s) => s.depth),
    );
    expect(
      (await db
              .customSelect('SELECT COUNT(*) AS n FROM dive_profiles_inbound')
              .getSingle())
          .data['n'],
      0,
    );
  });

  test(
    'a 450-row stage crosses the chunk boundaries and keeps every row',
    () async {
      await ensureLegacyStagingTables(db);
      // 450 rows is three statements at the 200-row chunk size, so both
      // boundaries are exercised. Every third row omits `temperature`, an
      // optional codec column, which must stage as null rather than shifting
      // the bound values of the rest of the chunk.
      final rows = [
        for (var i = 0; i < 450; i++)
          <String, dynamic>{
            'id': 'p$i',
            'diveId': 'dive-1',
            'isPrimary': true,
            'timestamp': i,
            'depth': i / 10.0,
            if (i % 3 != 0) 'temperature': 20.0 - i / 100.0,
          },
      ];
      expect(await stageLegacyProfileRows(db, rows), 450);

      final count = await db
          .customSelect('SELECT COUNT(*) AS n FROM dive_profiles_inbound')
          .getSingle();
      expect(count.data['n'], 450);
      final nullTemps = await db
          .customSelect(
            'SELECT COUNT(*) AS n FROM dive_profiles_inbound '
            'WHERE temperature IS NULL',
          )
          .getSingle();
      expect(nullTemps.data['n'], 150);
      // A row from the last, short chunk still carries its own values.
      final last = await db
          .customSelect(
            'SELECT depth, temperature, is_primary FROM dive_profiles_inbound '
            'WHERE id = ?',
            variables: [const Variable<String>('p449')],
          )
          .getSingle();
      expect(last.data['depth'], 44.9);
      expect(last.data['temperature'], closeTo(15.51, 0.0001));
      expect(last.data['is_primary'], 1);

      final report = await packStagedLegacyRows(db);
      expect(report.profileSeries, 1);
      final series = await ProfileSeriesRepository().getSeriesForDive('dive-1');
      expect(series.single.samples, hasLength(450));
    },
  );

  test('a wire row with no is_primary key takes the column default', () async {
    await ensureLegacyStagingTables(db);
    expect(
      await stageLegacyProfileRows(db, [
        {'id': 'p1', 'diveId': 'dive-1', 'timestamp': 0, 'depth': 0.0},
      ]),
      1,
    );
    final row = await db
        .customSelect(
          'SELECT is_primary, ndl FROM dive_profiles_inbound WHERE id = ?',
          variables: [const Variable<String>('p1')],
        )
        .getSingle();
    expect(row.data['is_primary'], 1);
    expect(row.data['ndl'], isNull);
  });

  test('ensureLegacyStagingTables is idempotent and survives a missing legacy '
      'table', () async {
    await ensureLegacyStagingTables(db);
    await ensureLegacyStagingTables(db);
    expect(await packStagedLegacyRows(db), isA<ProfilePackReport>());
  });

  test(
    'a pack failure leaves the staged rows in place for the next apply',
    () async {
      await ensureLegacyStagingTables(db);
      await stageLegacyProfileRows(db, [
        {
          'id': 'p1',
          'diveId': 'dive-1',
          'isPrimary': true,
          'timestamp': 0,
          'depth': 0.0,
        },
        {
          'id': 'p2',
          'diveId': 'dive-1',
          'isPrimary': true,
          'timestamp': 30,
          'depth': 12.0,
        },
      ]);

      // The malformed-dive_profile_series trick from backstop_resilience_test
      // and legacy_sample_entities_inbound_test: a series table missing the
      // summary/samples columns makes every packer INSERT fail.
      await db.customStatement('DROP TABLE dive_profile_series');
      await db.customStatement('''
          CREATE TABLE dive_profile_series (
            id TEXT NOT NULL PRIMARY KEY,
            dive_id TEXT NOT NULL,
            computer_id TEXT,
            source_id TEXT,
            is_primary INTEGER NOT NULL DEFAULT 1
          )
        ''');

      // The packer isolates each dive, so this no longer throws: it reports
      // the dive it could not write and moves on. What matters is unchanged,
      // and is what this test is really about: the dive got no series row,
      // so the staged rows are not cleared and remain the only copy.
      final failed = await packStagedLegacyRows(db);
      expect(failed.failedDives, 1);
      expect(failed.profileSeries, 0);

      final staged = await db
          .customSelect('SELECT COUNT(*) AS n FROM dive_profiles_inbound')
          .getSingle();
      expect(
        staged.data['n'],
        2,
        reason: 'a failed pack must not discard the only copy of the rows',
      );

      // Repair the table (mirrors a real migration/backstop self-heal) and
      // confirm the next call packs the still-staged rows and empties them.
      await db.customStatement('DROP TABLE dive_profile_series');
      await db.customStatement('''
          CREATE TABLE dive_profile_series (
            id TEXT NOT NULL PRIMARY KEY,
            dive_id TEXT NOT NULL,
            computer_id TEXT,
            source_id TEXT,
            is_primary INTEGER NOT NULL DEFAULT 1,
            sample_count INTEGER NOT NULL,
            start_timestamp INTEGER NOT NULL,
            end_timestamp INTEGER NOT NULL,
            max_depth REAL NOT NULL,
            first_depth REAL NOT NULL,
            last_depth REAL NOT NULL,
            has_deco_type INTEGER NOT NULL DEFAULT 0,
            has_deco_stop INTEGER NOT NULL DEFAULT 0,
            has_positive_ceiling INTEGER NOT NULL DEFAULT 0,
            codec_version INTEGER NOT NULL,
            samples BLOB NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            hlc TEXT
          )
        ''');

      final report = await packStagedLegacyRows(db);
      expect(report.profileSeries, 1);
      final series = await ProfileSeriesRepository().getSeriesForDive('dive-1');
      expect(series.single.samples.map((s) => s.depth), [0.0, 12.0]);
      final after = await db
          .customSelect('SELECT COUNT(*) AS n FROM dive_profiles_inbound')
          .getSingle();
      expect(after.data['n'], 0);
    },
  );
}
