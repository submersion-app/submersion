import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart'
    hide Dive, DiveHealthRecord;
import 'package:submersion/features/dive_log/data/repositories/dive_health_record_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_consolidation_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_health_record.dart';

import '../../../../helpers/test_database.dart';

/// Heart rate, recovery and sleep from Apple Health (issue #637), one record
/// per dive, synced like the dive's tide record.
void main() {
  late AppDatabase db;
  late DiveRepository dives;
  late DiveHealthRecordRepository records;
  final created = DateTime.utc(2026, 7, 1).millisecondsSinceEpoch;

  setUp(() async {
    db = await setUpTestDatabase();
    dives = DiveRepository();
    records = DiveHealthRecordRepository();
    for (final id in ['a', 'b']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: created,
              updatedAt: created,
            ),
          );
    }
  });

  tearDown(() => tearDownTestDatabase());

  Future<Dive> dive({String diverId = 'a', DateTime? at}) => dives.createDive(
    Dive(
      id: '',
      diverId: diverId,
      dateTime: at ?? DateTime.utc(2026, 7, 17, 10),
      entryTime: at ?? DateTime.utc(2026, 7, 17, 10),
      exitTime: (at ?? DateTime.utc(2026, 7, 17, 10)).add(
        const Duration(minutes: 45),
      ),
    ),
  );

  DiveHealthRecord record(String diveId, {bool settled = false}) =>
      DiveHealthRecord(
        id: '',
        diveId: diveId,
        heartRateSamples: const [
          [0, 82],
          [60, 76],
        ],
        avgHeartRate: 79,
        maxHeartRate: 82,
        heartRateAtExit: 88,
        heartRateExitPlus5: 74,
        heartRateExitPlus15: 66,
        overnightHrvMs: 48.5,
        sleepBeforeMinutes: 412,
        settled: settled,
        fetchedAt: DateTime.utc(2026, 7, 17, 13),
      );

  test('a record reads back as it was written', () async {
    final d = await dive();

    await records.upsert(record(d.id));

    final read = (await records.forDive(d.id))!;
    expect(read.heartRateSamples, [
      [0, 82],
      [60, 76],
    ]);
    expect(read.avgHeartRate, 79);
    expect(read.heartRateExitPlus15, 66);
    expect(read.overnightHrvMs, 48.5);
    expect(read.sleepBeforeMinutes, 412);
    expect(read.settled, isFalse);
  });

  test('writing again replaces the dive\'s record', () async {
    final d = await dive();
    await records.upsert(record(d.id));

    await records.upsert(record(d.id, settled: true));

    final rows = await db.select(db.diveHealthRecords).get();
    expect(rows, hasLength(1));
    expect((await records.forDive(d.id))!.settled, isTrue);
  });

  test('a dive\'s first record takes the id every device gives it, so two '
      'devices reading Health for one synced dive write one row', () async {
    final d = await dive();

    await records.upsert(record(d.id));

    expect((await records.forDive(d.id))!.id, diveHealthRecordId(d.id));
  });

  test('deleting the dive deletes its record', () async {
    final d = await dive();
    await records.upsert(record(d.id));

    await dives.deleteDive(d.id);

    expect(await db.select(db.diveHealthRecords).get(), isEmpty);
  });

  group('consolidation', () {
    test('a watch dive joining a download brings its record', () async {
      final target = await dive();
      final watch = await dive(at: DateTime.utc(2026, 7, 17, 10, 1));
      await records.upsert(record(watch.id));

      await DiveConsolidationService(
        dives,
      ).apply(targetDiveId: target.id, secondaryDiveIds: [watch.id]);

      final moved = (await records.forDive(target.id))!;
      expect(moved.avgHeartRate, 79);
      expect(await db.select(db.diveHealthRecords).get(), hasLength(1));
    });

    test('the target keeps its own record', () async {
      final target = await dive();
      final watch = await dive(at: DateTime.utc(2026, 7, 17, 10, 1));
      await records.upsert(record(target.id, settled: true));
      await records.upsert(record(watch.id));

      await DiveConsolidationService(
        dives,
      ).apply(targetDiveId: target.id, secondaryDiveIds: [watch.id]);

      expect((await records.forDive(target.id))!.settled, isTrue);
      expect(await db.select(db.diveHealthRecords).get(), hasLength(1));
    });

    test('undo puts the record back on its dive', () async {
      final target = await dive();
      final watch = await dive(at: DateTime.utc(2026, 7, 17, 10, 1));
      await records.upsert(record(watch.id));
      final service = DiveConsolidationService(dives);
      final outcome = await service.apply(
        targetDiveId: target.id,
        secondaryDiveIds: [watch.id],
      );

      await service.undo(outcome.snapshot);

      expect(await records.forDive(target.id), isNull);
      expect((await records.forDive(watch.id))!.avgHeartRate, 79);
    });
  });

  test(
    'unsettled lists the diver\'s recent dives that still need readings',
    () async {
      final recent = await dive();
      final settled = await dive(at: DateTime.utc(2026, 7, 17, 14));
      final old = await dive(at: DateTime.utc(2026, 7, 1, 10));
      final theirs = await dive(diverId: 'b');
      final none = await dive(at: DateTime.utc(2026, 7, 16, 10));
      await records.upsert(record(recent.id));
      await records.upsert(record(settled.id, settled: true));
      await records.upsert(record(old.id));
      await records.upsert(record(theirs.id));

      final ids = await records.unsettledDiveIds(
        diverId: 'a',
        since: DateTime.utc(2026, 7, 10),
      );

      expect(ids, unorderedEquals([recent.id, none.id]));
    },
  );
}
