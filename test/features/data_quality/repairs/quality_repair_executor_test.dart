import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';
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

    final result = await executor.shiftTimes(
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

    await result.undo!();
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
    test('reports no change when the primary profile is empty', () async {
      await diveRepo.createDive(
        domain.Dive(id: 'd1', dateTime: DateTime.utc(2026, 7, 1)),
      );
      final finding = await seedFindingForDive('d1');

      final result = await executor.applyProfileRepair(
        diveId: 'd1',
        findingId: finding.id,
        compute: (pts) => pts,
      );

      expect(result.changed, isFalse);
      // Early-exit leaves the finding untouched.
      expect(await statusOf('d1'), QualityStatus.open);
    });

    test('reports no change and leaves the finding open when the repair '
        'computes the stored series', () async {
      // The repair found nothing to fix. Writing an identical series would
      // stack another edited-profile layer, and resolving the finding would
      // only have the next scan reopen it -- which is what made the repair
      // buttons look dead (issue #1001).
      final profile = [
        const domain.DiveProfilePoint(timestamp: 0, depth: 5),
        const domain.DiveProfilePoint(
          timestamp: 60,
          depth: 10,
          temperature: 12,
        ),
      ];
      await diveRepo.createDive(
        domain.Dive(
          id: 'd1',
          dateTime: DateTime.utc(2026, 7, 1),
          profile: profile,
        ),
      );
      final finding = await seedFindingForDive('d1');

      final result = await executor.applyProfileRepair(
        diveId: 'd1',
        findingId: finding.id,
        compute: (pts) => [for (final p in pts) p.copyWith()],
      );

      expect(result.changed, isFalse);
      expect(result.undo, isNull);
      expect(await statusOf('d1'), QualityStatus.open);
      expect(
        (await diveRepo.getDiveProfile('d1')).map((p) => p.depth).toList(),
        [5.0, 10.0],
      );
    });

    test('a repair touching a channel other than depth/temperature still '
        'counts as a change', () async {
      // The no-change check compares WHOLE samples, so a repair that
      // rewrites ppO2, an o2 sensor or a deco field is not mistaken for a
      // no-op just because depth and temperature are untouched.
      await diveRepo.createDive(
        domain.Dive(
          id: 'd1',
          dateTime: DateTime.utc(2026, 7, 1),
          profile: const [
            domain.DiveProfilePoint(timestamp: 0, depth: 5),
            domain.DiveProfilePoint(timestamp: 60, depth: 10),
          ],
        ),
      );
      final finding = await seedFindingForDive('d1');

      final result = await executor.applyProfileRepair(
        diveId: 'd1',
        findingId: finding.id,
        compute: (pts) => [for (final p in pts) p.copyWith(ppO2: 1.2)],
      );

      expect(result.changed, isTrue);
      expect(await statusOf('d1'), QualityStatus.resolved);
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

      final result = await executor.applyProfileRepair(
        diveId: 'd1',
        findingId: finding.id,
        compute: (pts) => [for (final p in pts) p.copyWith(depth: p.depth * 2)],
      );

      expect(
        (await diveRepo.getDiveProfile('d1')).map((p) => p.depth).toList(),
        [10.0, 20.0, 30.0],
      );
      expect(await statusOf('d1'), QualityStatus.resolved);

      await result.undo!();
      expect(
        (await diveRepo.getDiveProfile('d1')).map((p) => p.depth).toList(),
        [5.0, 10.0, 15.0],
      );
    });
  });

  group('recomputeMetrics', () {
    test('reports no change when the dive is missing', () async {
      // Returns before touching the finding, so no seeding is needed.
      final result = await executor.recomputeMetrics(
        diveId: 'ghost',
        findingId: 'irrelevant',
      );
      expect(result.changed, isFalse);
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

      final result = await executor.recomputeMetrics(
        diveId: 'd1',
        findingId: finding.id,
      );

      final fixed = (await diveRepo.getDiveById('d1'))!;
      expect(fixed.maxDepth, 30);
      expect(fixed.avgDepth, 20);
      expect(await statusOf('d1'), QualityStatus.resolved);

      await result.undo!();
      final restored = (await diveRepo.getDiveById('d1'))!;
      expect(restored.maxDepth, 99);
      expect(restored.avgDepth, 99);
    });
  });

  group('convertWaterTemp', () {
    test('reports no change when the dive is missing', () async {
      final result = await executor.convertWaterTemp(
        diveId: 'ghost',
        kelvinScale: false,
        findingId: 'irrelevant',
      );
      expect(result.changed, isFalse);
    });

    test('reports no change when the dive has no water temperature', () async {
      await diveRepo.createDive(
        domain.Dive(id: 'd1', dateTime: DateTime.utc(2026, 7, 1)),
      );
      final finding = await seedFindingForDive('d1');

      final result = await executor.convertWaterTemp(
        diveId: 'd1',
        kelvinScale: false,
        findingId: finding.id,
      );

      expect(result.changed, isFalse);
      expect(await statusOf('d1'), QualityStatus.open);
    });

    test('converts Fahrenheit to Celsius and undo restores prior', () async {
      await diveRepo.createDive(
        domain.Dive(
          id: 'd1',
          dateTime: DateTime.utc(2026, 7, 1),
          waterTemp: 78,
        ),
      );
      final finding = await seedFindingForDive('d1');

      final result = await executor.convertWaterTemp(
        diveId: 'd1',
        kelvinScale: false,
        findingId: finding.id,
      );

      expect(result.changed, isTrue);
      expect(
        (await diveRepo.getDiveById('d1'))!.waterTemp,
        closeTo(25.5556, 1e-3),
      );
      expect(await statusOf('d1'), QualityStatus.resolved);

      await result.undo!();
      expect((await diveRepo.getDiveById('d1'))!.waterTemp, 78);
    });

    test('refuses a scale that does not land the reading in range', () async {
      // -50 read as Fahrenheit is -45.6 C: still implausible, so converting
      // would resolve a finding the next scan reopens.
      await diveRepo.createDive(
        domain.Dive(
          id: 'd1',
          dateTime: DateTime.utc(2026, 7, 1),
          waterTemp: -50,
        ),
      );
      final finding = await seedFindingForDive('d1');

      final result = await executor.convertWaterTemp(
        diveId: 'd1',
        kelvinScale: false,
        findingId: finding.id,
      );

      expect(result.changed, isFalse);
      expect((await diveRepo.getDiveById('d1'))!.waterTemp, -50);
      expect(await statusOf('d1'), QualityStatus.open);
    });

    test('refuses when the dive was corrected between scan and tap', () async {
      // The finding was raised against a bad value, but the diver fixed it by
      // hand first. Converting a plausible 25 C would turn it into -3.9 C.
      await diveRepo.createDive(
        domain.Dive(
          id: 'd1',
          dateTime: DateTime.utc(2026, 7, 1),
          waterTemp: 25,
        ),
      );
      final finding = await seedFindingForDive('d1');

      final result = await executor.convertWaterTemp(
        diveId: 'd1',
        kelvinScale: false,
        findingId: finding.id,
      );

      expect(result.changed, isFalse);
      expect((await diveRepo.getDiveById('d1'))!.waterTemp, 25);
      expect(await statusOf('d1'), QualityStatus.open);
    });

    test('converts a Fahrenheit-as-Kelvin reading', () async {
      await diveRepo.createDive(
        domain.Dive(
          id: 'd1',
          dateTime: DateTime.utc(2026, 7, 1),
          waterTemp: 297,
        ),
      );
      final finding = await seedFindingForDive('d1');

      await executor.convertWaterTemp(
        diveId: 'd1',
        kelvinScale: true,
        findingId: finding.id,
      );

      expect(
        (await diveRepo.getDiveById('d1'))!.waterTemp,
        closeTo(23.85, 1e-3),
      );
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

      final result = await executor.swapTankRecordPressures(
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

      await result.undo!();
      tank = (await diveRepo.getDiveById('d1'))!.tanks.single;
      expect(tank.startPressure, 50);
      expect(tank.endPressure, 200);
    },
  );

  group('setTankRecordEndpoint', () {
    test('reports no change when the tank is not found', () async {
      await diveRepo.createDive(
        domain.Dive(id: 'd1', dateTime: DateTime.utc(2026, 7, 1)),
      );
      final finding = await seedFindingForDive('d1');

      final result = await executor.setTankRecordEndpoint(
        diveId: 'd1',
        tankId: 'missing',
        endpoint: 'start',
        bar: 210,
        findingId: finding.id,
      );

      expect(result.changed, isFalse);
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

      final result = await executor.setTankRecordEndpoint(
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

      await result.undo!();
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

      final result = await executor.setTankRecordEndpoint(
        diveId: 'd1',
        tankId: 't1',
        endpoint: 'end',
        bar: 60,
        findingId: finding.id,
      );

      var tank = (await diveRepo.getDiveById('d1'))!.tanks.single;
      expect(tank.startPressure, 50, reason: 'start untouched');
      expect(tank.endPressure, 60);

      await result.undo!();
      tank = (await diveRepo.getDiveById('d1'))!.tanks.single;
      expect(tank.endPressure, 200);
    });

    test(
      'writes but offers no undo when the prior endpoint was null',
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

        final result = await executor.setTankRecordEndpoint(
          diveId: 'd1',
          tankId: 't1',
          endpoint: 'start',
          bar: 210,
          findingId: finding.id,
        );

        expect(result.changed, isTrue);
        expect(result.undo, isNull);
        // The write still happened and the finding is resolved.
        final tank = (await diveRepo.getDiveById('d1'))!.tanks.single;
        expect(tank.startPressure, 210);
        expect(await statusOf('d1'), QualityStatus.resolved);
      },
    );
  });

  group('a repair rebuilds the dive\'s sensor summary', () {
    // The condition engine reads the summaries, and a repair (or its undo)
    // can rewrite a profile or pressure series without touching the dive's
    // updated_at, so the rebuild is forced.
    // Each request as "sorted ids:forced", since sets compare by identity.
    final requests = <String>[];
    setUp(() {
      requests.clear();
      SensorSummaryScheduler.instance.summaryRequestListener = (ids, force) =>
          requests.add('${(ids.toList()..sort()).join(',')}:$force');
    });
    tearDown(
      () => SensorSummaryScheduler.instance.summaryRequestListener = null,
    );

    test('after the write and after its undo', () async {
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

      final result = await executor.swapPressureSeries(
        diveId: 'd1',
        tankIdA: 't1',
        tankIdB: 't2',
        findingId: finding.id,
      );
      expect(requests, ['d1:true']);
      await result.undo!();
      expect(requests, ['d1:true', 'd1:true']);
    });

    test('for every dive a time shift moved', () async {
      for (final id in ['d1', 'd2']) {
        final entry = DateTime.utc(2026, 7, 1, 10);
        await diveRepo.createDive(
          domain.Dive(id: id, dateTime: entry, entryTime: entry),
        );
      }
      final finding = await seedFindingForDive('d1');
      final result = await executor.shiftTimes(
        diveIds: ['d1', 'd2'],
        offset: const Duration(hours: -6),
        findingId: finding.id,
      );
      await result.undo!();
      expect(requests, ['d1,d2:true', 'd1,d2:true']);
    });
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

    final result = await executor.swapPressureSeries(
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

    await result.undo!();
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

    final result = await executor.reassignPressureSeries(
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

    await result.undo!();
    expect(
      (await tankRepo.getPressuresForTank('d1', 't1')).single.pressure,
      200,
    );
    expect(await tankRepo.getPressuresForTank('d1', 't2'), isEmpty);
  });

  test(
    'setPrimarySource promotes the source, resolves, offers no undo',
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

      final result = await executor.setPrimarySource(
        diveId: 'd1',
        sourceId: 'src2',
        findingId: finding.id,
      );

      expect(result.undo, isNull);
      final sources = await diveRepo.getDataSources('d1');
      expect(sources.firstWhere((s) => s.id == 'src2').isPrimary, isTrue);
      expect(sources.firstWhere((s) => s.id == 'src1').isPrimary, isFalse);
      expect(await statusOf('d1'), QualityStatus.resolved);
    },
  );

  group('deleteDuplicate', () {
    final entry = DateTime.utc(2026, 7, 1, 10);
    final richProfile = [
      for (var t = 0; t <= 600; t += 60)
        domain.DiveProfilePoint(timestamp: t, depth: 20),
    ];
    const fragmentProfile = [
      domain.DiveProfilePoint(timestamp: 0, depth: 1.7),
      domain.DiveProfilePoint(timestamp: 13, depth: 0),
    ];

    Future<QualityFinding> seedPair({String keep = 'dA', String drop = 'dB'}) {
      final pid = qualityPairIdentity(
        detectorId: 'duplicate',
        a: keep,
        b: drop,
      );
      final finding = QualityFinding(
        id: pid.id,
        diveId: pid.diveId,
        relatedDiveId: pid.relatedDiveId,
        detectorId: 'duplicate',
        detectorVersion: 3,
        category: QualityCategory.duplicate,
        severity: QualitySeverity.critical,
        status: QualityStatus.open,
        params: {'sameComputer': true, 'redundantDiveId': drop},
        createdAt: DateTime.utc(2026, 7, 17),
        updatedAt: DateTime.utc(2026, 7, 17),
      );
      return findingsRepo
          .applyScanResults(
            scopeDiveIds: {keep, drop},
            ranDetectorIds: {'duplicate'},
            produced: [finding],
          )
          .then((_) => finding);
    }

    Future<void> seedBoth() async {
      await diveRepo.createDive(
        domain.Dive(
          id: 'dA',
          dateTime: entry,
          entryTime: entry,
          runtime: const Duration(minutes: 35),
          maxDepth: 20,
          diveComputerSerial: 'S1',
          profile: richProfile,
        ),
      );
      await diveRepo.createDive(
        domain.Dive(
          id: 'dB',
          dateTime: entry.add(const Duration(minutes: 1)),
          entryTime: entry.add(const Duration(minutes: 1)),
          runtime: const Duration(seconds: 13),
          maxDepth: 1.7,
          diveComputerSerial: 'S1',
          profile: fragmentProfile,
        ),
      );
    }

    Future<bool> tombstoned(String diveId) async {
      final rows =
          await (DatabaseService.instance.database.select(
                  DatabaseService.instance.database.deletionLog,
                )
                ..where((t) => t.entityType.equals('dives'))
                ..where((t) => t.recordId.equals(diveId)))
              .get();
      return rows.isNotEmpty;
    }

    test('deletes the redundant copy, keeps the other, resolves', () async {
      await seedBoth();
      final finding = await seedPair();

      final result = await executor.deleteDuplicate(
        keepDiveId: 'dA',
        deleteDiveId: 'dB',
        findingId: finding.id,
      );

      expect(result.changed, isTrue);
      expect(await diveRepo.getDiveById('dB'), isNull);
      expect(await diveRepo.getDiveById('dA'), isNotNull);
      expect(await statusOf('dA'), QualityStatus.resolved);
    });

    test('goes through the sync tombstone path', () async {
      // A plain row delete would resurrect the copy on the next sync from
      // any peer that still has it.
      await seedBoth();
      final finding = await seedPair();
      await executor.deleteDuplicate(
        keepDiveId: 'dA',
        deleteDiveId: 'dB',
        findingId: finding.id,
      );
      expect(await tombstoned('dB'), isTrue);
      expect(await tombstoned('dA'), isFalse);
    });

    test('undo brings the copy back with its profile', () async {
      await seedBoth();
      final finding = await seedPair();
      final result = await executor.deleteDuplicate(
        keepDiveId: 'dA',
        deleteDiveId: 'dB',
        findingId: finding.id,
      );

      await result.undo!();

      final restored = await diveRepo.getDiveById('dB');
      expect(restored, isNotNull);
      expect(restored!.maxDepth, 1.7);
      expect(restored.diveComputerSerial, 'S1');
      expect(
        (await diveRepo.getDiveProfile('dB')).map((p) => p.depth).toList(),
        [1.7, 0.0],
      );
    });

    test('survives the finding being cascaded away with its dive', () async {
      // The pair's one finding hangs off the lexicographically smaller id.
      // When THAT is the redundant copy, deleting it cascades the finding
      // row, and resolving a row that is gone must not throw.
      await seedBoth();
      final finding = await seedPair(keep: 'dB', drop: 'dA');
      expect(finding.diveId, 'dA');

      final result = await executor.deleteDuplicate(
        keepDiveId: 'dB',
        deleteDiveId: 'dA',
        findingId: finding.id,
      );

      expect(result.changed, isTrue);
      expect(await diveRepo.getDiveById('dA'), isNull);
      expect(await findingsRepo.getFindings(diveId: 'dA'), isEmpty);
    });

    test('reports no change when the copy is already gone', () async {
      // Deleted by hand between the scan and the tap; there is nothing to
      // do, and resolving would only hide a finding the next scan would
      // not reopen anyway. Leave it to the rescan.
      await seedBoth();
      final finding = await seedPair();
      await diveRepo.deleteDive('dB');

      final result = await executor.deleteDuplicate(
        keepDiveId: 'dA',
        deleteDiveId: 'dB',
        findingId: finding.id,
      );

      expect(result.changed, isFalse);
      expect(result.undo, isNull);
      expect(await statusOf('dA'), QualityStatus.open);
    });

    test('refuses to delete the dive it was told to keep', () async {
      // Belt and braces against a mapping bug: the two ids must differ.
      await seedBoth();
      final finding = await seedPair();
      await expectLater(
        executor.deleteDuplicate(
          keepDiveId: 'dB',
          deleteDiveId: 'dB',
          findingId: finding.id,
        ),
        throwsArgumentError,
      );
      expect(await diveRepo.getDiveById('dB'), isNotNull);
    });
  });
}
