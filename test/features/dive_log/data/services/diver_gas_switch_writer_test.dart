import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/safety_findings_repository.dart';
import 'package:submersion/features/dive_log/data/services/diver_gas_switch_writer.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/domain/services/safety_review_service.dart';

import '../../../../helpers/test_database.dart';

/// The one write behind the gas switch editor (issue #32): the diver's list
/// replaces what the editor loaded, in one transaction, and the dive is
/// marked as having a diver-owned switch list.
void main() {
  late AppDatabase db;
  late SyncRepository sync;
  late DiverGasSwitchWriter writer;

  final seededAt = DateTime.utc(2026, 5, 3, 10).millisecondsSinceEpoch;
  final now = DateTime.utc(2026, 11, 1, 12);

  setUp(() async {
    db = await setUpTestDatabase();
    sync = SyncRepository(database: db);
    writer = DiverGasSwitchWriter(db: db, sync: sync);

    for (final id in ['comp-1', 'comp-2']) {
      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion(
              id: Value(id),
              name: Value('Computer $id'),
              createdAt: Value(seededAt),
              updatedAt: Value(seededAt),
            ),
          );
    }
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('dive-1'),
            diveDateTime: Value(seededAt),
            entryTime: Value(seededAt),
            notes: const Value(''),
            createdAt: Value(seededAt),
            updatedAt: Value(seededAt),
          ),
        );
    for (final (id, order) in [('tank-a', 0), ('tank-b', 1)]) {
      await db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion.insert(
              id: id,
              diveId: 'dive-1',
              tankOrder: Value(order),
            ),
          );
    }
    for (final (id, computer) in [('gs-1', 'comp-1'), ('gs-other', 'comp-2')]) {
      await db
          .into(db.gasSwitches)
          .insert(
            GasSwitchesCompanion.insert(
              id: id,
              diveId: 'dive-1',
              tankId: 'tank-a',
              timestamp: 0,
              createdAt: seededAt,
              computerId: Value(computer),
            ),
          );
    }
  });

  tearDown(tearDownTestDatabase);

  GasSwitch sw({
    required String id,
    required int timestamp,
    required String tankId,
    double? depth,
    String? computerId,
  }) => GasSwitch(
    id: id,
    diveId: 'dive-1',
    timestamp: timestamp,
    tankId: tankId,
    depth: depth,
    createdAt: now,
    computerId: computerId,
  );

  final stored1 = sw(
    id: 'gs-1',
    timestamp: 0,
    tankId: 'tank-a',
    computerId: 'comp-1',
  );

  Future<GasSwitche?> row(String id) => (db.select(
    db.gasSwitches,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Dive> dive() =>
      (db.select(db.dives)..where((t) => t.id.equals('dive-1'))).getSingle();

  Future<bool> tombstoned(String id) async =>
      (await (db.select(db.deletionLog)..where(
                (t) =>
                    t.entityType.equals('gasSwitches') & t.recordId.equals(id),
              ))
              .get())
          .isNotEmpty;

  Future<bool> pending(String entityType, String id) async =>
      (await (db.select(db.syncRecords)..where(
                (t) => t.entityType.equals(entityType) & t.recordId.equals(id),
              ))
              .get())
          .isNotEmpty;

  test('an added switch is inserted without a computer', () async {
    final changed = await writer.save(
      diveId: 'dive-1',
      switches: [
        stored1,
        sw(id: 'gs-new', timestamp: 900, tankId: 'tank-b', depth: 21.0),
      ],
      loadedIds: {'gs-1'},
      now: now,
    );

    expect(changed, isTrue);
    final added = await row('gs-new');
    expect(added, isNotNull);
    expect(added!.computerId, isNull);
    expect(added.timestamp, 900);
    expect(added.tankId, 'tank-b');
    expect(added.depth, 21.0);
    expect(await pending('gasSwitches', 'gs-new'), isTrue);
  });

  test('an edited switch keeps its id and computer', () async {
    await writer.save(
      diveId: 'dive-1',
      switches: [stored1.copyWith(timestamp: 30)],
      loadedIds: {'gs-1'},
      now: now,
    );

    final edited = await row('gs-1');
    expect(edited!.timestamp, 30);
    expect(edited.computerId, 'comp-1');
    expect(await tombstoned('gs-1'), isFalse);
    expect(await pending('gasSwitches', 'gs-1'), isTrue);
  });

  test('a dropped switch is deleted and tombstoned', () async {
    await writer.save(
      diveId: 'dive-1',
      switches: const [],
      loadedIds: {'gs-1'},
      now: now,
    );

    expect(await row('gs-1'), isNull);
    expect(await tombstoned('gs-1'), isTrue);
  });

  test("the other computer's switch is never touched", () async {
    await writer.save(
      diveId: 'dive-1',
      switches: [
        stored1.copyWith(timestamp: 30),
        sw(id: 'gs-new', timestamp: 900, tankId: 'tank-b'),
      ],
      loadedIds: {'gs-1'},
      now: now,
    );
    await writer.save(
      diveId: 'dive-1',
      switches: const [],
      loadedIds: {'gs-1', 'gs-new'},
      now: now,
    );

    final other = await row('gs-other');
    expect(other, isNotNull);
    expect(other!.timestamp, 0);
    expect(other.computerId, 'comp-2');
    expect(await tombstoned('gs-other'), isFalse);
    expect(await pending('gasSwitches', 'gs-other'), isFalse);
  });

  test('a save marks the dive edited, bumps it and drops its review', () async {
    final reviews = SafetyFindingsRepository(db: db, syncRepository: sync);
    await reviews.saveReview(
      SafetyReview(
        diveId: 'dive-1',
        engineVersion: SafetyReviewService.engineVersion,
        reviewedAt: DateTime.fromMillisecondsSinceEpoch(seededAt),
        inputsHash: 'graded-the-old-switches',
        findings: const [],
      ),
    );
    // A dive the next day, whose residual loading re-derives from this one.
    final laterAt = DateTime.utc(2026, 5, 4, 10).millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('dive-2'),
            diveDateTime: Value(laterAt),
            entryTime: Value(laterAt),
            notes: const Value(''),
            createdAt: Value(laterAt),
            updatedAt: Value(laterAt),
          ),
        );
    final repository = DiveRepository();
    final revisionBefore = await repository.getResidualHistoryRevision(
      'dive-2',
    );

    await writer.save(
      diveId: 'dive-1',
      switches: [stored1.copyWith(timestamp: 30)],
      loadedIds: {'gs-1'},
      now: now,
    );

    final updated = await dive();
    expect(updated.gasSwitchesEdited, isTrue);
    expect(updated.updatedAt, now.millisecondsSinceEpoch);
    expect(await reviews.getReview('dive-1'), isNull);
    expect(await pending('dives', 'dive-1'), isTrue);
    expect(
      await repository.getResidualHistoryRevision('dive-2'),
      isNot(revisionBefore),
    );
  });

  test('an unchanged list writes nothing', () async {
    final reviews = SafetyFindingsRepository(db: db, syncRepository: sync);
    await reviews.saveReview(
      SafetyReview(
        diveId: 'dive-1',
        engineVersion: SafetyReviewService.engineVersion,
        reviewedAt: DateTime.fromMillisecondsSinceEpoch(seededAt),
        inputsHash: 'still-good',
        findings: const [],
      ),
    );

    final changed = await writer.save(
      diveId: 'dive-1',
      switches: [stored1],
      loadedIds: {'gs-1'},
      now: now,
    );

    expect(changed, isFalse);
    final untouched = await dive();
    expect(untouched.gasSwitchesEdited, isFalse);
    expect(untouched.updatedAt, seededAt);
    expect(await reviews.getReview('dive-1'), isNotNull);
    expect(await pending('dives', 'dive-1'), isFalse);
  });
}
