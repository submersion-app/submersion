import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/event_scope_tombstone.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// A peer's scope tombstone (#1926) stands for every event on a dive, or
/// every event one computer recorded on it, that existed when the peer
/// deleted them. Applied here it must remove exactly those, and the merge
/// must not let a lagging peer's copy of one come back.
void main() {
  late AppDatabase db;
  late FakeCloudStorageProvider cloud;

  // The scope delete's clock and time. Event clocks are set around it.
  const deleteMs = 5000000;
  const deleteClock = Hlc(deleteMs, 0, 'peer');
  Hlc at(int offsetMs) => Hlc(deleteMs + offsetMs, 0, 'x');

  Future<void> addEvent(
    String id, {
    String? computerId,
    Hlc? hlc,
    int createdAt = 1000,
  }) async {
    await db.customStatement(
      'INSERT INTO dive_profile_events '
      '(id, dive_id, timestamp, event_type, computer_id, created_at, hlc) '
      "VALUES (?, 'd1', 60, 'bookmark', ?, ?, ?)",
      [id, computerId, createdAt, hlc?.toString()],
    );
  }

  Future<Set<String>> eventIds() async =>
      (await db.select(db.diveProfileEvents).get()).map((e) => e.id).toSet();

  setUp(() async {
    db = await setUpTestDatabase();
    cloud = FakeCloudStorageProvider();
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    for (final c in ['c1', 'c2']) {
      await db.customStatement(
        'INSERT INTO dive_computers (id, name, created_at, updated_at) '
        'VALUES (?, ?, 1, 1)',
        [c, c],
      );
    }
    await SyncRepository().clearAllSyncRecords();
  });
  tearDown(() => DatabaseService.instance.resetForTesting());

  Future<void> pull({
    String peer = 'peer-b',
    List<Map<String, dynamic>> events = const [],
    Map<String, List<SyncDeletion>> deletions = const {},
  }) async {
    final data = SyncData(diveProfileEvents: events);
    await seedPeerBaseFromPayload(
      cloud,
      peer,
      SyncPayload(
        version: syncFormatVersion,
        exportedAt: deleteMs + 5000,
        deviceId: peer,
        checksum: sha256
            .convert(utf8.encode(jsonEncode(data.toJson())))
            .toString(),
        data: data,
        deletions: deletions,
      ),
    );
    final result = await SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: cloud,
    ).performSync();
    expect(result.status, isNot(SyncResultStatus.error));
  }

  Map<String, List<SyncDeletion>> scope(String recordId, {Hlc? clock}) => {
    EventScopeTombstone.entityType: [
      SyncDeletion(
        id: recordId,
        deletedAt: deleteMs,
        hlc: (clock ?? deleteClock).toString(),
      ),
    ],
  };

  test('a dive scope deletes every older event and keeps newer ones', () async {
    await addEvent('e-old', computerId: 'c1', hlc: at(-1000));
    await addEvent('e-old-2', computerId: 'c2', hlc: at(-1));
    await addEvent('e-tie', hlc: at(0).copyWithNode('peer'));
    await addEvent('e-new', computerId: 'c1', hlc: at(1000));

    await pull(deletions: scope('d1'));

    expect(await eventIds(), {'e-new'});
  });

  test('a computer scope leaves other computers and unowned events', () async {
    await addEvent('e-c1', computerId: 'c1', hlc: at(-1000));
    await addEvent('e-c2', computerId: 'c2', hlc: at(-1000));
    await addEvent('e-none', hlc: at(-1000));

    await pull(deletions: scope('d1|c1'));

    expect(await eventIds(), {'e-c2', 'e-none'});
  });

  test('an event with no clock is judged by its creation time', () async {
    await addEvent('e-legacy-old', createdAt: deleteMs - 1);
    await addEvent('e-legacy-new', createdAt: deleteMs + 1);

    await pull(deletions: scope('d1'));

    expect(await eventIds(), {'e-legacy-new'});
  });

  test('a locally pending event survives', () async {
    await addEvent('e-pending', hlc: at(-1000));
    await SyncRepository().markRecordPending(
      entityType: 'diveProfileEvents',
      recordId: 'e-pending',
      localUpdatedAt: 1,
    );
    // markRecordPending stamps a fresh clock; put it back below the delete
    // so only the pending mark can be what keeps the row.
    await db.customStatement(
      "UPDATE dive_profile_events SET hlc = ? WHERE id = 'e-pending'",
      [at(-1000).toString()],
    );

    await pull(deletions: scope('d1'));

    expect(await eventIds(), {'e-pending'});
  });

  test(
    'the scope is stored for relay with the deleting peer\'s clock',
    () async {
      await pull(deletions: scope('d1|c1'));

      final logged = (await SyncRepository().getAllDeletions()).single;
      expect(logged.entityType, EventScopeTombstone.entityType);
      expect(logged.recordId, 'd1|c1');
      expect(logged.originHlc, deleteClock.toString());
      expect(logged.deletedAt, deleteMs);
    },
  );

  test('a lagging peer cannot bring a scope-deleted event back', () async {
    await addEvent('e-old', computerId: 'c1', hlc: at(-1000));
    final stale = (await SyncDataSerializer().fetchRecord(
      'diveProfileEvents',
      'e-old',
    ))!;

    await pull(deletions: scope('d1'));
    expect(await eventIds(), isEmpty);

    // Another peer that had not heard of the delete republishes the event,
    // and also carries one it created after the delete.
    await pull(
      peer: 'peer-c',
      events: [
        stale,
        {...stale, 'id': 'e-later', 'hlc': at(2000).toString()},
      ],
    );

    expect(await eventIds(), {'e-later'});
  });

  test('a malformed scope deletes nothing and the sync goes on', () async {
    await addEvent('e1', hlc: at(-1000));

    await pull(deletions: scope('d1|c1|extra'));

    expect(await eventIds(), {'e1'});
  });
}

extension on Hlc {
  Hlc copyWithNode(String node) => Hlc(physicalTime, counter, node);
}
