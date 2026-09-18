import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_gear_note_repository.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center_gear_note.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveCenterGearNoteRepository repository;
  const stale = 1000;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveCenterGearNoteRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> seedCenter(String id) => db
      .into(db.diveCenters)
      .insert(
        DiveCentersCompanion(
          id: Value(id),
          name: Value(id),
          createdAt: const Value(stale),
          updatedAt: const Value(stale),
        ),
      );

  Future<void> seedDive(String id, {String? centerId}) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: const Value(stale),
          diveCenterId: Value(centerId),
          createdAt: const Value(stale),
          updatedAt: const Value(stale),
        ),
      );

  DiveCenterGearNote note({
    String id = '',
    String centerId = 'c1',
    EquipmentType type = EquipmentType.regulator,
    String? diveId,
    DateTime? notedAt,
  }) {
    final now = DateTime.utc(2026, 9, 18, 10);
    return DiveCenterGearNote(
      id: id,
      diveCenterId: centerId,
      gearType: type,
      label: '14',
      verdict: RentalVerdict.avoid,
      leadAdjustmentKg: 2,
      note: 'wet',
      diveId: diveId,
      notedAt: notedAt ?? now,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<int> pendingCountFor(String recordId) async =>
      (await db
              .customSelect(
                "SELECT COUNT(*) AS n FROM sync_records WHERE entity_type = "
                "'diveCenterGearNotes' AND record_id = ? "
                "AND sync_status = 'pending'",
                variables: [Variable<String>(recordId)],
              )
              .getSingle())
          .read<int>('n');

  Future<int> tombstoneCountFor(String recordId) async =>
      (await db
              .customSelect(
                'SELECT COUNT(*) AS n FROM deletion_log WHERE entity_type = '
                "'diveCenterGearNotes' AND record_id = ?",
                variables: [Variable<String>(recordId)],
              )
              .getSingle())
          .read<int>('n');

  test('create assigns an id, stores every field and marks pending', () async {
    await seedCenter('c1');
    await seedDive('d1', centerId: 'c1');

    final created = await repository.create(note(diveId: 'd1'));

    expect(created.id, isNotEmpty);
    final stored = await repository.getById(created.id);
    expect(stored, isNotNull);
    expect(stored!.diveCenterId, 'c1');
    expect(stored.gearType, EquipmentType.regulator);
    expect(stored.label, '14');
    expect(stored.size, isNull);
    expect(stored.verdict, RentalVerdict.avoid);
    expect(stored.leadAdjustmentKg, 2);
    expect(stored.volumeLiters, isNull);
    expect(stored.note, 'wet');
    expect(stored.diveId, 'd1');
    expect(stored.notedAt, DateTime.utc(2026, 9, 18, 10));
    expect(await pendingCountFor(created.id), 1);
  });

  test('getForCenter lists newest noted first and only that center', () async {
    await seedCenter('c1');
    await seedCenter('c2');
    final older = await repository.create(
      note(notedAt: DateTime.utc(2026, 1, 1)),
    );
    final newer = await repository.create(
      note(notedAt: DateTime.utc(2026, 6, 1), type: EquipmentType.bcd),
    );
    await repository.create(note(centerId: 'c2'));

    final notes = await repository.getForCenter('c1');
    expect(notes.map((n) => n.id), [newer.id, older.id]);
  });

  test('update rewrites the row and marks it pending again', () async {
    await seedCenter('c1');
    final created = await repository.create(note());

    await repository.update(
      created.copyWith(
        verdict: RentalVerdict.worked,
        size: 'L',
        clearLeadAdjustment: true,
        volumeLiters: 11.1,
        note: 'fine after service',
      ),
    );

    final stored = await repository.getById(created.id);
    expect(stored!.verdict, RentalVerdict.worked);
    expect(stored.size, 'L');
    expect(stored.leadAdjustmentKg, isNull);
    expect(stored.volumeLiters, 11.1);
    expect(stored.note, 'fine after service');
    expect(stored.updatedAt.isBefore(created.updatedAt), isFalse);
    expect(await pendingCountFor(created.id), 1);
  });

  test('delete removes the row and writes a tombstone', () async {
    await seedCenter('c1');
    final created = await repository.create(note());

    await repository.delete(created.id);

    expect(await repository.getById(created.id), isNull);
    expect(await tombstoneCountFor(created.id), 1);
  });

  test('deleting the dive it was noted on keeps the note, detached', () async {
    await seedCenter('c1');
    await seedDive('d1', centerId: 'c1');
    final created = await repository.create(note(diveId: 'd1'));

    await (db.delete(db.dives)..where((t) => t.id.equals('d1'))).go();

    final stored = await repository.getById(created.id);
    expect(stored, isNotNull);
    expect(stored!.diveId, isNull);
  });

  test('deleting the center cascades its notes and tombstones each', () async {
    await seedCenter('c1');
    final a = await repository.create(note());
    final b = await repository.create(note(type: EquipmentType.wetsuit));

    await DiveCenterRepository().deleteDiveCenter('c1');

    expect(await repository.getForCenter('c1'), isEmpty);
    expect(await tombstoneCountFor(a.id), 1);
    expect(await tombstoneCountFor(b.id), 1);
  });

  test('watchChanges emits after a write', () async {
    await seedCenter('c1');
    final events = <void>[];
    final sub = repository.watchChanges().listen(events.add);
    addTearDown(sub.cancel);

    await repository.create(note());
    await Future<void>.delayed(Duration.zero);

    expect(events, isNotEmpty);
  });

  test('create for a center that does not exist throws', () async {
    await expectLater(
      repository.create(note(centerId: 'gone')),
      throwsA(anything),
    );
    expect(await repository.getForCenter('gone'), isEmpty);
  });
}
