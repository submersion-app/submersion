import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/services/user_event_preservation.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Resync, reparse and a native re-download replace a dive's events; the
/// rows the diver authored (annotations among them) must survive every one
/// of them (#4109).
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    for (final id in ['c1', 'c2']) {
      await db.customStatement(
        'INSERT INTO dive_computers (id, name, created_at, updated_at) '
        'VALUES (?, ?, 1, 1)',
        [id, id],
      );
    }
  });
  tearDown(() => tearDownTestDatabase());

  Future<void> seed(String id, String source, {String? computerId}) =>
      db.customStatement(
        'INSERT INTO dive_profile_events '
        '(id, dive_id, timestamp, event_type, source, computer_id, created_at) '
        "VALUES (?, 'd1', 1, 'bookmark', ?, ?, 1)",
        [id, source, computerId],
      );

  test('nonUserEventIds lists imported and computed rows only', () async {
    await seed('u1', 'user');
    await seed('i1', 'imported', computerId: 'c1');
    await seed('i2', 'imported', computerId: 'c2');
    await seed('k1', 'computed');

    expect(
      await nonUserEventIds(db, 'd1'),
      unorderedEquals(['i1', 'i2', 'k1']),
    );
    expect(await nonUserEventIds(db, 'd1', computerId: 'c1'), ['i1']);
  });

  test('restampUserEvents marks every user row pending with a clock', () async {
    await seed('u1', 'user');
    await seed('u2', 'user');
    await seed('i1', 'imported');

    await restampUserEvents(
      db: db,
      sync: SyncRepository(database: db),
      diveId: 'd1',
      now: 5,
    );

    final pending = {
      for (final r in await db.select(db.syncRecords).get())
        if (r.syncStatus == 'pending' && r.entityType == 'diveProfileEvents')
          r.recordId,
    };
    expect(pending, {'u1', 'u2'});
    final rows = await db.select(db.diveProfileEvents).get();
    expect(rows.firstWhere((r) => r.id == 'u1').hlc, isNotNull);
    expect(rows.firstWhere((r) => r.id == 'i1').hlc, isNull);
  });
}
