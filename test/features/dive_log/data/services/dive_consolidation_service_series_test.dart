import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/data/services/dive_consolidation_service.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';

/// Series-first coverage of DiveConsolidationService: the copy step, the
/// null-computer tank series stamp, and undo. Mirrors the fixture in
/// dive_consolidation_service_test.dart but keeps every dive's profile
/// empty at seed time so createDive (series-only since an earlier 2c task)
/// never writes a primary series of its own to collide with the series
/// each test inserts explicitly.
void main() {
  late AppDatabase db;
  late DiveRepository diveRepo;
  late DiveConsolidationService service;
  late ProfileSeriesRepository profileSeries;
  late TankPressureSeriesRepository tankSeries;

  domain.DiveTank tank(
    String id, {
    required double o2,
    double he = 0,
    double? start,
    double? end,
    int order = 0,
  }) => domain.DiveTank(
    id: id,
    gasMix: domain.GasMix(o2: o2, he: he),
    startPressure: start,
    endPressure: end,
    order: order,
  );

  Future<void> seedDive(
    String id, {
    required DateTime entry,
    String? computerId,
    String? serial,
    List<domain.DiveTank> tanks = const [],
  }) async {
    await diveRepo.createDive(
      domain.Dive(
        id: id,
        dateTime: entry,
        entryTime: entry,
        runtime: const Duration(minutes: 30),
        maxDepth: 18,
        diveComputerSerial: serial,
        tanks: tanks,
      ),
    );
    if (computerId != null) {
      await (db.update(db.dives)..where((t) => t.id.equals(id))).write(
        DivesCompanion(computerId: Value(computerId)),
      );
    }
  }

  Future<void> seedDataSource(
    String id, {
    required String diveId,
    String? computerId,
    bool isPrimary = true,
  }) async {
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: id,
            diveId: diveId,
            importedAt: DateTime.utc(2026, 7, 1),
            createdAt: DateTime.utc(2026, 7, 1),
          ).copyWith(
            isPrimary: Value(isPrimary),
            computerId: Value(computerId),
          ),
        );
  }

  Future<String> copiedSourceId() async =>
      (await (db.select(db.diveDataSources)..where(
                (t) => t.diveId.equals('t') & t.computerId.equals('comp-s'),
              ))
              .getSingle())
          .id;

  setUp(() async {
    db = await setUpTestDatabase();
    diveRepo = DiveRepository();
    service = DiveConsolidationService(diveRepo);
    profileSeries = ProfileSeriesRepository();
    tankSeries = TankPressureSeriesRepository();

    // Foreign keys stay ON (the default connection state): the profile
    // series / tank pressure series tables cascade-delete on their dive's
    // removal, and the "apply" test below relies on that cascade to prove
    // the secondary's series are gone, not merely orphaned.
    for (final id in ['comp-t', 'comp-s']) {
      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion.insert(
              id: id,
              name: id,
              createdAt: 0,
              updatedAt: 0,
            ),
          );
    }

    await seedDive(
      't',
      entry: DateTime.utc(2026, 7, 1, 9),
      computerId: 'comp-t',
      serial: 'SER-T',
      tanks: [tank('tank-t1', o2: 21)],
    );
    await seedDataSource('src-t', diveId: 't', computerId: 'comp-t');
    await seedDive(
      's',
      entry: DateTime.utc(2026, 7, 1, 9, 1),
      computerId: 'comp-s',
      serial: 'SER-S',
    );
    await seedDataSource('src-s', diveId: 's', computerId: 'comp-s');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('apply copies the secondary series onto the target as demoted, re-owned '
      'and offset', () async {
    final st = await profileSeries.insertSeries(
      diveId: 't',
      computerId: 'comp-t',
      sourceId: 'src-t',
      samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
      now: 1000,
    );
    await profileSeries.insertSeries(
      diveId: 's',
      computerId: 'comp-s',
      sourceId: 'src-s',
      samples: const [ProfileSample(timestamp: 0, depth: 2.0)],
      now: 1000,
    );
    await profileSeries.insertSeries(
      diveId: 's',
      sourceId: 'src-s',
      isPrimary: false,
      samples: const [ProfileSample(timestamp: 0, depth: 3.0)],
      now: 1000,
    );

    await service.apply(targetDiveId: 't', secondaryDiveIds: ['s']);

    final rows = await profileSeries.getSeriesForDive('t');
    expect(rows.where((s) => s.isPrimary).map((s) => s.id), [st]);
    final copied = rows.where((s) => s.id != st).toList();
    expect(copied, hasLength(2));
    expect(copied.every((s) => !s.isPrimary), isTrue);
    expect(copied.map((s) => s.computerId).toSet(), {
      'comp-s',
    }, reason: 'a null computer takes the secondary source computer');
    final source = await copiedSourceId();
    expect(copied.every((s) => s.sourceId == source), isTrue);
    final offset =
        (await (db.select(
          db.diveDataSources,
        )..where((t) => t.id.equals(source))).getSingle()).timeOffsetSeconds ??
        0;
    expect(copied.map((s) => s.samples.single.timestamp).toSet(), {offset});
    expect(await profileSeries.getSeriesForDive('s'), isEmpty);
  });

  test('apply stamps the target computer on the target null-computer tank '
      'series', () async {
    final id = await tankSeries.insertSeries(
      diveId: 't',
      tankId: 'tank-t1',
      samples: const [TankPressureSample(timestamp: 0, pressure: 200.0)],
      now: 1000,
    );

    await service.apply(targetDiveId: 't', secondaryDiveIds: ['s']);

    final row = (await tankSeries.getRowsForDives([
      't',
    ])).firstWhere((r) => r.id == id);
    expect(row.computerId, 'comp-t');
  });

  test('undo tombstones the copied series, keeps the originals and restores '
      'the secondary rows', () async {
    await profileSeries.insertSeries(
      diveId: 't',
      computerId: 'comp-t',
      sourceId: 'src-t',
      samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
      now: 1000,
    );
    await profileSeries.insertSeries(
      diveId: 's',
      computerId: 'comp-s',
      sourceId: 'src-s',
      samples: const [ProfileSample(timestamp: 0, depth: 2.0)],
      now: 1000,
    );
    final before = await profileSeries.getRowsForDives(['t', 's']);

    final outcome = await service.apply(
      targetDiveId: 't',
      secondaryDiveIds: ['s'],
    );
    final copiedIds = (await profileSeries.getRowsForDives([
      't',
    ])).map((r) => r.id).where((id) => !before.any((r) => r.id == id)).toSet();
    await service.undo(outcome.snapshot);

    final after = await profileSeries.getRowsForDives(['t', 's']);
    // Compared as nested Lists rather than Records: a Uint8List (the
    // samples blob) has no structural `==`, and a Record's own `==`
    // defers to each field's `==`, so two byte-identical blobs read back
    // from separate queries would never compare equal packed into a
    // Record. `package:matcher`'s `equals` recurses through every nested
    // List/Iterable it finds, so unpacking `samples` with `.toList()`
    // makes the comparison reach the individual bytes instead.
    List<List<Object?>> summarize(List<DiveProfileSeriesRow> rows) => [
      for (final r in rows)
        [
          r.id,
          r.diveId,
          r.computerId,
          r.sourceId,
          r.isPrimary,
          r.samples.toList(),
        ],
    ];
    expect(summarize(after), summarize(before));
    final tombstones = await db.select(db.deletionLog).get();
    expect(
      tombstones
          .where((t) => t.entityType == 'diveProfileSeries')
          .map((t) => t.recordId)
          .toSet(),
      copiedIds,
    );
    expect(
      tombstones.any((t) => before.any((r) => r.id == t.recordId)),
      isFalse,
    );
  });
}
