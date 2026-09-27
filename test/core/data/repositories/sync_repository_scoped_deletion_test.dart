import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/event_scope_tombstone.dart';
import 'package:submersion/core/services/sync/hlc.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  setUp(() async => db = await setUpTestDatabase());
  tearDown(() => tearDownTestDatabase());

  test('logScopedDeletion writes one stamped tombstone', () async {
    await SyncRepository().logScopedDeletion(
      const EventScopeTombstone(diveId: 'd1', computerId: 'c1'),
    );
    final row = (await db.select(db.deletionLog).get()).single;
    expect(row.entityType, 'diveProfileEventsScope');
    expect(row.recordId, 'd1|c1');
    expect(row.originHlc, isNotNull);
    expect(row.originHlc, row.hlc);
  });

  test('relayScopedDeletion keeps the newest clock', () async {
    final repo = SyncRepository();
    final older = const Hlc(1000, 0, 'p').toString();
    final newer = const Hlc(2000, 0, 'p').toString();
    await repo.relayScopedDeletion(
      recordId: 'd1',
      deletedAt: 2000,
      originHlc: newer,
    );
    await repo.relayScopedDeletion(
      recordId: 'd1',
      deletedAt: 1000,
      originHlc: older,
    );
    await repo.relayScopedDeletion(recordId: 'd1', deletedAt: 5000);
    var row = (await db.select(db.deletionLog).get()).single;
    expect(row.originHlc, newer);
    expect(row.deletedAt, 2000);

    final newest = const Hlc(3000, 0, 'p').toString();
    await repo.relayScopedDeletion(
      recordId: 'd1',
      deletedAt: 3000,
      originHlc: newest,
    );
    row = (await db.select(db.deletionLog).get()).single;
    expect(row.originHlc, newest);
    expect(row.deletedAt, 3000);
  });
}
