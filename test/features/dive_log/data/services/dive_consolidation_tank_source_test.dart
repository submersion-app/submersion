import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/data/services/dive_consolidation_service.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';

/// Issue #2440: two file imports of one dive, neither with a dive computer,
/// consolidated. Both log the same cylinder, and before the tank series
/// carried a source the two recordings could not be told apart: every reader
/// interleaved them into a line that zigzags between two clocks.
void main() {
  late AppDatabase db;
  late DiveRepository diveRepo;
  late DiveConsolidationService service;
  late TankPressureSeriesRepository tankSeries;

  List<TankPressureSample> recording({
    required int offset,
    double start = 200,
  }) => [
    for (var i = 0; i <= 240; i++)
      TankPressureSample(timestamp: offset + i * 10, pressure: start - i * 0.5),
  ];

  Future<void> seedFileImport(
    String diveId,
    String tankId,
    DateTime entry,
  ) async {
    await diveRepo.createDive(
      domain.Dive(
        id: diveId,
        dateTime: entry,
        entryTime: entry,
        runtime: const Duration(minutes: 40),
        maxDepth: 30,
        tanks: [
          domain.DiveTank(
            id: tankId,
            gasMix: const domain.GasMix(o2: 21, he: 0),
            order: 0,
          ),
        ],
      ),
    );
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: 'src-$diveId',
            diveId: diveId,
            importedAt: DateTime.utc(2026, 7, 18),
            createdAt: DateTime.utc(2026, 7, 18),
          ).copyWith(isPrimary: const Value(true)),
        );
  }

  setUp(() async {
    db = await setUpTestDatabase();
    diveRepo = DiveRepository();
    service = DiveConsolidationService(diveRepo);
    tankSeries = TankPressureSeriesRepository();

    await seedFileImport('f1', 'tank-f1', DateTime.utc(2026, 7, 18, 18));
    await seedFileImport('f2', 'tank-f2', DateTime.utc(2026, 7, 18, 18, 1));
    // As the UDDF importer writes them: before the source row exists, so
    // unattributed, then stamped with the import's source.
    await tankSeries.insertSeries(
      diveId: 'f1',
      tankId: 'tank-f1',
      samples: recording(offset: 0),
      now: 1000,
    );
    await tankSeries.stampSourceWhereNull('f1', 'src-f1', now: 1000);
    await tankSeries.insertSeries(
      diveId: 'f2',
      tankId: 'tank-f2',
      samples: recording(offset: 0, start: 197.5),
      now: 1000,
    );
    await tankSeries.stampSourceWhereNull('f2', 'src-f2', now: 1000);
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('consolidation keeps each source on its own series', () async {
    await service.apply(targetDiveId: 'f1', secondaryDiveIds: ['f2']);

    final series = await tankSeries.getSeriesForDive('f1');
    expect(series, hasLength(2));
    expect(series.map((s) => s.tankId).toSet(), {'tank-f1'});
    final sourceIds = series.map((s) => s.sourceId).toSet();
    expect(sourceIds, hasLength(2));
    expect(sourceIds, contains('src-f1'));
    expect(sourceIds, isNot(contains(null)));
  });

  test('the dive reads one recording, never the two interleaved', () async {
    await service.apply(targetDiveId: 'f1', secondaryDiveIds: ['f2']);

    final pressures = await TankPressureRepository().getTankPressuresForDive(
      'f1',
    );
    final points = pressures['tank-f1']!;
    expect(points, hasLength(241));
    // The primary source's recording, and nothing of the other one.
    expect(points.first.pressure, 200);
    for (var i = 1; i < points.length; i++) {
      expect(points[i].pressure, lessThanOrEqualTo(points[i - 1].pressure));
    }
  });

  test('a secondary with several sources keeps its unattributed series '
      'unattributed', () async {
    // f2 holds a second source, and one of its series never got one: it
    // could be either source's recording, so it stays unattributed rather
    // than being grouped with the primary source's series.
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: 'src-f2-other',
            diveId: 'f2',
            importedAt: DateTime.utc(2026, 7, 18),
            createdAt: DateTime.utc(2026, 7, 18),
          ),
        );
    await tankSeries.insertSeries(
      diveId: 'f2',
      tankId: 'tank-f2',
      samples: recording(offset: 7, start: 196),
      now: 1000,
    );

    await service.apply(targetDiveId: 'f1', secondaryDiveIds: ['f2']);

    final series = await tankSeries.getSeriesForDive('f1');
    expect(series, hasLength(3));
    expect(series.where((s) => s.sourceId == null), hasLength(1));
  });

  test('a target with several sources keeps its unattributed series '
      'unattributed', () async {
    // f1 already holds a second source from an earlier consolidation, so an
    // unattributed series of it could be either one's.
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: 'src-older',
            diveId: 'f1',
            importedAt: DateTime.utc(2026, 7, 18),
            createdAt: DateTime.utc(2026, 7, 18),
          ),
        );
    final legacy = await tankSeries.insertSeries(
      diveId: 'f1',
      tankId: 'tank-f1',
      samples: recording(offset: 5000),
      now: 1000,
    );

    await service.apply(targetDiveId: 'f1', secondaryDiveIds: ['f2']);

    final row = (await tankSeries.getRowsForDives([
      'f1',
    ])).firstWhere((r) => r.id == legacy);
    expect(row.sourceId, isNull);
  });

  test('a secondary series naming a source the secondary lacks is left '
      'unattributed', () async {
    // f2 holds two sources, and one of its series points at a source of
    // another dive (f3's). Nothing on f2 says which of its own sources
    // recorded it, so it is as unknown as an unattributed series, and is
    // not handed to f2's primary source.
    await seedFileImport('f3', 'tank-f3', DateTime.utc(2026, 7, 19, 9));
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: 'src-f2-other',
            diveId: 'f2',
            importedAt: DateTime.utc(2026, 7, 18),
            createdAt: DateTime.utc(2026, 7, 18),
          ),
        );
    final stray = await tankSeries.insertSeries(
      diveId: 'f2',
      tankId: 'tank-f2',
      sourceId: 'src-f3',
      samples: recording(offset: 7, start: 196),
      now: 1000,
    );

    await service.apply(targetDiveId: 'f1', secondaryDiveIds: ['f2']);

    final series = await tankSeries.getSeriesForDive('f1');
    expect(series, hasLength(3));
    final moved = series.singleWhere(
      (s) => s.samples.first.pressure == 196,
      orElse: () => fail('the series $stray did not move to f1'),
    );
    expect(moved.sourceId, isNull);
  });
}
