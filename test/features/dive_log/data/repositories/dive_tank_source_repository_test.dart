import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/test_database.dart';

/// Issue #2716: the source rows a dive gains attribute its tanks, the way
/// they adopt its profile series; a deleted source lets go of them with a
/// clock, so peers hear of it.
void main() {
  late AppDatabase db;
  late DiveRepository repository;

  Future<void> computer(String id) => db
      .into(db.diveComputers)
      .insert(
        DiveComputersCompanion.insert(
          id: id,
          name: id,
          createdAt: 1,
          updatedAt: 1,
        ),
      );

  Future<void> tank(String id, {String? computerId, String? sourceId}) => db
      .into(db.diveTanks)
      .insert(
        DiveTanksCompanion.insert(
          id: id,
          diveId: 'd1',
        ).copyWith(computerId: Value(computerId), sourceId: Value(sourceId)),
      );

  DiveDataSourcesCompanion reading(String id, {String? computerId}) =>
      DiveDataSourcesCompanion.insert(
        id: id,
        diveId: 'd1',
        importedAt: DateTime.utc(2026),
        createdAt: DateTime.utc(2026),
      ).copyWith(computerId: Value(computerId));

  Future<Map<String, String?>> sources() async => {
    for (final t in await db.select(db.diveTanks).get()) t.id: t.sourceId,
  };

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'd1',
            diveDateTime: 1,
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await computer('c1');
    await computer('c2');
  });

  tearDown(tearDownTestDatabase);

  test('an import\'s source row claims the tanks written before it', () async {
    await tank('t1');
    await tank('t2');
    await repository.saveComputerReading(reading('s1'));
    expect(await sources(), {'t1': 's1', 't2': 's1'});
  });

  test('a restored pair of sources claims each tank by computer', () async {
    await tank('t1', computerId: 'c1');
    await tank('t2', computerId: 'c2');
    await repository.saveComputerReadings([
      reading('sa', computerId: 'c1'),
      reading('sb', computerId: 'c2'),
    ]);
    expect(await sources(), {'t1': 'sa', 't2': 'sb'});
  });

  test('deleting a source lets go of its tanks, staged for sync', () async {
    await repository.saveComputerReadings([reading('sa'), reading('sb')]);
    await tank('t1', sourceId: 'sa');
    await tank('t2', sourceId: 'sb');
    await repository.deleteComputerReading('sa');
    expect(await sources(), {'t1': null, 't2': 'sb'});
    final pending = {
      for (final r in await SyncRepository().getPendingRecords())
        if (r.entityType == 'diveTanks') r.recordId,
    };
    expect(pending, contains('t1'));
  });
}
