import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/data_quality/data/repositories/quality_findings_repository.dart';
import 'package:submersion/features/data_quality/data/services/quality_repair_executor.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../helpers/test_database.dart';

void main() {
  late DiveRepository diveRepo;
  late QualityFindingsRepository findingsRepo;
  late QualityRepairExecutor executor;

  setUp(() async {
    await setUpTestDatabase();
    // The executor queues a targeted rescan; keep it out of the test zone.
    QualityScanScheduler.enabled = false;
    diveRepo = DiveRepository();
    findingsRepo = QualityFindingsRepository();
    executor = QualityRepairExecutor();
  });
  tearDown(() {
    QualityScanScheduler.enabled = true;
    return tearDownTestDatabase();
  });

  Future<QualityFinding> seedFindingForDive(String diveId) async {
    final finding = QualityFinding(
      id: qualityFindingId(diveId: diveId, detectorId: 'clock_offset'),
      diveId: diveId,
      detectorId: 'clock_offset',
      detectorVersion: 1,
      category: QualityCategory.time,
      severity: QualitySeverity.warning,
      status: QualityStatus.open,
      createdAt: DateTime.utc(2026, 7, 17),
      updatedAt: DateTime.utc(2026, 7, 17),
    );
    await findingsRepo.applyScanResults(
      scopeDiveIds: {diveId},
      ranDetectorIds: {'clock_offset'},
      produced: [finding],
    );
    return finding;
  }

  test('shiftTimes shifts, resolves the finding, and undo restores', () async {
    final entry = DateTime.utc(2026, 7, 1, 10);
    await diveRepo.createDive(
      domain.Dive(id: 'd1', dateTime: entry, entryTime: entry),
    );
    final finding = await seedFindingForDive('d1');

    final undo = await executor.shiftTimes(
      diveIds: ['d1'],
      offset: const Duration(hours: -6),
      findingId: finding.id,
    );

    expect(
      (await diveRepo.getDiveById('d1'))!.entryTime,
      entry.subtract(const Duration(hours: 6)),
    );
    final resolved = await findingsRepo.getFindings(diveId: 'd1');
    expect(resolved.single.status, QualityStatus.resolved);

    await undo!();
    expect((await diveRepo.getDiveById('d1'))!.entryTime, entry);
  });

  test(
    'divesInSameImport falls back to just the dive without importId',
    () async {
      await diveRepo.createDive(
        domain.Dive(id: 'd1', dateTime: DateTime.utc(2026, 7, 1)),
      );
      expect(await executor.divesInSameImport('d1'), ['d1']);
    },
  );

  test('divesInSameImport returns every dive sharing the importId', () async {
    final t = DateTime.utc(2026, 7, 1);
    await diveRepo.createDive(
      domain.Dive(id: 'd1', dateTime: t, importId: 'imp1'),
    );
    await diveRepo.createDive(
      domain.Dive(id: 'd2', dateTime: t, importId: 'imp1'),
    );
    await diveRepo.createDive(
      domain.Dive(id: 'd3', dateTime: t, importId: 'other'),
    );

    expect((await executor.divesInSameImport('d1')).toSet(), {'d1', 'd2'});
  });

  Future<QualityStatus> statusOf(String diveId) async =>
      (await findingsRepo.getFindings(diveId: diveId)).single.status;

  group('applyProfileRepair', () {
    test('returns null when the primary profile is empty', () async {
      await diveRepo.createDive(
        domain.Dive(id: 'd1', dateTime: DateTime.utc(2026, 7, 1)),
      );
      final finding = await seedFindingForDive('d1');

      final undo = await executor.applyProfileRepair(
        diveId: 'd1',
        findingId: finding.id,
        compute: (pts) => pts,
      );

      expect(undo, isNull);
      // Early-exit leaves the finding untouched.
      expect(await statusOf('d1'), QualityStatus.open);
    });

    test('applies the computed profile, resolves, and undo restores', () async {
      final profile = [
        const domain.DiveProfilePoint(timestamp: 0, depth: 5),
        const domain.DiveProfilePoint(timestamp: 60, depth: 10),
        const domain.DiveProfilePoint(timestamp: 120, depth: 15),
      ];
      await diveRepo.createDive(
        domain.Dive(
          id: 'd1',
          dateTime: DateTime.utc(2026, 7, 1),
          profile: profile,
        ),
      );
      final finding = await seedFindingForDive('d1');

      final undo = await executor.applyProfileRepair(
        diveId: 'd1',
        findingId: finding.id,
        compute: (pts) => [for (final p in pts) p.copyWith(depth: p.depth * 2)],
      );

      expect(
        (await diveRepo.getDiveProfile('d1')).map((p) => p.depth).toList(),
        [10.0, 20.0, 30.0],
      );
      expect(await statusOf('d1'), QualityStatus.resolved);

      await undo!();
      expect(
        (await diveRepo.getDiveProfile('d1')).map((p) => p.depth).toList(),
        [5.0, 10.0, 15.0],
      );
    });
  });

  group('recomputeMetrics', () {
    test('returns null when the dive is missing', () async {
      // Returns before touching the finding, so no seeding is needed.
      final undo = await executor.recomputeMetrics(
        diveId: 'ghost',
        findingId: 'irrelevant',
      );
      expect(undo, isNull);
    });

    test('recomputes maxDepth/avgDepth and undo restores prior', () async {
      final profile = [
        const domain.DiveProfilePoint(timestamp: 0, depth: 10),
        const domain.DiveProfilePoint(timestamp: 60, depth: 20),
        const domain.DiveProfilePoint(timestamp: 120, depth: 30),
      ];
      await diveRepo.createDive(
        domain.Dive(
          id: 'd1',
          dateTime: DateTime.utc(2026, 7, 1),
          maxDepth: 99,
          avgDepth: 99,
          profile: profile,
        ),
      );
      final finding = await seedFindingForDive('d1');

      final undo = await executor.recomputeMetrics(
        diveId: 'd1',
        findingId: finding.id,
      );

      final fixed = (await diveRepo.getDiveById('d1'))!;
      expect(fixed.maxDepth, 30);
      expect(fixed.avgDepth, 20);
      expect(await statusOf('d1'), QualityStatus.resolved);

      await undo!();
      final restored = (await diveRepo.getDiveById('d1'))!;
      expect(restored.maxDepth, 99);
      expect(restored.avgDepth, 99);
    });
  });

  test(
    'swapTankRecordPressures writes swapped values, undo restores',
    () async {
      await diveRepo.createDive(
        domain.Dive(
          id: 'd1',
          dateTime: DateTime.utc(2026, 7, 1),
          tanks: const [
            domain.DiveTank(id: 't1', startPressure: 50, endPressure: 200),
          ],
        ),
      );
      final finding = await seedFindingForDive('d1');

      final undo = await executor.swapTankRecordPressures(
        diveId: 'd1',
        tankId: 't1',
        newStartBar: 200,
        newEndBar: 50,
        findingId: finding.id,
      );

      var tank = (await diveRepo.getDiveById('d1'))!.tanks.single;
      expect(tank.startPressure, 200);
      expect(tank.endPressure, 50);
      expect(await statusOf('d1'), QualityStatus.resolved);

      await undo!();
      tank = (await diveRepo.getDiveById('d1'))!.tanks.single;
      expect(tank.startPressure, 50);
      expect(tank.endPressure, 200);
    },
  );

  group('setTankRecordEndpoint', () {
    test('returns null when the tank is not found', () async {
      await diveRepo.createDive(
        domain.Dive(id: 'd1', dateTime: DateTime.utc(2026, 7, 1)),
      );
      final finding = await seedFindingForDive('d1');

      final undo = await executor.setTankRecordEndpoint(
        diveId: 'd1',
        tankId: 'missing',
        endpoint: 'start',
        bar: 210,
        findingId: finding.id,
      );

      expect(undo, isNull);
      // Nothing was written, so the finding stays open.
      expect(await statusOf('d1'), QualityStatus.open);
    });

    test('sets the start endpoint only, undo restores prior', () async {
      await diveRepo.createDive(
        domain.Dive(
          id: 'd1',
          dateTime: DateTime.utc(2026, 7, 1),
          tanks: const [
            domain.DiveTank(id: 't1', startPressure: 50, endPressure: 200),
          ],
        ),
      );
      final finding = await seedFindingForDive('d1');

      final undo = await executor.setTankRecordEndpoint(
        diveId: 'd1',
        tankId: 't1',
        endpoint: 'start',
        bar: 210,
        findingId: finding.id,
      );

      var tank = (await diveRepo.getDiveById('d1'))!.tanks.single;
      expect(tank.startPressure, 210);
      expect(tank.endPressure, 200, reason: 'end untouched');
      expect(await statusOf('d1'), QualityStatus.resolved);

      await undo!();
      tank = (await diveRepo.getDiveById('d1'))!.tanks.single;
      expect(tank.startPressure, 50);
      expect(tank.endPressure, 200);
    });

    test('sets the end endpoint only, undo restores prior', () async {
      await diveRepo.createDive(
        domain.Dive(
          id: 'd1',
          dateTime: DateTime.utc(2026, 7, 1),
          tanks: const [
            domain.DiveTank(id: 't1', startPressure: 50, endPressure: 200),
          ],
        ),
      );
      final finding = await seedFindingForDive('d1');

      final undo = await executor.setTankRecordEndpoint(
        diveId: 'd1',
        tankId: 't1',
        endpoint: 'end',
        bar: 60,
        findingId: finding.id,
      );

      var tank = (await diveRepo.getDiveById('d1'))!.tanks.single;
      expect(tank.startPressure, 50, reason: 'start untouched');
      expect(tank.endPressure, 60);

      await undo!();
      tank = (await diveRepo.getDiveById('d1'))!.tanks.single;
      expect(tank.endPressure, 200);
    });

    test(
      'writes but returns null undo when the prior endpoint was null',
      () async {
        await diveRepo.createDive(
          domain.Dive(
            id: 'd1',
            dateTime: DateTime.utc(2026, 7, 1),
            tanks: const [
              // No startPressure -> prior is null, so no undo is offered.
              domain.DiveTank(id: 't1', endPressure: 200),
            ],
          ),
        );
        final finding = await seedFindingForDive('d1');

        final undo = await executor.setTankRecordEndpoint(
          diveId: 'd1',
          tankId: 't1',
          endpoint: 'start',
          bar: 210,
          findingId: finding.id,
        );

        expect(undo, isNull);
        // The write still happened and the finding is resolved.
        final tank = (await diveRepo.getDiveById('d1'))!.tanks.single;
        expect(tank.startPressure, 210);
        expect(await statusOf('d1'), QualityStatus.resolved);
      },
    );
  });

  test('swapPressureSeries exchanges the two series, undo restores', () async {
    final tankRepo = TankPressureRepository();
    await diveRepo.createDive(
      domain.Dive(
        id: 'd1',
        dateTime: DateTime.utc(2026, 7, 1),
        tanks: const [
          domain.DiveTank(id: 't1'),
          domain.DiveTank(id: 't2'),
        ],
      ),
    );
    await tankRepo.insertTankPressures('d1', {
      't1': const [(timestamp: 0, pressure: 200.0)],
      't2': const [(timestamp: 0, pressure: 100.0)],
    });
    final finding = await seedFindingForDive('d1');

    final undo = await executor.swapPressureSeries(
      diveId: 'd1',
      tankIdA: 't1',
      tankIdB: 't2',
      findingId: finding.id,
    );

    expect(
      (await tankRepo.getPressuresForTank('d1', 't1')).single.pressure,
      100,
    );
    expect(
      (await tankRepo.getPressuresForTank('d1', 't2')).single.pressure,
      200,
    );
    expect(await statusOf('d1'), QualityStatus.resolved);

    await undo!();
    expect(
      (await tankRepo.getPressuresForTank('d1', 't1')).single.pressure,
      200,
    );
    expect(
      (await tankRepo.getPressuresForTank('d1', 't2')).single.pressure,
      100,
    );
  });

  test('reassignPressureSeries moves the series, undo swaps back', () async {
    final tankRepo = TankPressureRepository();
    await diveRepo.createDive(
      domain.Dive(
        id: 'd1',
        dateTime: DateTime.utc(2026, 7, 1),
        tanks: const [
          domain.DiveTank(id: 't1'),
          domain.DiveTank(id: 't2'),
        ],
      ),
    );
    await tankRepo.insertTankPressures('d1', {
      't1': const [(timestamp: 0, pressure: 200.0)],
    });
    final finding = await seedFindingForDive('d1');

    final undo = await executor.reassignPressureSeries(
      diveId: 'd1',
      fromTankId: 't1',
      toTankId: 't2',
      findingId: finding.id,
    );

    expect(await tankRepo.getPressuresForTank('d1', 't1'), isEmpty);
    expect(
      (await tankRepo.getPressuresForTank('d1', 't2')).single.pressure,
      200,
    );
    expect(await statusOf('d1'), QualityStatus.resolved);

    await undo!();
    expect(
      (await tankRepo.getPressuresForTank('d1', 't1')).single.pressure,
      200,
    );
    expect(await tankRepo.getPressuresForTank('d1', 't2'), isEmpty);
  });

  test(
    'setPrimarySource promotes the source, resolves, returns null undo',
    () async {
      final db = DatabaseService.instance.database;
      await diveRepo.createDive(
        domain.Dive(id: 'd1', dateTime: DateTime.utc(2026, 7, 1)),
      );
      final now = DateTime.utc(2026, 7, 1);
      Future<void> insertSource(String id, bool isPrimary) => db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion(
              id: Value(id),
              diveId: const Value('d1'),
              isPrimary: Value(isPrimary),
              importedAt: Value(now),
              createdAt: Value(now),
            ),
          );
      await insertSource('src1', true);
      await insertSource('src2', false);
      final finding = await seedFindingForDive('d1');

      final undo = await executor.setPrimarySource(
        diveId: 'd1',
        sourceId: 'src2',
        findingId: finding.id,
      );

      expect(undo, isNull);
      final sources = await diveRepo.getDataSources('d1');
      expect(sources.firstWhere((s) => s.id == 'src2').isPrimary, isTrue);
      expect(sources.firstWhere((s) => s.id == 'src1').isPrimary, isFalse);
      expect(await statusOf('d1'), QualityStatus.resolved);
    },
  );
}
