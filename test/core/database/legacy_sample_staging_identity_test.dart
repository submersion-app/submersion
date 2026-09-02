import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/legacy_sample_staging.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';

import '../../helpers/test_database.dart';

/// A dive can be half packed. This device holds a series for one computer
/// while a peer below v183 still publishes row-per-sample rows for that dive
/// from two computers, and the staged rows are the only copy: the real
/// legacy tables are gone at v183 and the peer never re-sends.
///
/// So "this dive has a series" is not the question the pack or the staging
/// clear can ask. Both have to ask it per identity, the way the residue
/// count that gates dropping a legacy table already does.
void main() {
  late AppDatabase db;
  late ProfileSeriesRepository series;
  late TankPressureSeriesRepository tankSeries;
  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

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
    for (final id in ['comp-1', 'comp-2']) {
      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion.insert(
              id: id,
              name: id,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
    await db
        .into(db.diveTanks)
        .insert(DiveTanksCompanion.insert(id: 'tank-a', diveId: 'dive-1'));
  });

  tearDown(tearDownTestDatabase);

  test('a second computer\'s staged rows pack even though the dive already '
      'has a series', () async {
    // What this device already holds: dive-1's profile from comp-1.
    await series.insertSeries(
      diveId: 'dive-1',
      computerId: 'comp-1',
      samples: const [
        ProfileSample(timestamp: 0, depth: 1.0),
        ProfileSample(timestamp: 60, depth: 2.0),
      ],
      now: now,
    );
    // What the peer sends: the same dive from both computers.
    await ensureLegacyStagingTables(db);
    await stageLegacyProfileRows(db, [
      for (final (i, computerId) in [(0, 'comp-1'), (1, 'comp-2')])
        for (var t = 0; t < 2; t++)
          {
            'id': 'p$i-$t',
            'diveId': 'dive-1',
            'computerId': computerId,
            'isPrimary': true,
            'timestamp': t * 60,
            'depth': 10.0 + i + t,
          },
    ]);

    await packStagedLegacyRows(db);

    final all = await series.getSeriesForDive('dive-1');
    final byComputer = {for (final s in all) s.computerId: s};
    expect(
      byComputer.keys,
      containsAll(['comp-1', 'comp-2']),
      reason: "comp-2's rows were the only copy the peer will ever send",
    );
    // comp-1 keeps the series it already had, not a second copy of it.
    expect(all.where((s) => s.computerId == 'comp-1'), hasLength(1));
    expect(byComputer['comp-1']!.samples.map((s) => s.depth), [
      1.0,
      2.0,
    ], reason: 'the local series wins over the peer\'s row-per-sample copy');
    expect(byComputer['comp-2']!.samples.map((s) => s.depth), [11.0, 12.0]);
  });

  test('a staged group the dive has no series for still packs', () async {
    // What this device holds for dive-1: one primary, no computer, no
    // source (a manual dive or a file import).
    await series.insertSeries(
      diveId: 'dive-1',
      samples: const [
        ProfileSample(timestamp: 0, depth: 1.0),
        ProfileSample(timestamp: 60, depth: 2.0),
      ],
      now: now,
    );
    // What a peer below the floor sends: the same dive with a saved profile
    // edit, so its dive_profiles array carries TWO null-computer groups.
    // Coverage keyed on (dive, computer) alone calls both of them done.
    await ensureLegacyStagingTables(db);
    await stageLegacyProfileRows(db, [
      for (final (i, primary) in [(0, true), (1, false)])
        for (var t = 0; t < 2; t++)
          {
            'id': 'p$i-$t',
            'diveId': 'dive-1',
            'isPrimary': primary,
            'timestamp': t * 60,
            'depth': 20.0 + i + t,
          },
    ]);

    await packStagedLegacyRows(db);

    final all = await series.getSeriesForDive('dive-1');
    expect(
      all.where((s) => !s.isPrimary),
      hasLength(1),
      reason: "the peer's demoted group was never this device's to discard",
    );
    // The primary group IS covered by what this device already holds, and
    // the stored series wins: no second primary, and no overwrite.
    expect(all.where((s) => s.isPrimary), hasLength(1));
    expect(all.firstWhere((s) => s.isPrimary).samples.first.depth, 1.0);
  });

  test('a staged row whose identity is not yet covered survives a pack that '
      'cannot place it', () async {
    // The dive has not arrived, so nothing can pack; the rows must remain
    // for the next apply rather than be cleared.
    await ensureLegacyStagingTables(db);
    await stageLegacyProfileRows(db, [
      {
        'id': 'orphan',
        'diveId': 'not-here-yet',
        'isPrimary': true,
        'timestamp': 0,
        'depth': 4.0,
      },
    ]);

    await packStagedLegacyRows(db);

    final staged = await db
        .customSelect('SELECT COUNT(*) AS n FROM $kLegacyProfileStagingTable')
        .getSingle();
    expect(staged.data['n'], 1);
  });

  test(
    'a peer\'s pre-attribution pressures do not pack a second time',
    () async {
      // Consolidation and relink STAMP a computer onto series this device
      // wrote with computer_id NULL. An older peer still holds the same
      // readings unattributed and republishes them, so coverage keyed on an
      // exact computer match finds nothing and packs a duplicate. Nothing
      // collapses duplicate pressure series on read, so the cylinder's trace
      // carries every reading twice and per-cylinder SAC roughly halves.
      await tankSeries.insertSeries(
        diveId: 'dive-1',
        tankId: 'tank-a',
        computerId: 'comp-1',
        samples: const [
          TankPressureSample(timestamp: 0, pressure: 200.0),
          TankPressureSample(timestamp: 60, pressure: 190.0),
        ],
        now: now,
      );
      await ensureLegacyStagingTables(db);
      await stageLegacyTankRows(db, [
        for (var t = 0; t < 2; t++)
          {
            'id': 'tp-$t',
            'diveId': 'dive-1',
            'tankId': 'tank-a',
            'computerId': null,
            'timestamp': t * 60,
            'pressure': 200.0 - t * 10,
          },
      ]);

      await packStagedLegacyRows(db);

      expect(await tankSeries.getRowsForDives(['dive-1']), hasLength(1));
    },
  );

  test('a peer\'s pressures for a computer of their own still pack', () async {
    // The wildcard is only for a staged row that names NO computer. One
    // that names a different computer is a different source and has to
    // land.
    await tankSeries.insertSeries(
      diveId: 'dive-1',
      tankId: 'tank-a',
      computerId: 'comp-1',
      samples: const [TankPressureSample(timestamp: 0, pressure: 200.0)],
      now: now,
    );
    await ensureLegacyStagingTables(db);
    await stageLegacyTankRows(db, [
      for (var t = 0; t < 2; t++)
        {
          'id': 'tp2-$t',
          'diveId': 'dive-1',
          'tankId': 'tank-a',
          'computerId': 'comp-2',
          'timestamp': t * 60,
          'pressure': 150.0 - t,
        },
    ]);

    await packStagedLegacyRows(db);

    expect(await tankSeries.getRowsForDives(['dive-1']), hasLength(2));
  });

  test('a legacy tombstone removes the matching staged row', () async {
    // A peer below the floor deletes a sample row and publishes the
    // tombstone. Nothing local answers it: the row-per-sample tables are
    // gone at v183, so deleteRecord no-oped and the staged copy survived to
    // be packed on a later apply, resurrecting what the peer deleted.
    await ensureLegacyStagingTables(db);
    await stageLegacyProfileRows(db, [
      {
        'id': 'p-doomed',
        'diveId': 'dive-1',
        'isPrimary': true,
        'timestamp': 0,
        'depth': 5.0,
      },
      {
        'id': 'p-kept',
        'diveId': 'dive-1',
        'isPrimary': true,
        'timestamp': 60,
        'depth': 6.0,
      },
    ]);
    await stageLegacyTankRows(db, [
      {
        'id': 'q-doomed',
        'diveId': 'dive-1',
        'tankId': 'tank-a',
        'timestamp': 0,
        'pressure': 200.0,
      },
    ]);

    await SyncDataSerializer().deleteRecord('diveProfiles', 'p-doomed');
    await SyncDataSerializer().deleteRecord('tankPressureProfiles', 'q-doomed');

    final profiles = await db
        .customSelect('SELECT id FROM $kLegacyProfileStagingTable')
        .get();
    expect(profiles.map((r) => r.read<String>('id')), ['p-kept']);
    final tanks = await db
        .customSelect('SELECT COUNT(*) AS n FROM $kLegacyTankStagingTable')
        .getSingle();
    expect(tanks.read<int>('n'), 0);
  });

  test('a legacy tombstone with no staging tables is a no-op', () async {
    // The common case once every peer has upgraded: nothing staged, and the
    // TEMP tables were never created in this connection.
    await expectLater(
      SyncDataSerializer().deleteRecord('diveProfiles', 'p-none'),
      completes,
    );
  });

  test('staging outlives the connection that created it', () async {
    // The retry the shim promises spans applies, and the changeset cursor
    // that would offer these rows again is committed durably. A TEMP table
    // meant the promise ended at the next app launch: the row gone, the
    // peer convinced it had been delivered.
    await ensureLegacyStagingTables(db);
    await stageLegacyProfileRows(db, [
      {
        'id': 'p-orphan',
        'diveId': 'not-here-yet',
        'isPrimary': true,
        'timestamp': 0,
        'depth': 4.0,
      },
    ]);

    final durable = await db
        .customSelect(
          "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
          variables: [const Variable<String>(kLegacyProfileStagingTable)],
        )
        .get();
    expect(
      durable,
      isNotEmpty,
      reason: 'a TEMP table is absent from sqlite_master',
    );
  });

  test('a packed identity clears its staged rows', () async {
    await ensureLegacyStagingTables(db);
    await stageLegacyProfileRows(db, [
      {
        'id': 'p1',
        'diveId': 'dive-1',
        'computerId': 'comp-1',
        'isPrimary': true,
        'timestamp': 0,
        'depth': 7.0,
      },
    ]);

    await packStagedLegacyRows(db);

    final staged = await db
        .customSelect('SELECT COUNT(*) AS n FROM $kLegacyProfileStagingTable')
        .getSingle();
    expect(staged.data['n'], 0);
    expect(await series.getSeriesForDive('dive-1'), hasLength(1));
  });

  test(
    'a second tank\'s staged pressures pack alongside an existing series',
    () async {
      await db
          .into(db.diveTanks)
          .insert(DiveTanksCompanion.insert(id: 'tank-b', diveId: 'dive-1'));
      await tankSeries.insertSeries(
        diveId: 'dive-1',
        tankId: 'tank-a',
        samples: const [
          TankPressureSample(timestamp: 0, pressure: 200.0),
          TankPressureSample(timestamp: 60, pressure: 190.0),
        ],
        now: now,
      );
      await ensureLegacyStagingTables(db);
      await stageLegacyTankRows(db, [
        for (var t = 0; t < 2; t++)
          {
            'id': 'tp-b-$t',
            'diveId': 'dive-1',
            'tankId': 'tank-b',
            'timestamp': t * 60,
            'pressure': 150.0 - t,
          },
      ]);

      await packStagedLegacyRows(db);

      final rows = await tankSeries.getRowsForDives(['dive-1']);
      expect(rows.map((r) => r.tankId), containsAll(['tank-a', 'tank-b']));
    },
  );
}
