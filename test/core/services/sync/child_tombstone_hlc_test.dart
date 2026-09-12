import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// A child with its own HLC (a dive's tank, a gear link, an event...) has
/// no updatedAt, so the tombstone paths had no age to compare: a stale
/// delete from a peer removed a tank edited after it, and a peer's newer
/// copy could not revive a tank deleted here. A tombstone now carries the
/// clock of the delete itself (not the clock of whichever device relayed
/// it), and when both sides have a clock the newer one wins. A missing
/// clock on either side keeps the old rules.
void main() {
  late AppDatabase db;
  late FakeCloudStorageProvider cloud;
  late Hlc tankHlc;

  setUp(() async {
    db = await setUpTestDatabase();
    cloud = FakeCloudStorageProvider();
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await db.customStatement(
      "INSERT INTO dive_tanks (id, dive_id, volume) VALUES ('t1', 'd1', 11.1)",
    );
    await SyncRepository().markRecordPending(
      entityType: 'diveTanks',
      recordId: 't1',
      localUpdatedAt: 1,
    );
    final local = (await SyncDataSerializer().fetchRecord('diveTanks', 't1'))!;
    tankHlc = Hlc.parse(local['hlc'] as String);
    // This device has published; what follows is a peer's payload.
    await SyncRepository().clearAllSyncRecords();
  });
  tearDown(() => DatabaseService.instance.resetForTesting());

  Hlc shifted(int ms) => Hlc(tankHlc.physicalTime + ms, tankHlc.counter, 'b');

  Future<void> pull({
    List<Map<String, dynamic>> tanks = const [],
    Map<String, List<SyncDeletion>> deletions = const {},
  }) async {
    final data = SyncData(diveTanks: tanks);
    await seedPeerBaseFromPayload(
      cloud,
      'peer-b',
      SyncPayload(
        version: syncFormatVersion,
        exportedAt: tankHlc.physicalTime + 5000,
        deviceId: 'peer-b',
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

  Future<Map<String, dynamic>?> tank() =>
      SyncDataSerializer().fetchRecord('diveTanks', 't1');

  test('the wire carries a tombstone\'s clock', () {
    const withClock = SyncDeletion(id: 't1', deletedAt: 5, hlc: 'h');
    expect(SyncDeletion.fromJson(withClock.toJson()).hlc, 'h');
    // An older peer's tombstone has none.
    expect(SyncDeletion.fromJson({'id': 't1', 'deletedAt': 5}).hlc, isNull);
    expect(const SyncDeletion(id: 't1', deletedAt: 5).toJson(), {
      'id': 't1',
      'deletedAt': 5,
    });
  });

  group('a peer\'s tombstone for a tank', () {
    SyncDeletion tombstone(Hlc? hlc) => SyncDeletion(
      id: 't1',
      deletedAt: tankHlc.physicalTime,
      hlc: hlc?.toString(),
    );

    test('older than the tank\'s last edit leaves the tank', () async {
      // The peer deleted it, then this device edited and published the
      // tank before the delete arrived. The edit is the newer event.
      await pull(
        deletions: {
          'diveTanks': [tombstone(shifted(-1000))],
        },
      );
      expect((await tank())?['volume'], 11.1);
    });

    test('newer deletes it and keeps the deleter\'s clock', () async {
      final clock = shifted(1000);
      await pull(
        deletions: {
          'diveTanks': [tombstone(clock)],
        },
      );
      expect(await tank(), isNull);
      // Relayed onward, the tombstone still says when the delete happened,
      // not when this device heard of it.
      final logged = (await SyncRepository().getAllDeletions()).single;
      expect(logged.originHlc, clock.toString());
      final payload = await SyncDataSerializer().exportData(
        deviceId: 'me',
        deletions: [logged],
      );
      expect(payload.deletions['diveTanks']!.single.hlc, clock.toString());
    });

    test('with no clock deletes it, as before', () async {
      await pull(
        deletions: {
          'diveTanks': [tombstone(null)],
        },
      );
      expect(await tank(), isNull);
      // This device's own stamp says when it heard, not when the peer
      // deleted; relayed onward it would beat edits made in between.
      final logged = (await SyncRepository().getAllDeletions()).single;
      expect(logged.hlc, isNotNull);
      expect(logged.originHlc, isNull);
    });
  });

  group('a peer\'s copy of a tank deleted here', () {
    late Map<String, dynamic> row;
    late Hlc deletedHlc;

    setUp(() async {
      row = (await tank())!;
      await db.customStatement("DELETE FROM dive_tanks WHERE id = 't1'");
      await SyncRepository().logDeletion(
        entityType: 'diveTanks',
        recordId: 't1',
      );
      final logged = (await SyncRepository().getAllDeletions()).single;
      expect(logged.originHlc, logged.hlc, reason: 'a local delete is its own');
      deletedHlc = Hlc.parse(logged.originHlc!);
    });

    Hlc afterDelete(int ms) =>
        Hlc(deletedHlc.physicalTime + ms, deletedHlc.counter, 'b');

    test('edited after the delete revives it', () async {
      await pull(
        tanks: [
          {...row, 'volume': 7.0, 'hlc': afterDelete(1000).toString()},
        ],
      );
      expect((await tank())?['volume'], 7.0);
      expect(await SyncRepository().getAllDeletions(), isEmpty);
    });

    test('edited before the delete stays deleted', () async {
      await pull(
        tanks: [
          {...row, 'volume': 7.0, 'hlc': afterDelete(-1000).toString()},
        ],
      );
      expect(await tank(), isNull);
    });

    test('with no clock stays deleted, as before', () async {
      await pull(
        tanks: [
          {...row, 'volume': 7.0, 'hlc': null},
        ],
      );
      expect(await tank(), isNull);
    });
  });
}
