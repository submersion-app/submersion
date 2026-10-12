import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/changeset_log/local_only_tombstone_gc.dart';
import 'package:submersion/core/services/sync/changeset_log/peer_cursor_store.dart';
import 'package:submersion/core/services/sync/changeset_log/publish_state_store.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_liveness.dart';

void main() {
  group('SyncHistoryEvidence', () {
    const neverSynced = SyncHistoryEvidence(
      providerConfigured: false,
      hasLastSyncTime: false,
      hasPeerCursors: false,
      hasPublishState: false,
      hasAcceptedEpoch: false,
    );

    test('a device with no provider and no history may GC', () {
      expect(neverSynced.hasEverSynced, isFalse);
      expect(neverSynced.allowsLocalOnlyGc, isTrue);
    });

    test('a connected provider blocks GC even with no history', () {
      // The cloud path owns GC while a provider is connected: it computes
      // the fleet-acked horizon from live peer manifests. Running the local
      // purge as well would race it with a weaker gate.
      const e = SyncHistoryEvidence(
        providerConfigured: true,
        hasLastSyncTime: false,
        hasPeerCursors: false,
        hasPublishState: false,
        hasAcceptedEpoch: false,
      );
      expect(e.allowsLocalOnlyGc, isFalse);
    });

    test('any single trace of a prior sync blocks GC', () {
      const traces = [
        SyncHistoryEvidence(
          providerConfigured: false,
          hasLastSyncTime: true,
          hasPeerCursors: false,
          hasPublishState: false,
          hasAcceptedEpoch: false,
        ),
        SyncHistoryEvidence(
          providerConfigured: false,
          hasLastSyncTime: false,
          hasPeerCursors: true,
          hasPublishState: false,
          hasAcceptedEpoch: false,
        ),
        SyncHistoryEvidence(
          providerConfigured: false,
          hasLastSyncTime: false,
          hasPeerCursors: false,
          hasPublishState: true,
          hasAcceptedEpoch: false,
        ),
        SyncHistoryEvidence(
          providerConfigured: false,
          hasLastSyncTime: false,
          hasPeerCursors: false,
          hasPublishState: false,
          hasAcceptedEpoch: true,
        ),
      ];
      for (final e in traces) {
        expect(e.hasEverSynced, isTrue, reason: '$e');
        expect(e.allowsLocalOnlyGc, isFalse, reason: '$e');
      }
    });
  });

  group('LocalOnlyTombstoneGc', () {
    late AppDatabase db;
    late SyncRepository repo;
    late LocalOnlyTombstoneGc gc;

    final now = DateTime.utc(2026, 9, 1, 12);
    final oldDeletedAt = now
        .subtract(const Duration(days: 31))
        .millisecondsSinceEpoch;
    final youngDeletedAt = now
        .subtract(const Duration(days: 1))
        .millisecondsSinceEpoch;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));
      repo = SyncRepository(database: db);
      gc = LocalOnlyTombstoneGc(
        syncRepository: repo,
        peerCursors: PeerCursorStore(db),
        publishStates: PublishStateStore(db),
      );
      // Mint the metadata row (device id) so the sync clock can configure
      // and every tombstone below carries an HLC, as it does in production.
      await repo.getOrCreateMetadata();
      await repo.logDeletion(
        entityType: 'dives',
        recordId: 'old',
        deletedAt: oldDeletedAt,
      );
      await repo.logDeletion(
        entityType: 'dives',
        recordId: 'young',
        deletedAt: youngDeletedAt,
      );
    });
    tearDown(() => db.close());

    Future<Set<String>> remaining() async =>
        (await repo.getAllDeletions()).map((d) => d.recordId).toSet();

    test('never-synced device purges tombstones past the floor only', () async {
      expect(await gc.run(now: now), isTrue);
      expect(await remaining(), {'young'});
    });

    test('the floor is SyncLiveness.gcFloorMillis, shared with the cloud '
        'path', () async {
      // Exactly at the floor is kept: the cloud path deletes strictly older.
      final atFloor = now.millisecondsSinceEpoch - SyncLiveness.gcFloorMillis;
      await repo.logDeletion(
        entityType: 'dives',
        recordId: 'at-floor',
        deletedAt: atFloor,
      );
      await repo.logDeletion(
        entityType: 'dives',
        recordId: 'past-floor',
        deletedAt: atFloor - 1,
      );
      await gc.run(now: now);
      expect(await remaining(), {'young', 'at-floor'});
    });

    test('a connected provider leaves the log to the cloud path', () async {
      await repo.setCloudProvider(CloudProviderType.s3);
      expect(await gc.run(now: now), isFalse);
      expect(await remaining(), {'old', 'young'});
    });

    test('a signed-out device that once synced keeps its tombstones', () async {
      // Sign-out clears the provider but not the last sync time: the cloud
      // still holds this device's log, and a peer may still need these.
      await repo.setCloudProvider(CloudProviderType.s3);
      await repo.updateLastSyncTime(
        now.subtract(const Duration(days: 90)),
        providerId: 's3',
      );
      await repo.setCloudProvider(null);

      expect(await gc.run(now: now), isFalse);
      expect(await remaining(), {'old', 'young'});
    });

    test('a peer cursor alone is evidence of a prior sync', () async {
      await PeerCursorStore(
        db,
      ).upsert(peerDeviceId: 'peer-1', provider: 's3', lastSeqApplied: 3);
      expect(await gc.run(now: now), isFalse);
      expect(await remaining(), {'old', 'young'});
    });

    test('a publish state alone is evidence of a prior sync', () async {
      // A single-device cloud library has no peers and so no peer cursors;
      // its own publish row is the only transport-side trace it ever synced.
      await PublishStateStore(db).upsert(
        LocalPublishStatesCompanion(
          provider: const Value('icloud'),
          baseSeq: const Value(1),
          headSeq: const Value(1),
          updatedAt: Value(now.millisecondsSinceEpoch),
        ),
      );
      expect(await gc.run(now: now), isFalse);
      expect(await remaining(), {'old', 'young'});
    });

    test(
      'an accepted library epoch alone is evidence of a prior sync',
      () async {
        // Survives the user-facing Reset Sync State, which wipes the cursor and
        // publish rows and the last sync time but leaves the epoch in place.
        await repo.setLastAcceptedEpochId('epoch-1');
        expect(await gc.run(now: now), isFalse);
        expect(await remaining(), {'old', 'young'});
      },
    );

    test('gatherEvidence reports each signal independently', () async {
      var e = await gc.gatherEvidence();
      expect(e.providerConfigured, isFalse);
      expect(e.hasLastSyncTime, isFalse);
      expect(e.hasPeerCursors, isFalse);
      expect(e.hasPublishState, isFalse);
      expect(e.hasAcceptedEpoch, isFalse);

      await repo.setCloudProvider(CloudProviderType.dropbox);
      await repo.updateLastSyncTime(now, providerId: 'dropbox');
      await repo.setLastAcceptedEpochId('epoch-2');
      e = await gc.gatherEvidence();
      expect(e.providerConfigured, isTrue);
      expect(e.hasLastSyncTime, isTrue);
      expect(e.hasAcceptedEpoch, isTrue);
    });
  });
}
