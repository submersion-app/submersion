import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/data_quality/data/repositories/quality_findings_repository.dart';
import 'package:submersion/features/data_quality/data/services/quality_context_builder.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/data_quality/domain/detectors/quality_detector.dart';
import 'package:submersion/features/data_quality/domain/detectors/quality_detector_toggles.dart';
import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';
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

/// Flags a pair from one member only, the way `split_pair` stays silent on a
/// dive with no runtime while its neighbor still reports the pair.
class _OneSidedPairDetector extends QualityDetector {
  const _OneSidedPairDetector();
  @override
  String get id => 'one_sided_pair';
  @override
  int get version => 1;
  @override
  QualityCategory get category => QualityCategory.duplicate;
  @override
  List<QualityFinding> detect(DiveQualityContext context) =>
      context.dive.id == 'first'
      ? [makePair(context, otherDiveId: 'last', severity: QualitySeverity.info)]
      : const [];
}

/// Answers each batch with bare contexts, recording how large it was and the
/// clock it was given.
class _RecordingBuilder implements QualityContextBuilder {
  final batches = <int>[];
  final clocks = <DateTime?>[];

  @override
  Future<List<DiveQualityContext>> buildAll(
    List<String> diveIds, {
    DateTime? now,
  }) async {
    batches.add(diveIds.length);
    clocks.add(now);
    return [
      for (final id in diveIds)
        DiveQualityContext(
          dive: domain.Dive(id: id, dateTime: DateTime.utc(2026)),
          now: DateTime.utc(2026),
        ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records each write in place of making it.
class _RecordingFindings extends QualityFindingsRepository {
  final scopes = <Set<String>>[];
  final produced = <QualityFinding>[];

  @override
  Future<ScanApplyResult> applyScanResults({
    required Set<String> scopeDiveIds,
    required Set<String> ranDetectorIds,
    required List<QualityFinding> produced,
  }) async {
    scopes.add(scopeDiveIds);
    this.produced.addAll(produced);
    return const ScanApplyResult(inserted: 0, updated: 0, removed: 0);
  }
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

  group('a targeted scan past one batch (issue #3864)', () {
    const overBatch = QualityScanService.batchSize * 2 + 50;
    final ids = {for (var i = 0; i < overBatch; i++) 'dive-$i'};

    test('builds no more than a batch of contexts at a time', () async {
      final builder = _RecordingBuilder();
      final service = QualityScanService(
        contextBuilder: builder,
        findingsRepository: _RecordingFindings(),
        detectors: const [_UnprefilteredDetector()],
      );

      final summary = await service.scanDives(ids);

      expect(builder.batches, [
        QualityScanService.batchSize,
        QualityScanService.batchSize,
        50,
      ]);
      expect(summary.divesScanned, overBatch);
      expect(summary.findingsProduced, overBatch);
    });

    test('writes every finding in one apply, scoped to every dive', () async {
      final findings = _RecordingFindings();
      final service = QualityScanService(
        contextBuilder: _RecordingBuilder(),
        findingsRepository: findings,
        detectors: const [_UnprefilteredDetector()],
      );

      await service.scanDives(ids);

      expect(findings.scopes, [ids]);
      expect(findings.produced, hasLength(overBatch));
    });

    test('keeps a pair only one member reports when the two land in '
        'different batches', () async {
      await seedFutureDive('first');
      await seedFutureDive('last');
      final service = QualityScanService(
        contextBuilder: _RecordingBuilder(),
        detectors: const [_OneSidedPairDetector()],
      );

      await service.scanDives({
        'first',
        for (var i = 0; i < QualityScanService.batchSize; i++) 'dive-$i',
        'last',
      });

      final findings = await findingsRepo.getFindings(diveId: 'first');
      expect(findings.single.relatedDiveId, 'last');
    });

    test('counts detector errors from every batch', () async {
      final service = QualityScanService(
        contextBuilder: _RecordingBuilder(),
        findingsRepository: _RecordingFindings(),
        detectors: const [ThrowingDetector()],
      );

      final summary = await service.scanDives(ids);

      expect(summary.detectorErrors, overBatch);
    });

    test('tells sync once', () async {
      var notified = 0;
      final sub = SyncEventBus.changes.listen((_) => notified++);
      addTearDown(sub.cancel);
      final service = QualityScanService(
        contextBuilder: _RecordingBuilder(),
        findingsRepository: _RecordingFindings(),
        detectors: const [_UnprefilteredDetector()],
      );

      await service.scanDives(ids);
      await Future<void>.delayed(Duration.zero);

      expect(notified, 1);
    });

    test('judges every batch against one clock', () async {
      final builder = _RecordingBuilder();
      final service = QualityScanService(
        contextBuilder: builder,
        findingsRepository: _RecordingFindings(),
        detectors: const [_UnprefilteredDetector()],
      );

      await service.scanDives(ids);

      expect(builder.clocks, hasLength(3));
      expect(builder.clocks.first, isNotNull);
      expect(builder.clocks.toSet(), hasLength(1));
    });
  });

  group('a scope past SQLite\'s variable limit (issue #3864)', () {
    test('still scans and writes', () async {
      await seedFutureDive('first');
      await seedFutureDive('last');
      final service = QualityScanService(
        contextBuilder: _RecordingBuilder(),
        detectors: const [_OneSidedPairDetector()],
      );

      final summary = await service.scanDives({
        'first',
        for (var i = 0; i < 33000; i++) 'dive-$i',
        'last',
      });

      expect(summary.divesScanned, 33002);
      final findings = await findingsRepo.getFindings(diveId: 'first');
      expect(findings.single.relatedDiveId, 'last');
    });

    test('finds the neighbors of a dive past the first chunk', () async {
      await seedFutureDive('late');
      await seedFutureDive('neighbor');
      final findings = _RecordingFindings();
      final service = QualityScanService(
        contextBuilder: _RecordingBuilder(),
        findingsRepository: findings,
        detectors: const [_UnprefilteredDetector()],
      );

      await service.scanDives({
        for (var i = 0; i < kSeriesIdChunkSize; i++) 'dive-$i',
        'late',
      });

      expect(findings.scopes.single, contains('neighbor'));
    });

    test('retires a finding only a later chunk of the scope matches', () async {
      await seedFutureDive('first');
      await seedFutureDive('last');
      await QualityScanService(
        contextBuilder: _RecordingBuilder(),
        detectors: const [_OneSidedPairDetector()],
      ).scanDives({'first', 'last'});

      final result = await findingsRepo.applyScanResults(
        scopeDiveIds: {
          for (var i = 0; i < kSeriesIdChunkSize; i++) 'dive-$i',
          'last',
        },
        ranDetectorIds: {'one_sided_pair'},
        produced: const [],
      );

      expect(result.removed, 1);
    });

    test('removes a pair once when its dives fall in different chunks of '
        'the scope', () async {
      await seedFutureDive('first');
      await seedFutureDive('last');
      await QualityScanService(
        contextBuilder: _RecordingBuilder(),
        detectors: const [_OneSidedPairDetector()],
      ).scanDives({'first', 'last'});

      final result = await findingsRepo.applyScanResults(
        scopeDiveIds: {
          'first',
          for (var i = 0; i < kSeriesIdChunkSize; i++) 'dive-$i',
          'last',
        },
        ranDetectorIds: {'one_sided_pair'},
        produced: const [],
      );

      expect(result.removed, 1);
      expect(await findingsRepo.getFindings(diveId: 'first'), isEmpty);
    });
  });

  test('a full scan judges every batch against one clock', () async {
    for (var i = 0; i <= QualityScanService.batchSize; i++) {
      await seedFutureDive('d$i');
    }
    final builder = _RecordingBuilder();
    final service = QualityScanService(
      contextBuilder: builder,
      findingsRepository: _RecordingFindings(),
      detectors: const [_UnprefilteredDetector()],
    );

    await service.scanLibrary();

    expect(builder.clocks, hasLength(2));
    expect(builder.clocks.first, isNotNull);
    expect(builder.clocks.toSet(), hasLength(1));
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
        'set up', () async {
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
              volumeL: const Value(11.1),
            ),
          );
      await service.scanLibrary(now: DateTime.utc(2026, 7, 17));

      final after = await unknownTransmitterFindings('d1');
      expect(after.where((f) => f.status == QualityStatus.open), isEmpty);
    });

    for (final (name, configured, volume) in [
      ('a configured transmitter with no cylinder', true, null),
      ('an unconfigured transmitter', false, 11.1),
    ]) {
      test('$name keeps the finding (#3676)', () async {
        await seedTransmitterDive('d1');
        final t = DateTime.now().millisecondsSinceEpoch;
        final db = DatabaseService.instance.database;
        await db
            .into(db.transmitters)
            .insert(
              TransmittersCompanion.insert(
                id: 'tx1',
                label: 'Transmitter 180777',
                tankRole: 'backGas',
                createdAt: t,
                updatedAt: t,
                transmitterSerial: const Value('180777'),
                volumeL: Value(volume),
                isConfigured: Value(configured),
              ),
            );

        await QualityScanService().scanLibrary(now: DateTime.utc(2026, 7, 17));

        expect(await unknownTransmitterFindings('d1'), hasLength(1));
      });
    }

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
