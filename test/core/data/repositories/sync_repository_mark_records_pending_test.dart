import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';

import '../../../helpers/test_database.dart';

/// `markRecordsPending` is `markRecordPending` for rows written together: a
/// row it leaves has to look like one the single write left, pending and
/// carrying a clock the changeset writer's `hlc >` filter can see.
void main() {
  late AppDatabase db;
  final repo = SyncRepository();

  Future<List<String>> pendingIds(String entityType) async => [
    for (final r in await repo.getPendingRecords())
      if (r.entityType == entityType) r.recordId,
  ];

  Future<void> seedSites(int n) async {
    for (var i = 0; i < n; i++) {
      await db.customStatement(
        'INSERT INTO dive_sites (id, name, description, created_at, '
        "updated_at) VALUES ('s$i', 'Site', '', 0, 0)",
      );
    }
  }

  setUp(() async => db = await setUpTestDatabase());
  tearDown(tearDownTestDatabase);

  test('marks every row pending and stamps its clock', () async {
    await seedSites(3);

    await repo.markRecordsPending(
      entityType: 'diveSites',
      recordIds: ['s0', 's1', 's2'],
      localUpdatedAt: 7,
    );

    expect(await pendingIds('diveSites'), unorderedEquals(['s0', 's1', 's2']));
    final pending = await repo.getPendingRecords();
    expect(pending.map((r) => r.localUpdatedAt), everyElement(7));
    final unstamped = await db
        .customSelect('SELECT id FROM dive_sites WHERE hlc IS NULL')
        .get();
    expect(unstamped, isEmpty);
  });

  test('stamps a clock newer than the row held', () async {
    await seedSites(1);
    await repo.markRecordPending(
      entityType: 'diveSites',
      recordId: 's0',
      localUpdatedAt: 1,
    );
    Future<String> clock() async =>
        (await db
                .customSelect("SELECT hlc FROM dive_sites WHERE id = 's0'")
                .getSingle())
            .read<String>('hlc');
    final before = await clock();

    await repo.markRecordsPending(
      entityType: 'diveSites',
      recordIds: ['s0'],
      localUpdatedAt: 2,
    );

    expect((await clock()).compareTo(before), greaterThan(0));
  });

  test('stamps past one clock chunk', () async {
    await seedSites(501);

    await repo.markRecordsPending(
      entityType: 'diveSites',
      recordIds: [for (var i = 0; i < 501; i++) 's$i'],
      localUpdatedAt: 1,
    );

    final unstamped = await db
        .customSelect('SELECT id FROM dive_sites WHERE hlc IS NULL')
        .get();
    expect(unstamped, isEmpty);
  });

  test('an empty list writes nothing', () async {
    await repo.markRecordsPending(
      entityType: 'diveSites',
      recordIds: const [],
      localUpdatedAt: 1,
    );
    expect(await repo.getPendingRecords(), isEmpty);
  });

  test('an entity with no clock column still goes pending', () async {
    await repo.markRecordsPending(
      entityType: 'noClockEntity',
      recordIds: ['a', 'b'],
      localUpdatedAt: 1,
    );
    expect(await pendingIds('noClockEntity'), unorderedEquals(['a', 'b']));
  });

  test('a two-column key is stamped row by row', () async {
    await db.customStatement(
      "INSERT INTO dives (id, dive_date_time, created_at, updated_at) "
      "VALUES ('d', 0, 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO equipment (id, name, type, created_at, updated_at) "
      "VALUES ('e', 'Fins', 'fins', 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO dive_equipment (dive_id, equipment_id) VALUES ('d', 'e')",
    );

    await repo.markRecordsPending(
      entityType: 'diveEquipment',
      recordIds: ['d|e'],
      localUpdatedAt: 1,
    );

    expect(await pendingIds('diveEquipment'), ['d|e']);
    final stamped = await db
        .customSelect('SELECT hlc FROM dive_equipment')
        .getSingle();
    expect(stamped.read<String?>('hlc'), isNotNull);
  });

  test('a row with fact clocks gets them from the single write', () async {
    await db.customStatement(
      "INSERT INTO media (id, file_path, created_at, updated_at) "
      "VALUES ('m1', '/x.jpg', 0, 0)",
    );

    await repo.markRecordsPending(
      entityType: 'media',
      recordIds: ['m1'],
      localUpdatedAt: 1,
    );

    final row = await db
        .customSelect("SELECT hlc, upload_facts_hlc FROM media WHERE id = 'm1'")
        .getSingle();
    expect(row.read<String?>('hlc'), isNotNull);
    expect(row.read<String?>('upload_facts_hlc'), isNotNull);
  });
}
