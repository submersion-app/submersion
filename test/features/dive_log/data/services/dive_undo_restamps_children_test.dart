import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_consolidation_service.dart';
import 'package:submersion/features/dive_log/data/services/dive_merge_service.dart';
import 'package:submersion/features/dive_log/data/services/dive_merge_snapshot.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';

/// An undo is a new edit (#2670). The dive merge and consolidation undos
/// re-insert the data sources, tide records and gear links of the restored
/// dives from the snapshot; each must come back with a clock newer than the
/// one it had before the operation, and a pending mark, or a peer holding a
/// newer copy of the row refuses it as stale and the undo never reaches it.
void main() {
  late AppDatabase db;
  late DiveRepository diveRepo;

  /// Older than any clock this test's device issues.
  final seedClock = const Hlc(1000, 0, 'seed-device').toString();

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
    diveRepo = DiveRepository();
  });

  tearDown(() async {
    // The undo's pending marks configure the process-wide clock from this
    // database; drop it so the next file in the isolate seeds its own.
    SyncClock.instance.reset();
    await tearDownTestDatabase();
  });

  Future<void> seedDive(String id, {required DateTime entry}) async {
    await diveRepo.createDive(
      domain.Dive(
        id: id,
        diverId: 'diver1',
        dateTime: entry,
        entryTime: entry,
        runtime: const Duration(minutes: 30),
        maxDepth: 18,
        profile: const [
          domain.DiveProfilePoint(timestamp: 0, depth: 0),
          domain.DiveProfilePoint(timestamp: 900, depth: 18),
          domain.DiveProfilePoint(timestamp: 1800, depth: 0),
        ],
      ),
    );
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: 'src-$id',
            diveId: id,
            importedAt: DateTime.utc(2026, 7, 1),
            createdAt: DateTime.utc(2026, 7, 1),
          ).copyWith(isPrimary: const Value(true), hlc: Value(seedClock)),
        );
    await db
        .into(db.tideRecords)
        .insert(
          TideRecordsCompanion.insert(
            id: 'tide-$id',
            diveId: id,
            heightMeters: 1.2,
            tideState: 'rising',
            createdAt: 0,
          ).copyWith(hlc: Value(seedClock)),
        );
    await db
        .into(db.diveEquipment)
        .insert(
          DiveEquipmentCompanion.insert(
            diveId: id,
            equipmentId: 'bcd',
          ).copyWith(hlc: Value(seedClock)),
        );
  }

  /// Each restored row's (entity type, sync record id, current clock).
  Future<List<(String, String, String?)>> restoredChildren(
    List<String> diveIds,
  ) async => [
    for (final r in await (db.select(
      db.diveDataSources,
    )..where((t) => t.diveId.isIn(diveIds))).get())
      ('diveDataSources', r.id, r.hlc),
    for (final r in await (db.select(
      db.tideRecords,
    )..where((t) => t.diveId.isIn(diveIds))).get())
      ('tideRecords', r.id, r.hlc),
    for (final r in await (db.select(
      db.diveEquipment,
    )..where((t) => t.diveId.isIn(diveIds))).get())
      ('diveEquipment', '${r.diveId}|${r.equipmentId}', r.hlc),
  ];

  Future<Set<String>> pendingKeys() async => {
    for (final r in await db.select(db.syncRecords).get())
      if (r.syncStatus == 'pending') '${r.entityType}/${r.recordId}',
  };

  Future<void> expectRestampedAndPending(List<String> diveIds) async {
    final rows = await restoredChildren(diveIds);
    // Two dives, each with one data source, one tide record, one gear link.
    expect(rows, hasLength(6));
    final pending = await pendingKeys();
    for (final (entityType, recordId, hlc) in rows) {
      expect(
        hlc,
        isNotNull,
        reason: '$entityType/$recordId restored without a clock',
      );
      expect(
        Hlc.parse(hlc!).compareTo(Hlc.parse(seedClock)),
        greaterThan(0),
        reason:
            '$entityType/$recordId restored with its pre-operation clock, '
            'which a peer holding the newer copy refuses as stale',
      );
      expect(
        pending,
        contains('$entityType/$recordId'),
        reason: '$entityType/$recordId restored without a pending mark',
      );
    }
  }

  /// Clears the pending marks the seed and the operation left, so only the
  /// undo's own marks are counted.
  Future<void> undoWithCleanQueue(
    Future<void> Function(DiveMergeSnapshot) undo,
    DiveMergeSnapshot snapshot,
  ) async {
    await db.delete(db.syncRecords).go();
    await undo(snapshot);
  }

  test('dive merge undo restamps and marks the restored sources, tides and '
      'gear links', () async {
    await seedDive('a', entry: DateTime.utc(2026, 7, 1, 9));
    await seedDive('b', entry: DateTime.utc(2026, 7, 1, 10));
    final service = DiveMergeService(diveRepo);

    final outcome = await service.apply(['a', 'b']);
    await undoWithCleanQueue(service.undo, outcome.snapshot);

    await expectRestampedAndPending(['a', 'b']);
  });

  test('consolidation undo restamps and marks the restored sources, tides '
      'and gear links', () async {
    await seedDive('t', entry: DateTime.utc(2026, 7, 1, 9));
    await seedDive('s', entry: DateTime.utc(2026, 7, 1, 9, 1));
    final service = DiveConsolidationService(diveRepo);

    final outcome = await service.apply(
      targetDiveId: 't',
      secondaryDiveIds: ['s'],
    );
    await undoWithCleanQueue(service.undo, outcome.snapshot);

    await expectRestampedAndPending(['t', 's']);
  });
}
