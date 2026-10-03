import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/data_quality/data/repositories/quality_findings_repository.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/data_quality/domain/detectors/quality_detector.dart';
import 'package:submersion/features/data_quality/domain/detectors/quality_detector_toggles.dart';
import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../helpers/global_test_defaults.dart';
import '../../../helpers/test_database.dart';

/// Always throws: proves per-detector isolation.
class ThrowingDetector extends QualityDetector {
  const ThrowingDetector();
  @override
  String get id => 'throwing';
  @override
  int get version => 1;
  @override
  QualityCategory get category => QualityCategory.profile;
  @override
  List<QualityFinding> detect(DiveQualityContext context) =>
      throw StateError('boom');
}

/// Flags every dive it sees and has no prefilter candidate set.
class _UnprefilteredDetector extends QualityDetector {
  const _UnprefilteredDetector();
  @override
  String get id => 'unprefiltered';
  @override
  int get version => 1;
  @override
  QualityCategory get category => QualityCategory.time;
  @override
  List<QualityFinding> detect(DiveQualityContext context) => [
    make(context, severity: QualitySeverity.info),
  ];
}

void main() {
  late DiveRepository diveRepo;
  late QualityFindingsRepository findingsRepo;

  setUp(() async {
    await setUpTestDatabase();
    diveRepo = DiveRepository();
    findingsRepo = QualityFindingsRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<void> seedFutureDive(String id) => diveRepo.createDive(
    domain.Dive(id: id, dateTime: DateTime.utc(2031, 1, 1)),
  );

  test('targeted scan writes findings for a future-dated dive', () async {
    await seedFutureDive('d1');
    final service = QualityScanService();
    final summary = await service.scanDives({
      'd1',
    }, now: DateTime.utc(2026, 7, 17));
    expect(summary.findingsProduced, greaterThanOrEqualTo(1));
    final findings = await findingsRepo.getFindings(diveId: 'd1');
    expect(findings.map((f) => f.detectorId), contains('clock_offset'));
  });

  test('a disabled detector is skipped during a scan', () async {
    await seedFutureDive('d1');
    addTearDown(() => QualityDetectorToggles.disabled = <String>{});
    QualityDetectorToggles.disabled = {'clock_offset'};
    final service = QualityScanService();
    await service.scanDives({'d1'}, now: DateTime.utc(2026, 7, 17));
    final findings = await findingsRepo.getFindings(diveId: 'd1');
    expect(findings.where((f) => f.detectorId == 'clock_offset'), isEmpty);
  });

  test('fixing the dive retires the finding on rescan', () async {
    await seedFutureDive('d1');
    final service = QualityScanService();
    await service.scanDives({'d1'}, now: DateTime.utc(2026, 7, 17));
    final fixed = (await diveRepo.getDiveById('d1'))!;
    await diveRepo.updateDive(
      fixed.copyWith(
        dateTime: DateTime.utc(2026, 6, 1),
        entryTime: DateTime.utc(2026, 6, 1),
      ),
    );
    await service.scanDives({'d1'}, now: DateTime.utc(2026, 7, 17));
    final findings = await findingsRepo.getFindings(diveId: 'd1');
    expect(findings.where((f) => f.detectorId == 'clock_offset'), isEmpty);
  });

  test('a throwing detector is isolated and counted', () async {
    await seedFutureDive('d1');
    final service = QualityScanService(detectors: const [ThrowingDetector()]);
    final summary = await service.scanDives({
      'd1',
    }, now: DateTime.utc(2026, 7, 17));
    expect(summary.detectorErrors, 1);
    expect(summary.divesScanned, 1);
  });

  test('full scan honors cancellation at batch boundaries', () async {
    for (var i = 0; i < 5; i++) {
      await seedFutureDive('d$i');
    }
    final service = QualityScanService();
    var calls = 0;
    final summary = await service.scanLibrary(
      now: DateTime.utc(2026, 7, 17),
      isCancelled: () => ++calls > 1, // cancel after the first batch check
    );
    // With batchSize 200 all 5 dives fit one batch; the second check cancels
    // before a second batch would start, so exactly one batch ran.
    expect(summary.divesScanned, 5);
  });

  test('scheduler merges bursts and is awaitable', () async {
    await seedFutureDive('d1');
    QualityScanScheduler.enabled = true;
    addTearDown(applyGlobalTestDefaults);
    scheduleQualityScan(['d1']);
    scheduleQualityScan(['d1']);
    await QualityScanScheduler.instance.idle;
    final findings = await findingsRepo.getFindings(diveId: 'd1');
    expect(findings, isNotEmpty);
  });

  group('unknown transmitters (issue #2870)', () {
    Future<void> seedTransmitterDive(String id) => diveRepo.createDive(
      domain.Dive(
        id: id,
        dateTime: DateTime.utc(2026, 6, 1),
        tanks: const [
          domain.DiveTank(id: 'tank-1', transmitterSerial: '180777'),
        ],
      ),
    );

    Future<List<QualityFinding>> unknownTransmitterFindings(String id) async =>
        (await findingsRepo.getFindings(
          diveId: id,
        )).where((f) => f.detectorId == 'unknown_transmitter').toList();

    test('a full library scan keeps an unknown transmitter finding', () async {
      await seedTransmitterDive('d1');
      final service = QualityScanService();
      await service.scanDives({'d1'}, now: DateTime.utc(2026, 7, 17));
      expect(await unknownTransmitterFindings('d1'), hasLength(1));

      await service.scanLibrary(now: DateTime.utc(2026, 7, 17));

      final after = await unknownTransmitterFindings('d1');
      expect(after, hasLength(1));
      expect(after.single.status, QualityStatus.open);
    });

    test('a library scan retires the finding once the transmitter is '
        'registered', () async {
      await seedTransmitterDive('d1');
      final service = QualityScanService();
      await service.scanDives({'d1'}, now: DateTime.utc(2026, 7, 17));
      expect(await unknownTransmitterFindings('d1'), hasLength(1));

      final t = DateTime.now().millisecondsSinceEpoch;
      final db = DatabaseService.instance.database;
      await db
          .into(db.transmitters)
          .insert(
            TransmittersCompanion.insert(
              id: 'tx1',
              label: 'Back gas',
              tankRole: 'backGas',
              createdAt: t,
              updatedAt: t,
              transmitterSerial: const Value('180777'),
            ),
          );
      await service.scanLibrary(now: DateTime.utc(2026, 7, 17));

      final after = await unknownTransmitterFindings('d1');
      expect(after.where((f) => f.status == QualityStatus.open), isEmpty);
    });

    test(
      'a full library scan finds an unknown transmitter by itself',
      () async {
        await seedTransmitterDive('d1');
        await QualityScanService().scanLibrary(now: DateTime.utc(2026, 7, 17));
        expect(await unknownTransmitterFindings('d1'), hasLength(1));
      },
    );
  });

  // A detector the prefilters do not know must still run in a library
  // scan: skipping it while counting it as run retires all its findings
  // (#2870).
  test(
    'a detector without a candidate set still runs in a library scan',
    () async {
      await seedFutureDive('d1');
      final service = QualityScanService(
        detectors: const [_UnprefilteredDetector()],
      );
      await service.scanLibrary(now: DateTime.utc(2026, 7, 17));
      final findings = await findingsRepo.getFindings(diveId: 'd1');
      expect(findings.map((f) => f.detectorId), ['unprefiltered']);
    },
  );
}
