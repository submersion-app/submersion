import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_initializer.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

import '../../../helpers/test_database.dart';

/// A repository whose [getDeviceId] always throws, to exercise the launch-safe
/// error branch of [SyncInitializer.reconcileDeviceIdentity].
class _ThrowingSyncRepository extends SyncRepository {
  @override
  Future<String> getDeviceId() async {
    throw StateError('boom');
  }
}

/// Tests for the launch-time device-identity reconciliation that recovers a
/// database restore.
///
/// All sync bookkeeping (device id, HLC clock, last-sync timestamp, cursors,
/// deletion log) lives inside the database, so a whole-DB restore silently
/// rewinds it to the backup's snapshot. Two anchors mirrored in
/// SharedPreferences survive the restore and reveal it: a per-database instance
/// token rotated each launch (the primary signal -- it catches a same-device
/// backup, whose device id is unchanged) and the device id (a secondary signal
/// that also names the identity to preserve). A launch-time mismatch on either
/// is the cue to re-baseline sync.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SyncRepository repository;
  late SharedPreferences prefs;
  late SyncInitializer initializer;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repository = SyncRepository();
    initializer = SyncInitializer(syncRepository: repository, prefs: prefs);
  });

  tearDown(() async {
    DatabaseService.instance.resetForTesting();
  });

  group('reconcileDeviceIdentity', () {
    test(
      'seeds the sentinel on first run without touching the baseline',
      () async {
        // Materialize metadata so updateLastSyncTime() (a bare UPDATE) sticks.
        await repository.getOrCreateMetadata();
        await repository.updateLastSyncTime(
          DateTime.fromMillisecondsSinceEpoch(5000),
        );
        final before = await repository.getDeviceId();

        final status = await initializer.reconcileDeviceIdentity();

        expect(
          status,
          DeviceIdentityStatus.seeded,
          reason: 'the first run has no sentinel to compare against',
        );
        expect(
          await repository.getDeviceId(),
          before,
          reason: 'seeding must not change this installation identity',
        );
        expect(
          await repository.getLastSyncTime(),
          isNotNull,
          reason: 'seeding must not wipe a legitimate baseline',
        );

        // The sentinel now exists and matches, so a second run is a no-op.
        expect(
          await initializer.reconcileDeviceIdentity(),
          DeviceIdentityStatus.unchanged,
        );
      },
    );

    test(
      'is a no-op when the sentinel already matches the device id',
      () async {
        // First run seeds the sentinel from the current device id.
        await initializer.reconcileDeviceIdentity();
        await repository.updateLastSyncTime(
          DateTime.fromMillisecondsSinceEpoch(5000),
        );
        await repository.logDeletion(entityType: 'dives', recordId: 'keep-me');

        final status = await initializer.reconcileDeviceIdentity();

        expect(status, DeviceIdentityStatus.unchanged);
        expect(
          await repository.getLastSyncTime(),
          isNotNull,
          reason: 'a matching identity must not trigger a rebaseline',
        );
        expect(
          await repository.getAllDeletions(),
          isNotEmpty,
          reason: 'a matching identity must leave the deletion log intact',
        );
      },
    );

    test('rebaselines and restores the live identity after a restore', () async {
      // Establish this install's identity and seed the out-of-DB sentinel.
      await repository.setDeviceId('live-device');
      expect(
        await initializer.reconcileDeviceIdentity(),
        DeviceIdentityStatus.seeded,
      );

      // A restore swaps the whole DB: the in-DB device id becomes the backup's,
      // with a rewound baseline (stale lastSync) and a leftover tombstone.
      await repository.setDeviceId('backup-device');
      await repository.updateLastSyncTime(
        DateTime.fromMillisecondsSinceEpoch(1000),
      );
      await repository.logDeletion(
        entityType: 'dives',
        recordId: 'old-tombstone',
      );

      final status = await initializer.reconcileDeviceIdentity();

      expect(status, DeviceIdentityStatus.rebaselined);
      expect(
        await repository.getDeviceId(),
        'live-device',
        reason:
            'the live identity from the sentinel must replace the '
            "backup's device id",
      );
      expect(
        await repository.getLastSyncTime(),
        isNull,
        reason:
            'the rewound baseline must be cleared so the next sync does a '
            'full reconcile',
      );
      expect(
        await repository.getAllDeletions(),
        isEmpty,
        reason: "the backup's stale tombstones must be cleared",
      );

      // The sentinel now matches the restored identity, so the next launch is a
      // no-op rather than a second rebaseline.
      expect(
        await initializer.reconcileDeviceIdentity(),
        DeviceIdentityStatus.unchanged,
      );
    });

    test('detects a same-device restore from the instance token alone', () async {
      // Seed the anchors (device-id sentinel + instance token).
      expect(
        await initializer.reconcileDeviceIdentity(),
        DeviceIdentityStatus.seeded,
      );
      final liveId = await repository.getDeviceId();

      // A same-device hand-restore: the device id is unchanged (it is this
      // device's own backup), so the device-id sentinel still matches. The only
      // signal is that the restored DB carries a different instance token than
      // the copy mirrored in prefs -- plus a rewound baseline.
      await repository.rotateInstanceToken();
      await repository.updateLastSyncTime(
        DateTime.fromMillisecondsSinceEpoch(1000),
      );
      await repository.logDeletion(
        entityType: 'dives',
        recordId: 'old-tombstone',
      );

      final status = await initializer.reconcileDeviceIdentity();

      expect(
        status,
        DeviceIdentityStatus.rebaselined,
        reason:
            'a token mismatch must trigger a rebaseline even when the device '
            'id is unchanged (the same-device-backup blind spot)',
      );
      expect(
        await repository.getDeviceId(),
        liveId,
        reason: 'the unchanged same-device identity is preserved',
      );
      expect(await repository.getLastSyncTime(), isNull);
      expect(await repository.getAllDeletions(), isEmpty);

      // The anchors are re-aligned, so the next launch is a plain no-op.
      expect(
        await initializer.reconcileDeviceIdentity(),
        DeviceIdentityStatus.unchanged,
      );
    });

    test('rotates the instance token on a normal launch', () async {
      expect(
        await initializer.reconcileDeviceIdentity(),
        DeviceIdentityStatus.seeded,
      );
      final t1 = await repository.getInstanceToken();
      expect(t1, isNotNull);

      expect(
        await initializer.reconcileDeviceIdentity(),
        DeviceIdentityStatus.unchanged,
      );
      final t2 = await repository.getInstanceToken();

      expect(t2, isNotNull);
      expect(
        t2,
        isNot(t1),
        reason:
            'each launch rotates the token so a backup of this state becomes '
            'detectable once the live token advances past it',
      );
    });

    test('returns error and never throws when the lookup fails', () async {
      final throwingInitializer = SyncInitializer(
        syncRepository: _ThrowingSyncRepository(),
        prefs: prefs,
      );

      // Must not throw -- a reconcile failure cannot be allowed to crash launch.
      final status = await throwingInitializer.reconcileDeviceIdentity();

      expect(status, DeviceIdentityStatus.error);
    });
  });

  group('reconcileDeviceIdentityProvider', () {
    test('runs the reconcile and seeds anchors on first run', () async {
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final status = await container.read(
        reconcileDeviceIdentityProvider.future,
      );

      expect(status, DeviceIdentityStatus.seeded);
    });
  });

  group('adoptFreshIdentity', () {
    test('mints a new device id, persists it, and re-anchors it', () async {
      await initializer.reconcileDeviceIdentity();
      final oldId = await repository.getDeviceId();
      final oldToken = prefs.getString('sync_db_instance_token');

      final newId = await initializer.adoptFreshIdentity();

      expect(newId, isNot(oldId));
      expect(await repository.getDeviceId(), newId);
      expect(prefs.getString('sync_device_id_sentinel'), newId);
      expect(prefs.getString('sync_db_instance_token'), isNotNull);
      expect(prefs.getString('sync_db_instance_token'), isNot(oldToken));
    });

    test('a later launch reconcile keeps the fresh identity', () async {
      // Restore detection deliberately preserves the anchored identity, so a
      // regenerated id must be fully re-anchored or the next launch would
      // read it as a restore and revert it.
      await initializer.reconcileDeviceIdentity();
      final newId = await initializer.adoptFreshIdentity();

      final status = await initializer.reconcileDeviceIdentity();

      expect(status, DeviceIdentityStatus.unchanged);
      expect(await repository.getDeviceId(), newId);
      expect(prefs.getString('sync_device_id_sentinel'), newId);
    });
  });

  group('SyncNotifier.resetSyncState', () {
    test('adopts a fresh device identity', () async {
      // The twin-device trap: two installs syncing as the same device write
      // the same per-device file and each lists zero peers. Reset Sync State
      // is the user-facing recovery, so it must shed the identity, not just
      // the baseline.
      await initializer.reconcileDeviceIdentity();
      final oldId = await repository.getDeviceId();

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await container.read(syncStateProvider.notifier).resetSyncState();

      final newId = await repository.getDeviceId();
      expect(newId, isNot(oldId));
      expect(prefs.getString('sync_device_id_sentinel'), newId);
    });
  });
}
