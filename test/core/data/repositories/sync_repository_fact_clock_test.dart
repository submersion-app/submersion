import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_fact_groups.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  Future<Map<String, String?>> clocksOf(String id) async {
    final r = await db
        .customSelect(
          'SELECT hlc, upload_facts_hlc, verify_facts_hlc '
          'FROM media WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .getSingle();
    return {
      'hlc': r.read<String?>('hlc'),
      'upload': r.read<String?>('upload_facts_hlc'),
      'verify': r.read<String?>('verify_facts_hlc'),
    };
  }

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement(
      "INSERT INTO media (id, file_path, created_at, updated_at) "
      "VALUES ('m1', '/x.jpg', 0, 0)",
    );
    await SyncRepository().markRecordPending(
      entityType: 'media',
      recordId: 'm1',
      localUpdatedAt: 0,
    );
  });
  tearDown(() async {
    DatabaseService.instance.resetForTesting();
    SyncClock.instance.reset();
  });

  test(
    'markFactsPending stamps only its group clock and marks pending',
    () async {
      final before = await clocksOf('m1');
      await SyncRepository().markFactsPending(
        entityType: 'media',
        recordId: 'm1',
        localUpdatedAt: 1,
        group: SyncFactGroups.mediaUpload,
      );
      final after = await clocksOf('m1');
      expect(after['hlc'], before['hlc'], reason: 'the row clock never moves');
      expect(after['upload'], isNotNull);
      expect(after['upload']!.compareTo(before['hlc']!), greaterThan(0));
      expect(after['verify'], before['verify']);
      final pending = await SyncRepository().getPendingRecords();
      expect(
        pending.any((r) => r.entityType == 'media' && r.recordId == 'm1'),
        isTrue,
      );
    },
  );

  test('markRecordPending can stamp fact clocks with the row clock', () async {
    await SyncRepository().markRecordPending(
      entityType: 'media',
      recordId: 'm1',
      localUpdatedAt: 2,
      alsoStamp: SyncFactGroups.of('media'),
    );
    final c = await clocksOf('m1');
    expect(c['upload'], c['hlc']);
    expect(c['verify'], c['hlc']);
  });

  test('any insert path gets fact clocks on its first pending mark', () async {
    // The network fetch pipeline and the signature inserts mark a row
    // pending without naming the groups; without initialisation their rows
    // keep null fact clocks, and a later caption edit's row clock would
    // then read as a fresh write to every group.
    await db.customStatement(
      "INSERT INTO media (id, file_path, created_at, updated_at) "
      "VALUES ('m2', '/y.jpg', 0, 0)",
    );

    await SyncRepository().markRecordPending(
      entityType: 'media',
      recordId: 'm2',
      localUpdatedAt: 0,
    );

    final c = await clocksOf('m2');
    expect(c['upload'], c['hlc']);
    expect(c['verify'], c['hlc']);
  });

  test('a later mark leaves an existing fact clock alone', () async {
    await SyncRepository().markFactsPending(
      entityType: 'media',
      recordId: 'm1',
      localUpdatedAt: 1,
      group: SyncFactGroups.mediaUpload,
    );
    final stamped = (await clocksOf('m1'))['upload'];

    await SyncRepository().markRecordPending(
      entityType: 'media',
      recordId: 'm1',
      localUpdatedAt: 2,
    );

    expect(
      (await clocksOf('m1'))['upload'],
      stamped,
      reason: 'a user edit must not claim the facts are new',
    );
  });

  test('the clock seed counts fact clocks', () async {
    await SyncRepository().markFactsPending(
      entityType: 'media',
      recordId: 'm1',
      localUpdatedAt: 3,
      group: SyncFactGroups.mediaVerification,
    );
    final verify = (await clocksOf('m1'))['verify']!;
    expect(await SyncRepository().maxRowHlc(), verify);
  });
}
