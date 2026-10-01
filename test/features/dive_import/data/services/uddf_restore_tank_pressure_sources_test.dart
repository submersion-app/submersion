// Restoring each tank pressure series under the source that recorded it
// (issue #2492), through the same parse the import wizard runs.
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_source_export.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_tank_pressure_export.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart'
    as domain;

import '../../../../helpers/tank_pressure_export_fixtures.dart';
import '../../../../helpers/test_database.dart';
import '../../../../helpers/uddf_restore.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
  });

  tearDown(() async => tearDownTestDatabase());

  const tank = DiveTank(id: 'tank-1', gasMix: GasMix(o2: 32));
  final dive = Dive(
    id: 'dive-a',
    diveNumber: 1,
    dateTime: DateTime.utc(2026, 3, 1, 9),
    tanks: const [tank],
    profile: const [
      DiveProfilePoint(timestamp: 0, depth: 0),
      DiveProfilePoint(timestamp: 10, depth: 12),
      DiveProfilePoint(timestamp: 20, depth: 12),
    ],
  );

  DiveSourceExport source(
    String id,
    int ordinal, {
    bool primary = false,
    String? computerId,
    String? computerSerial,
  }) => DiveSourceExport(
    id: id,
    diveId: 'dive-a',
    ordinal: ordinal,
    isPrimary: primary,
    importedAt: DateTime.utc(2026, 3, 1, 12),
    createdAt: DateTime.utc(2026, 3, 1, 12),
    sourceFileName: '$id.uddf',
    computerId: computerId,
    computerModel: computerSerial == null ? null : 'Perdix',
    computerSerial: computerSerial,
  );

  Future<void> restore(String xml) async {
    const diverId = 'diver-restore-tank-sources';
    final now = DateTime.now();
    await DiverRepository().createDiver(
      domain.Diver(
        id: diverId,
        name: 'Test Diver',
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await restoreUddfDives(xml, diverId: diverId);
  }

  /// Every restored series as (source file name, samples), source first.
  Future<List<(String?, String)>> restoredSeries() async {
    final diveId = (await db.select(db.dives).getSingle()).id;
    final names = {
      for (final row in await db.select(db.diveDataSources).get())
        row.id: row.sourceFileName,
    };
    final all = await TankPressureSeriesRepository().getSeriesForDive(diveId);
    final result = [
      for (final s in all)
        (
          s.sourceId == null ? null : names[s.sourceId],
          [for (final p in s.samples) '${p.timestamp}:${p.pressure}'].join(' '),
        ),
    ]..sort((a, b) => (a.$1 ?? '').compareTo(b.$1 ?? ''));
    return result;
  }

  test(
    'restores one series per source, each under its restored source',
    () async {
      final xml = await UddfFullExportService().generateAllDataXmlForTest(
        dives: [dive],
        dataSources: [
          source('src-primary', 0, primary: true),
          source('src-other', 1),
        ],
        diveTankPressures: {
          'dive-a': DiveTankPressureExport(
            primarySourceId: 'src-primary',
            series: [
              testTankSeries(
                's-other',
                diveId: 'dive-a',
                tankId: 'tank-1',
                sourceId: 'src-other',
                samples: [(1, 201.5), (11, 191.5)],
              ),
              testTankSeries(
                's-primary',
                diveId: 'dive-a',
                tankId: 'tank-1',
                sourceId: 'src-primary',
                samples: [(0, 200), (10, 190)],
              ),
            ],
          ),
        },
      );

      await restore(xml);

      expect(await restoredSeries(), [
        ('src-other.uddf', '1:201.5 11:191.5'),
        ('src-primary.uddf', '0:200.0 10:190.0'),
      ]);
    },
  );

  test('keeps a series no source owned unattributed', () async {
    final xml = await UddfFullExportService().generateAllDataXmlForTest(
      dives: [dive],
      dataSources: [
        source('src-primary', 0, primary: true),
        source('src-other', 1),
      ],
      diveTankPressures: {
        'dive-a': DiveTankPressureExport(
          primarySourceId: 'src-primary',
          series: [
            testTankSeries(
              's-primary',
              diveId: 'dive-a',
              tankId: 'tank-1',
              sourceId: 'src-primary',
              samples: [(0, 200), (10, 190)],
            ),
            testTankSeries(
              's-legacy',
              diveId: 'dive-a',
              tankId: 'tank-1',
              sourceId: null,
              samples: [(30, 170)],
            ),
          ],
        ),
      },
    );

    await restore(xml);

    expect(await restoredSeries(), [
      (null, '30:170.0'),
      ('src-primary.uddf', '0:200.0 10:190.0'),
    ]);
  });

  test('a single-source backup still restores the sample pressures', () async {
    // No extension block for one source: the waypoints carry the readings
    // and the lone restored source adopts them.
    final xml = await UddfFullExportService().generateAllDataXmlForTest(
      dives: [dive],
      dataSources: [source('src-primary', 0, primary: true)],
      diveTankPressures: {
        'dive-a': DiveTankPressureExport(
          primarySourceId: 'src-primary',
          series: [
            testTankSeries(
              's-primary',
              diveId: 'dive-a',
              tankId: 'tank-1',
              sourceId: 'src-primary',
              samples: [(0, 200), (10, 190)],
            ),
          ],
        ),
      },
    );

    await restore(xml);

    expect(await restoredSeries(), [('src-primary.uddf', '0:200.0 10:190.0')]);
  });

  test('restores each tank row under its own source and computer', () async {
    // Two computers' copies of their cylinders on one consolidated dive
    // (#2716), plus a hand-added tank that belongs to neither.
    final twoComputers = dive.copyWith(
      tanks: const [
        DiveTank(
          id: 'tank-1',
          gasMix: GasMix(o2: 32),
          sourceId: 'src-primary',
          computerId: 'comp-a',
        ),
        DiveTank(
          id: 'tank-2',
          gasMix: GasMix(o2: 50),
          order: 1,
          sourceId: 'src-other',
          computerId: 'comp-b',
        ),
        DiveTank(id: 'tank-3', gasMix: GasMix(), order: 2),
      ],
    );
    final xml = await UddfFullExportService().generateAllDataXmlForTest(
      dives: [twoComputers],
      dataSources: [
        source(
          'src-primary',
          0,
          primary: true,
          computerId: 'comp-a',
          computerSerial: 'SN-A',
        ),
        source('src-other', 1, computerId: 'comp-b', computerSerial: 'SN-B'),
      ],
    );

    await restore(xml);

    final sourceNames = {
      for (final row in await db.select(db.diveDataSources).get())
        row.id: row.sourceFileName,
    };
    final serials = {
      for (final row in await db.select(db.diveComputers).get())
        row.id: row.serialNumber,
    };
    final tanks = await (db.select(
      db.diveTanks,
    )..orderBy([(t) => OrderingTerm.asc(t.tankOrder)])).get();
    expect(
      [
        for (final t in tanks)
          (
            t.tankOrder,
            t.sourceId == null ? null : sourceNames[t.sourceId],
            t.computerId == null ? null : serials[t.computerId],
          ),
      ],
      [
        (0, 'src-primary.uddf', 'SN-A'),
        (1, 'src-other.uddf', 'SN-B'),
        (2, null, null),
      ],
    );
  });
}
