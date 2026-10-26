import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/data_quality/data/repositories/quality_findings_repository.dart';
import 'package:submersion/features/data_quality/data/services/quality_repair_executor.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../helpers/global_test_defaults.dart';
import '../../../helpers/test_database.dart';

/// Issue #3655: a whole-hour disagreement between a dive's sources is
/// repaired on the side that is wrong. Fixing a secondary computer's clock
/// rewrites that source row alone; shifting the logbook moves the dive and
/// its primary source together, so the two sources agree afterwards.
void main() {
  late DiveRepository diveRepo;
  late QualityFindingsRepository findingsRepo;
  late QualityRepairExecutor executor;
  late AppDatabase db;

  final logbookEntry = DateTime.utc(2026, 7, 1, 10);
  const runtime = Duration(minutes: 50);

  setUp(() async {
    await setUpTestDatabase();
    QualityScanScheduler.enabled = false;
    db = DatabaseService.instance.database;
    diveRepo = DiveRepository();
    findingsRepo = QualityFindingsRepository();
    executor = QualityRepairExecutor();
    await db
        .into(db.diveComputers)
        .insert(
          const DiveComputersCompanion(
            id: Value('pc1'),
            name: Value('Perdix'),
            createdAt: Value(0),
            updatedAt: Value(0),
          ),
        );
    await db
        .into(db.diveComputers)
        .insert(
          const DiveComputersCompanion(
            id: Value('pc2'),
            name: Value('Teric'),
            createdAt: Value(0),
            updatedAt: Value(0),
          ),
        );
  });
  tearDown(() {
    applyGlobalTestDefaults();
    return tearDownTestDatabase();
  });

  Future<void> insertSource(
    String id, {
    required String diveId,
    required bool isPrimary,
    required DateTime entry,
    String? computerId,
  }) => db
      .into(db.diveDataSources)
      .insert(
        DiveDataSourcesCompanion(
          id: Value(id),
          diveId: Value(diveId),
          computerId: Value(computerId),
          isPrimary: Value(isPrimary),
          entryTime: Value(entry),
          exitTime: Value(entry.add(runtime)),
          importedAt: Value(logbookEntry),
          createdAt: Value(logbookEntry),
        ),
      );

  /// A dive whose logbook and primary (UDDF) source are right, plus a
  /// secondary download from [computerId] whose clock is [secondaryOffset]
  /// off.
  Future<void> seedDive(
    String diveId, {
    DateTime? entry,
    Duration secondaryOffset = const Duration(hours: 1),
    String computerId = 'pc1',
  }) async {
    final at = entry ?? logbookEntry;
    await diveRepo.createDive(
      domain.Dive(
        id: diveId,
        dateTime: at,
        entryTime: at,
        exitTime: at.add(runtime),
      ),
    );
    await insertSource(
      '$diveId-uddf',
      diveId: diveId,
      isPrimary: true,
      entry: at,
    );
    await insertSource(
      '$diveId-dc',
      diveId: diveId,
      isPrimary: false,
      entry: at.add(secondaryOffset),
      computerId: computerId,
    );
  }

  Future<QualityFinding> seedFinding(String diveId) async {
    final finding = QualityFinding(
      id: qualityFindingId(
        diveId: diveId,
        detectorId: 'clock_offset',
        discriminator: 'src:$diveId-dc',
      ),
      diveId: diveId,
      detectorId: 'clock_offset',
      detectorVersion: 1,
      category: QualityCategory.time,
      severity: QualitySeverity.warning,
      status: QualityStatus.open,
      params: {'offsetHours': 1, 'sourceId': '$diveId-dc'},
      createdAt: logbookEntry,
      updatedAt: logbookEntry,
    );
    await findingsRepo.applyScanResults(
      scopeDiveIds: {diveId},
      ranDetectorIds: {'clock_offset'},
      produced: [finding],
    );
    return finding;
  }

  /// Drift reads a DateTime column back in local time, and DateTime ==
  /// compares the zone too; the instant is what matters.
  Matcher at(DateTime t) => predicate<DateTime?>(
    (d) => d != null && d.isAtSameMomentAs(t),
    'the instant $t',
  );

  Future<DiveDataSourcesData> source(String id) => (db.select(
    db.diveDataSources,
  )..where((t) => t.id.equals(id))).getSingle();

  group('shiftSourceTimes', () {
    test('moves only the wrong source; the logbook is untouched', () async {
      await seedDive('d1');
      final finding = await seedFinding('d1');

      final result = await executor.shiftSourceTimes(
        sourceIds: ['d1-dc'],
        offset: const Duration(hours: -1),
        findingId: finding.id,
      );

      expect(result.changed, isTrue);
      final dc = await source('d1-dc');
      expect(dc.entryTime, at(logbookEntry));
      expect(dc.exitTime, at(logbookEntry.add(runtime)));
      expect((await source('d1-uddf')).entryTime, at(logbookEntry));
      final dive = (await diveRepo.getDiveById('d1'))!;
      expect(dive.entryTime, logbookEntry);
      expect(dive.dateTime, logbookEntry);
      final findings = await findingsRepo.getFindings(diveId: 'd1');
      expect(findings.single.status, QualityStatus.resolved);
    });

    test('marks the source pending for sync, never the dive', () async {
      await seedDive('d1');
      final finding = await seedFinding('d1');
      await db.delete(db.syncRecords).go();

      await executor.shiftSourceTimes(
        sourceIds: ['d1-dc'],
        offset: const Duration(hours: -1),
        findingId: finding.id,
      );

      final pending = await db.select(db.syncRecords).get();
      expect({
        for (final r in pending) '${r.entityType}/${r.recordId}',
      }, containsAll(['diveDataSources/d1-dc']));
      expect(pending.where((r) => r.entityType == 'dives'), isEmpty);
    });

    test('undo puts the source clock back', () async {
      await seedDive('d1');
      final finding = await seedFinding('d1');

      final result = await executor.shiftSourceTimes(
        sourceIds: ['d1-dc'],
        offset: const Duration(hours: -1),
        findingId: finding.id,
      );
      await result.undo!();

      final dc = await source('d1-dc');
      expect(dc.entryTime, at(logbookEntry.add(const Duration(hours: 1))));
      expect(
        dc.exitTime,
        at(logbookEntry.add(const Duration(hours: 1) + runtime)),
      );
    });

    test('reports no change for a source that is gone', () async {
      await seedDive('d1');
      final finding = await seedFinding('d1');

      final result = await executor.shiftSourceTimes(
        sourceIds: ['missing'],
        offset: const Duration(hours: -1),
        findingId: finding.id,
      );

      expect(result.changed, isFalse);
      final findings = await findingsRepo.getFindings(diveId: 'd1');
      expect(findings.single.status, QualityStatus.open);
    });
  });

  group('sourcesWithSameClockOffset', () {
    test('finds this computer off by the same hours on other dives', () async {
      await seedDive('d1');
      await seedDive('d2', entry: logbookEntry.add(const Duration(days: 1)));
      // Same computer, a different error: not the same mistake.
      await seedDive(
        'd3',
        entry: logbookEntry.add(const Duration(days: 2)),
        secondaryOffset: const Duration(hours: 2),
      );
      // Same error, another computer.
      await seedDive(
        'd4',
        entry: logbookEntry.add(const Duration(days: 3)),
        computerId: 'pc2',
      );
      // Same computer, its clock right.
      await seedDive(
        'd5',
        entry: logbookEntry.add(const Duration(days: 4)),
        secondaryOffset: Duration.zero,
      );

      final ids = await executor.sourcesWithSameClockOffset(
        sourceId: 'd1-dc',
        offset: const Duration(hours: -1),
      );

      expect(ids.toSet(), {'d1-dc', 'd2-dc'});
    });

    test('tolerates a few minutes beside the whole hours', () async {
      await seedDive('d1');
      await seedDive(
        'd2',
        entry: logbookEntry.add(const Duration(days: 1)),
        secondaryOffset: const Duration(hours: 1, minutes: 2),
      );

      final ids = await executor.sourcesWithSameClockOffset(
        sourceId: 'd1-dc',
        offset: const Duration(hours: -1),
      );

      expect(ids.toSet(), {'d1-dc', 'd2-dc'});
    });

    test('is just the source when it names no computer', () async {
      await seedDive('d1');
      await (db.update(db.diveDataSources)..where((t) => t.id.equals('d1-dc')))
          .write(const DiveDataSourcesCompanion(computerId: Value(null)));

      final ids = await executor.sourcesWithSameClockOffset(
        sourceId: 'd1-dc',
        offset: const Duration(hours: -1),
      );

      expect(ids, ['d1-dc']);
    });
  });

  group('shiftTimes (the logbook is the wrong side)', () {
    test('moves the dive and its primary source to match', () async {
      await seedDive('d1');
      final finding = await seedFinding('d1');

      final result = await executor.shiftTimes(
        diveIds: ['d1'],
        offset: const Duration(hours: 1),
        findingId: finding.id,
      );

      final shifted = logbookEntry.add(const Duration(hours: 1));
      expect((await diveRepo.getDiveById('d1'))!.entryTime, shifted);
      final uddf = await source('d1-uddf');
      expect(uddf.entryTime, at(shifted));
      expect(uddf.exitTime, at(shifted.add(runtime)));
      // The secondary was right all along and is left alone.
      expect((await source('d1-dc')).entryTime, at(shifted));

      await result.undo!();
      expect((await diveRepo.getDiveById('d1'))!.entryTime, logbookEntry);
      expect((await source('d1-uddf')).entryTime, at(logbookEntry));
      expect((await source('d1-dc')).entryTime, at(shifted));
    });
  });
}
