import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/safety_findings_repository.dart';
import 'package:submersion/features/dive_log/data/services/dive_split_service.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';

import '../../../helpers/test_database.dart';

/// How many tombstones the operations #1926 names mint, on a realistic
/// logbook.
///
/// Uses only APIs that predate #1926, so this same file runs unchanged on
/// the commit before it to produce the "before" numbers: each scenario
/// prints its count BEFORE asserting the new behaviour, so a run on the old
/// code still reports what it measured.
void main() {
  late AppDatabase db;
  const uuid = Uuid();
  final now = DateTime.utc(2026, 9, 26);
  final nowMs = now.millisecondsSinceEpoch;

  setUp(() async => db = await setUpTestDatabase());
  tearDown(() => tearDownTestDatabase());

  Future<int> tombstoneCount() async =>
      (await db.select(db.deletionLog).get()).length;

  Future<int> measure(String scenario, Future<void> Function() run) async {
    final before = await tombstoneCount();
    await run();
    final minted = (await tombstoneCount()) - before;
    // ignore: avoid_print
    print('MEASURE $scenario $minted');
    return minted;
  }

  Future<void> insertDive(String id, {String? computerId}) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(nowMs),
            computerId: Value(computerId),
            createdAt: Value(nowMs),
            updatedAt: Value(nowMs),
          ),
        );
  }

  Future<void> insertComputer(String id) async {
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion(
            id: Value(id),
            name: Value(id),
            createdAt: Value(nowMs),
            updatedAt: Value(nowMs),
          ),
        );
  }

  Future<void> insertEvents(String diveId, String? computerId, int n) async {
    await db.batch(
      (b) => b.insertAll(db.diveProfileEvents, [
        for (var i = 0; i < n; i++)
          DiveProfileEventsCompanion(
            id: Value(uuid.v4()),
            diveId: Value(diveId),
            computerId: Value(computerId),
            timestamp: Value(i * 10),
            eventType: const Value('bookmark'),
            createdAt: Value(nowMs),
          ),
      ]),
    );
  }

  /// The engine's output for dive [index]: 0 to 6 findings, each under a
  /// fresh random id, which is what the engine minted before #1926.
  List<SafetyFinding> findingsFor(String diveId, int index, int engine) => [
    for (var k = 0; k < index % 7; k++)
      SafetyFinding(
        id: uuid.v4(),
        diveId: diveId,
        ruleId: SafetyRuleId.values[k % SafetyRuleId.values.length],
        severity: SafetySeverity.caution,
        startTimestamp: k * 100,
        endTimestamp: k * 100 + 40,
        value: 10.0 + k,
        engineVersion: engine,
        createdAt: now,
      ),
  ];

  test('safety review recompute over a 200-dive logbook', () async {
    final repo = SafetyFindingsRepository(
      db: db,
      syncRepository: SyncRepository(),
    );
    const dives = 200;
    for (var i = 0; i < dives; i++) {
      await insertDive('dive-$i');
      await repo.saveReview(
        SafetyReview(
          diveId: 'dive-$i',
          engineVersion: 2,
          reviewedAt: now,
          findings: findingsFor('dive-$i', i, 2),
        ),
      );
    }

    final engineBump = await measure('engine-bump', () async {
      for (var i = 0; i < dives; i++) {
        await repo.saveReview(
          SafetyReview(
            diveId: 'dive-$i',
            engineVersion: 3,
            reviewedAt: now,
            findings: findingsFor('dive-$i', i, 3),
          ),
        );
      }
    });

    final profileEdit = await measure('profile-edit', () async {
      for (var i = 0; i < dives; i++) {
        await SafetyFindingsRepository.clearReviewForDive(
          db,
          SyncRepository(),
          'dive-$i',
        );
        await repo.saveReview(
          SafetyReview(
            diveId: 'dive-$i',
            engineVersion: 3,
            reviewedAt: now,
            findings: findingsFor('dive-$i', i, 3),
          ),
        );
      }
    });

    // Unchanged findings: nothing is deleted, so nothing is tombstoned.
    expect(engineBump, 0);
    // The marker's tombstone is written, then cleared when the recompute
    // restores the marker.
    expect(profileEdit, 0);
  });

  test('re-importing a long dive', () async {
    await insertDive('dive-1');
    await insertEvents('dive-1', null, 300);

    final minted = await measure(
      'reimport-300-events',
      () => DiveComputerRepository().clearEventsForDive('dive-1'),
    );

    expect(minted, 1);
  });

  test('splitting a long dive', () async {
    await insertComputer('dc-a');
    await insertComputer('dc-b');
    await insertDive('dive-1', computerId: 'dc-a');
    for (final (id, computer, primary) in [
      ('src-a', 'dc-a', true),
      ('src-b', 'dc-b', false),
    ]) {
      await db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion(
              id: Value(id),
              diveId: const Value('dive-1'),
              computerId: Value(computer),
              isPrimary: Value(primary),
              importedAt: Value(DateTime.utc(2026, 1, 1)),
              createdAt: Value(DateTime.utc(2026, 1, 1)),
            ),
          );
      await ProfileSeriesRepository().insertSeries(
        diveId: 'dive-1',
        computerId: computer,
        isPrimary: primary,
        samples: const [ProfileSample(timestamp: 0, depth: 10)],
        now: 1000,
      );
    }
    for (final tank in ['tank-1', 'tank-2']) {
      await db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion(
              id: Value(tank),
              diveId: const Value('dive-1'),
              computerId: const Value('dc-b'),
              tankOrder: const Value(0),
            ),
          );
    }
    await insertEvents('dive-1', 'dc-b', 300);

    final minted = await measure(
      'split-300-events-2-tanks',
      () => DiveSplitService(
        DiveRepository(),
      ).split(diveId: 'dive-1', sourceId: 'src-b'),
    );

    // One events scope, two tanks, the moved profile series and the source.
    expect(minted, 5);
  });
}
