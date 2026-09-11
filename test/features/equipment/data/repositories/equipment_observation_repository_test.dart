import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_observation_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late EquipmentObservationRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = EquipmentObservationRepository(
      db: db,
      syncRepository: SyncRepository(database: db),
    );
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'reg',
            name: 'Reg',
            type: 'regulator',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    for (final (id, date) in [('d1', 1000), ('d2', 2000)]) {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: id,
              diveDateTime: date,
              createdAt: date,
              updatedAt: date,
            ),
          );
    }
  });

  tearDown(tearDownTestDatabase);

  test('create stores the row, stamps an hlc and reads back', () async {
    final created = await repo.create(
      equipmentId: 'reg',
      diveId: 'd1',
      observedAt: DateTime.utc(2026, 9, 9, 15),
      status: ObservationStatus.issue,
      issueTags: const [ObservationTag.freeFlow, ObservationTag.other],
      note: 'Free flow at depth',
      now: DateTime.utc(2026, 9, 9, 16),
    );
    expect(created.id, isNotEmpty);
    expect(created.createdAt, DateTime.utc(2026, 9, 9, 16));

    final stored = await repo.getById(created.id);
    expect(stored, created);

    final row = await (db.select(
      db.equipmentObservations,
    )..where((t) => t.id.equals(created.id))).getSingle();
    expect(row.issueTags, '["freeFlow","other"]');
    expect(row.status, 'issue');
    expect(row.hlc, isNotNull);
  });

  test('an OK check stores and exports no tags, known or unknown', () async {
    // An imported or synced OK row can arrive carrying tags; the invariant
    // is that an OK check has none, so neither the row nor an export (which
    // writes storedTagNames) may carry them.
    final created = await repo.create(
      equipmentId: 'reg',
      observedAt: DateTime.utc(2026, 9, 9, 15),
      status: ObservationStatus.ok,
      issueTags: const [ObservationTag.freeFlow],
      unrecognizedTags: const ['tagFromTheFuture'],
      now: DateTime.utc(2026, 9, 9, 16),
    );
    final row = await (db.select(
      db.equipmentObservations,
    )..where((t) => t.id.equals(created.id))).getSingle();
    expect(row.issueTags, '[]');
    expect(created.storedTagNames, isEmpty);
  });

  test('queries by item, by dive and by both, newest first', () async {
    await repo.create(
      equipmentId: 'reg',
      diveId: 'd1',
      observedAt: DateTime.utc(2026, 1, 1),
      status: ObservationStatus.ok,
    );
    await repo.create(
      equipmentId: 'reg',
      diveId: 'd2',
      observedAt: DateTime.utc(2026, 2, 1),
      status: ObservationStatus.issue,
      issueTags: const [ObservationTag.leak],
    );
    await repo.create(
      equipmentId: 'reg',
      observedAt: DateTime.utc(2026, 3, 1),
      status: ObservationStatus.ok,
    );

    final byItem = await repo.getForEquipment('reg');
    expect(byItem.map((o) => o.observedAt.month), [3, 2, 1]);
    expect((await repo.getForDive('d2')).single.isIssue, isTrue);
    expect(await repo.getForEquipmentOnDive('reg', 'd1'), hasLength(1));
    expect(await repo.getForEquipmentOnDive('reg', 'nope'), isEmpty);
    expect(await repo.getAll(), hasLength(3));
  });

  test('update rewrites the row and bumps updatedAt', () async {
    final created = await repo.create(
      equipmentId: 'reg',
      diveId: 'd1',
      observedAt: DateTime.utc(2026, 1, 1),
      status: ObservationStatus.ok,
      now: DateTime.utc(2026, 1, 1),
    );
    await repo.update(
      created.copyWith(
        status: ObservationStatus.issue,
        issueTags: const [ObservationTag.hoseDamage],
        note: 'Hose cracked',
      ),
      now: DateTime.utc(2026, 1, 2),
    );
    final stored = await repo.getById(created.id);
    expect(stored!.isIssue, isTrue);
    expect(stored.issueTags, [ObservationTag.hoseDamage]);
    expect(stored.note, 'Hose cracked');
    expect(stored.updatedAt, DateTime.utc(2026, 1, 2));
  });

  test('delete removes the row and logs a deletion', () async {
    final created = await repo.create(
      equipmentId: 'reg',
      observedAt: DateTime.utc(2026, 1, 1),
      status: ObservationStatus.ok,
    );
    await repo.delete(created.id);
    expect(await repo.getById(created.id), isNull);
    final tombstones = await db.select(db.deletionLog).get();
    expect(
      tombstones.where((t) => t.recordId == created.id).single.entityType,
      'equipmentObservations',
    );
  });

  test('deleting the item cascades, deleting the dive sets null', () async {
    final onDive = await repo.create(
      equipmentId: 'reg',
      diveId: 'd1',
      observedAt: DateTime.utc(2026, 1, 1),
      status: ObservationStatus.ok,
    );
    await (db.delete(db.dives)..where((t) => t.id.equals('d1'))).go();
    expect((await repo.getById(onDive.id))!.diveId, isNull);

    await (db.delete(db.equipment)..where((t) => t.id.equals('reg'))).go();
    expect(await repo.getById(onDive.id), isNull);
  });

  test('a tag this build does not know is dropped on read', () async {
    final created = await repo.create(
      equipmentId: 'reg',
      observedAt: DateTime.utc(2026, 1, 1),
      status: ObservationStatus.issue,
      issueTags: const [ObservationTag.leak],
    );
    await (db.update(
      db.equipmentObservations,
    )..where((t) => t.id.equals(created.id))).write(
      const EquipmentObservationsCompanion(
        issueTags: Value('["leak","futureTag"]'),
      ),
    );
    expect((await repo.getById(created.id))!.issueTags, [ObservationTag.leak]);
  });

  test('an edit here keeps the tags this build does not know', () async {
    // A newer peer's tag cannot be shown here, but writing the row back
    // without it would delete it on every device, the newer one included.
    final created = await repo.create(
      equipmentId: 'reg',
      observedAt: DateTime.utc(2026, 1, 1),
      status: ObservationStatus.issue,
      issueTags: const [ObservationTag.leak],
    );
    Future<String> storedTags() async => (await (db.select(
      db.equipmentObservations,
    )..where((t) => t.id.equals(created.id))).getSingle()).issueTags;
    await (db.update(
      db.equipmentObservations,
    )..where((t) => t.id.equals(created.id))).write(
      const EquipmentObservationsCompanion(
        issueTags: Value('["leak","futureTag"]'),
      ),
    );

    final read = (await repo.getById(created.id))!;
    expect(read.unrecognizedTags, ['futureTag']);
    await repo.update(read.copyWith(note: 'Serviced'));
    expect(await storedTags(), '["leak","futureTag"]');

    // An issue turned into an OK check keeps no tags at all.
    await repo.update(
      (await repo.getById(
        created.id,
      ))!.copyWith(status: ObservationStatus.ok, issueTags: const []),
    );
    expect(await storedTags(), '[]');
  });
}
