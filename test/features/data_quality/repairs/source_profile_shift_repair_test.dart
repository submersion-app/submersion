import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/data_quality/data/repositories/quality_findings_repository.dart';
import 'package:submersion/features/data_quality/data/services/quality_repair_executor.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../helpers/global_test_defaults.dart';
import '../../../helpers/test_database.dart';

/// A consolidated dive whose second computer was placed by a clock 20
/// minutes slow, put back where its profile fits by the repair (#4296).
void main() {
  late AppDatabase db;
  late ProfileSeriesRepository profileSeries;
  late QualityFindingsRepository findingsRepo;
  late QualityRepairExecutor executor;

  final entry = DateTime.utc(2026, 7, 1, 10);
  final secondEntry = entry.subtract(const Duration(minutes: 20));
  const exitAfter = Duration(minutes: 48);
  const shift = 1160;

  setUp(() async {
    await setUpTestDatabase();
    QualityScanScheduler.enabled = false;
    db = DatabaseService.instance.database;
    profileSeries = ProfileSeriesRepository();
    findingsRepo = QualityFindingsRepository();
    executor = QualityRepairExecutor();
    for (final id in ['pc1', 'pc2']) {
      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion(
              id: Value(id),
              name: Value(id),
              createdAt: const Value(0),
              updatedAt: const Value(0),
            ),
          );
    }
    await DiveRepository().createDive(
      domain.Dive(
        id: 'd1',
        dateTime: entry,
        entryTime: entry,
        tanks: const [
          domain.DiveTank(
            id: 't1',
            gasMix: domain.GasMix(o2: 32, he: 0),
            order: 0,
          ),
        ],
      ),
    );
    Future<void> source(
      String id, {
      required String computerId,
      required bool isPrimary,
      required DateTime at,
      int? offset,
    }) => db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion(
            id: Value(id),
            diveId: const Value('d1'),
            computerId: Value(computerId),
            isPrimary: Value(isPrimary),
            entryTime: Value(at),
            exitTime: Value(at.add(exitAfter)),
            timeOffsetSeconds: Value(offset),
            importedAt: Value(entry),
            createdAt: Value(entry),
          ),
        );
    await source('src-1', computerId: 'pc1', isPrimary: true, at: entry);
    await source(
      'src-2',
      computerId: 'pc2',
      isPrimary: false,
      at: secondEntry,
      offset: -1200,
    );
    await profileSeries.insertSeries(
      diveId: 'd1',
      computerId: 'pc1',
      sourceId: 'src-1',
      samples: const [
        ProfileSample(timestamp: 0, depth: 0),
        ProfileSample(timestamp: 60, depth: 10),
      ],
    );
    await profileSeries.insertSeries(
      diveId: 'd1',
      computerId: 'pc2',
      sourceId: 'src-2',
      isPrimary: false,
      samples: const [
        ProfileSample(timestamp: -1200, depth: 0),
        ProfileSample(timestamp: -1140, depth: 10),
      ],
    );
    Future<void> event(String id, {String? computerId, required String by}) =>
        db
            .into(db.diveProfileEvents)
            .insert(
              DiveProfileEventsCompanion(
                id: Value(id),
                diveId: const Value('d1'),
                timestamp: const Value(-1100),
                eventType: const Value('bookmark'),
                source: Value(by),
                computerId: Value(computerId),
                createdAt: const Value(0),
              ),
            );
    await event('ev-2', computerId: 'pc2', by: EventSource.imported.name);
    await event('ev-user', computerId: 'pc2', by: EventSource.user.name);
    await event('ev-1', computerId: 'pc1', by: EventSource.imported.name);
    await db
        .into(db.gasSwitches)
        .insert(
          const GasSwitchesCompanion(
            id: Value('sw-2'),
            diveId: Value('d1'),
            tankId: Value('t1'),
            timestamp: Value(-1000),
            computerId: Value('pc2'),
            createdAt: Value(0),
          ),
        );
  });
  tearDown(() {
    applyGlobalTestDefaults();
    return tearDownTestDatabase();
  });

  Future<QualityFinding> seedFinding() async {
    final finding = QualityFinding(
      id: qualityFindingId(
        diveId: 'd1',
        detectorId: 'clock_offset',
        discriminator: 'fit:src-2',
      ),
      diveId: 'd1',
      computerId: 'pc2',
      detectorId: 'clock_offset',
      detectorVersion: 2,
      category: QualityCategory.time,
      severity: QualitySeverity.warning,
      status: QualityStatus.open,
      params: const {'sourceId': 'src-2', 'profileOffsetSeconds': shift},
      createdAt: entry,
      updatedAt: entry,
    );
    await findingsRepo.applyScanResults(
      scopeDiveIds: {'d1'},
      ranDetectorIds: {'clock_offset'},
      produced: [finding],
    );
    return finding;
  }

  Future<Map<String, List<int>>> seriesStarts() async => {
    for (final s in await profileSeries.getSeriesForDive('d1'))
      s.sourceId!: [for (final p in s.samples) p.timestamp],
  };
  Future<int> eventAt(String id) async => (await (db.select(
    db.diveProfileEvents,
  )..where((t) => t.id.equals(id))).getSingle()).timestamp;
  Future<DiveDataSourcesData> sourceRow(String id) => (db.select(
    db.diveDataSources,
  )..where((t) => t.id.equals(id))).getSingle();

  test(
    "moves the source's samples, events and clock, not the primary's",
    () async {
      final finding = await seedFinding();

      final result = await executor.shiftSourceProfile(
        diveId: 'd1',
        sourceId: 'src-2',
        seconds: shift,
        findingId: finding.id,
      );

      expect(result.changed, isTrue);
      final starts = await seriesStarts();
      expect(starts['src-2'], [-40, 20]);
      expect(starts['src-1'], [0, 60]);
      expect(await eventAt('ev-2'), -1100 + shift);
      expect(await eventAt('ev-user'), -1100, reason: "the diver's own stays");
      expect(await eventAt('ev-1'), -1100, reason: "the primary's stays");
      final sw = await (db.select(
        db.gasSwitches,
      )..where((t) => t.id.equals('sw-2'))).getSingle();
      expect(sw.timestamp, -1000 + shift);
      final moved = await sourceRow('src-2');
      expect(moved.timeOffsetSeconds, -40);
      expect(
        moved.entryTime!.isAtSameMomentAs(
          secondEntry.add(const Duration(seconds: shift)),
        ),
        isTrue,
      );
      final primary = await sourceRow('src-1');
      expect(primary.entryTime!.isAtSameMomentAs(entry), isTrue);
      final findings = await findingsRepo.getFindings(diveId: 'd1');
      expect(findings.single.status, QualityStatus.resolved);
    },
  );

  test('undo puts every moved row back', () async {
    final finding = await seedFinding();
    final result = await executor.shiftSourceProfile(
      diveId: 'd1',
      sourceId: 'src-2',
      seconds: shift,
      findingId: finding.id,
    );

    await result.undo!();

    final starts = await seriesStarts();
    expect(starts['src-2'], [-1200, -1140]);
    expect(await eventAt('ev-2'), -1100);
    final restored = await sourceRow('src-2');
    expect(restored.timeOffsetSeconds, -1200);
    expect(restored.entryTime!.isAtSameMomentAs(secondEntry), isTrue);
  });

  test('undo leaves a source that recorded no offset without one', () async {
    await (db.update(db.diveDataSources)..where((t) => t.id.equals('src-2')))
        .write(const DiveDataSourcesCompanion(timeOffsetSeconds: Value(null)));
    final finding = await seedFinding();
    final result = await executor.shiftSourceProfile(
      diveId: 'd1',
      sourceId: 'src-2',
      seconds: shift,
      findingId: finding.id,
    );
    expect((await sourceRow('src-2')).timeOffsetSeconds, shift);

    await result.undo!();

    expect((await sourceRow('src-2')).timeOffsetSeconds, isNull);
  });

  test('a window an earlier clock repair already corrected is not moved '
      'again (#3655)', () async {
    // The whole-hour repair put the window on the primary's clock, but the
    // samples it does not touch still sit where the wrong clock put them.
    final corrected = entry.subtract(const Duration(seconds: 40));
    await (db.update(
      db.diveDataSources,
    )..where((t) => t.id.equals('src-2'))).write(
      DiveDataSourcesCompanion(
        entryTime: Value(corrected),
        exitTime: Value(corrected.add(exitAfter)),
      ),
    );
    final finding = await seedFinding();

    await executor.shiftSourceProfile(
      diveId: 'd1',
      sourceId: 'src-2',
      seconds: shift,
      findingId: finding.id,
    );

    final row = await sourceRow('src-2');
    expect(row.entryTime!.isAtSameMomentAs(corrected), isTrue);
    expect(row.timeOffsetSeconds, -40);
    expect((await seriesStarts())['src-2'], [-40, 20]);
  });

  test('a source the dive no longer has changes nothing', () async {
    final finding = await seedFinding();
    final result = await executor.shiftSourceProfile(
      diveId: 'd1',
      sourceId: 'src-gone',
      seconds: shift,
      findingId: finding.id,
    );
    expect(result.changed, isFalse);
    expect((await seriesStarts())['src-2'], [-1200, -1140]);
  });
}
