import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';

import '../../../../helpers/test_database.dart';

/// The operations a profile restore and a consolidation undo need: what they
/// delete, what they promote, and how a captured row goes back.
void main() {
  late AppDatabase db;
  late ProfileSeriesRepository repo;
  const now = 1750000000000;

  const samples = [
    ProfileSample(timestamp: 0, depth: 0.0),
    ProfileSample(timestamp: 10, depth: 12.0, temperature: 21.0),
  ];

  late String computerSeries;
  late String otherComputerSeries;
  late String editSeries;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = ProfileSeriesRepository();
    await db
        .into(db.dives)
        .insert(
          const DivesCompanion(
            id: Value('dive-1'),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    for (final id in ['comp-1', 'comp-2']) {
      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion.insert(
              id: id,
              name: 'Perdix',
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
    computerSeries = await repo.insertSeries(
      diveId: 'dive-1',
      computerId: 'comp-1',
      samples: samples,
      now: now,
    );
    otherComputerSeries = await repo.insertSeries(
      diveId: 'dive-1',
      computerId: 'comp-2',
      samples: samples,
      now: now,
    );
    editSeries = await repo.insertSeries(
      diveId: 'dive-1',
      samples: const [ProfileSample(timestamp: 0, depth: 2.0)],
      now: now,
    );
  });

  tearDown(tearDownTestDatabase);

  test('deleteEditedSeries removes only the primary edit', () async {
    final deleted = await repo.deleteEditedSeries('dive-1');
    expect(deleted, [editSeries]);
    final left = await repo.getSeriesForDive('dive-1');
    expect(left.map((s) => s.id).toSet(), {
      computerSeries,
      otherComputerSeries,
    });
    final tombstones =
        await (db.select(db.deletionLog)..where(
              (t) => t.entityType.equals(ProfileSeriesRepository.entityType),
            ))
            .get();
    expect(tombstones, hasLength(1));
    expect(tombstones.single.recordId, editSeries);
  });

  test('deleteEditedSeries leaves a demoted edit alone', () async {
    await repo.demoteAll('dive-1');
    expect(await repo.deleteEditedSeries('dive-1'), isEmpty);
  });

  test('promoteByComputer promotes that computer only', () async {
    await repo.demoteAll('dive-1');
    expect(await repo.promoteByComputer('dive-1', 'comp-1', now: now + 1), 1);
    expect((await repo.getSeriesById(computerSeries))!.isPrimary, isTrue);
    expect((await repo.getSeriesById(otherComputerSeries))!.isPrimary, isFalse);
    expect((await repo.getSeriesById(editSeries))!.isPrimary, isFalse);
  });

  test('promoteAll promotes every series of the dive', () async {
    await repo.demoteAll('dive-1');
    expect(await repo.promoteAll('dive-1', now: now + 1), 3);
    final rows = await repo.getSeriesForDive('dive-1');
    expect(rows.map((s) => s.isPrimary), everyElement(isTrue));
  });

  test('hasPrimarySeries follows the flag without decoding', () async {
    expect(await repo.hasPrimarySeries('dive-1'), isTrue);
    await repo.demoteAll('dive-1');
    expect(await repo.hasPrimarySeries('dive-1'), isFalse);
    expect(await repo.hasPrimarySeries('no-such-dive'), isFalse);
  });

  test('restoreSeriesRow puts the captured row back and queues it', () async {
    final captured = await (db.select(
      db.diveProfileSeries,
    )..where((t) => t.id.equals(computerSeries))).getSingle();
    await repo.deleteForDive('dive-1');
    await (db.delete(
      db.syncRecords,
    )..where((t) => t.recordId.equals(computerSeries))).go();

    await repo.restoreSeriesRow(captured, now: now + 5);

    final back = await (db.select(
      db.diveProfileSeries,
    )..where((t) => t.id.equals(computerSeries))).getSingle();
    expect(back.createdAt, captured.createdAt);
    expect(back.updatedAt, captured.updatedAt);
    expect(back.samples, captured.samples);
    expect(back.hlc, isNotNull);
    final pending = await (db.select(
      db.syncRecords,
    )..where((t) => t.recordId.equals(computerSeries))).getSingle();
    expect(pending.entityType, ProfileSeriesRepository.entityType);
  });

  test('restoreSeriesRow without now stamps the pending record with '
      'wall-clock time', () async {
    final captured = await (db.select(
      db.diveProfileSeries,
    )..where((t) => t.id.equals(computerSeries))).getSingle();
    await repo.deleteForDive('dive-1');
    await (db.delete(
      db.syncRecords,
    )..where((t) => t.recordId.equals(computerSeries))).go();

    await repo.restoreSeriesRow(captured);

    final pending = await (db.select(
      db.syncRecords,
    )..where((t) => t.recordId.equals(computerSeries))).getSingle();
    expect(pending.entityType, ProfileSeriesRepository.entityType);
    expect(pending.localUpdatedAt, greaterThan(0));
  });

  test(
    'restoreSeriesRow keeps the row untouched without markPending',
    () async {
      final captured = await (db.select(
        db.diveProfileSeries,
      )..where((t) => t.id.equals(computerSeries))).getSingle();
      await repo.deleteForDive('dive-1');

      await repo.restoreSeriesRow(captured, markPending: false);

      final back = await (db.select(
        db.diveProfileSeries,
      )..where((t) => t.id.equals(computerSeries))).getSingle();
      expect(back.hlc, captured.hlc);
      expect(back.updatedAt, captured.updatedAt);
    },
  );

  test('restoreSeriesRow removes the tombstone the delete logged', () async {
    final id = await repo.insertSeries(
      diveId: 'dive-1',
      samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
      now: now,
    );
    final row = await (db.select(
      db.diveProfileSeries,
    )..where((t) => t.id.equals(id))).getSingle();
    await repo.deleteForDive('dive-1');
    var tombstones = await (db.select(
      db.deletionLog,
    )..where((t) => t.recordId.equals(id))).get();
    expect(tombstones, hasLength(1));

    await repo.restoreSeriesRow(row, now: now + 1);

    tombstones = await (db.select(
      db.deletionLog,
    )..where((t) => t.recordId.equals(id))).get();
    expect(tombstones, isEmpty);
    expect(await repo.getSeriesById(id), isNotNull);
  });
}
