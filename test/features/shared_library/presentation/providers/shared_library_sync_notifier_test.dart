import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/shared_library/backup/library_backup_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_membership_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_sync_notifier.dart';

import '../../../../helpers/fake_cloud_storage_provider.dart';
import '../../../../helpers/shared_library_test_keys.dart';
import '../../../../helpers/test_database.dart';

void main() {
  tearDown(SyncCoordinator.reset);

  test(
    'syncAll syncs each connected library of the profile and records results',
    () async {
      await setUpTestDatabase();
      addTearDown(tearDownTestDatabase);
      await DiverRepository().createDiver(
        Diver(
          id: 'd1',
          name: 'Ann',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      final store = SharedLibraryStore();
      await store.upsertLibrary(
        const SharedLibrary(
          id: 'L',
          name: 'Reef Survey',
          connectedAccountId: 'acc',
          prefix: 'site-sync',
        ),
      );
      await store.upsertMembership(
        const SharedLibraryMembership(
          id: 'ms',
          diverId: 'd1',
          libraryId: 'L',
          memberId: 'm',
          displayName: 'Ann',
          libraryName: 'Reef Survey',
          backendKind: 's3',
        ),
      );
      // A membership the device has not connected: skipped, not failed.
      await store.upsertMembership(
        const SharedLibraryMembership(
          id: 'ms2',
          diverId: 'd1',
          libraryId: 'X',
          memberId: 'm',
          displayName: 'Ann',
          libraryName: 'Other',
          backendKind: 's3',
        ),
      );
      final cloud = FakeCloudStorageProvider();
      await SharedLibraryTransport(
        cloud,
        prefix: 'site-sync',
      ).writeManifest({'id': 'L', 'name': 'Reef Survey', 'formatVersion': 2});
      final container = ProviderContainer(
        overrides: [
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
          sharedLibraryTransportFactoryProvider.overrideWithValue(
            (lib) async => SharedLibraryTransport(cloud, prefix: lib.prefix),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(sharedLibrarySyncProvider.notifier).syncAll();

      final state = container.read(sharedLibrarySyncProvider);
      expect(state.syncing, isFalse);
      expect(state.lastResults.keys, ['L']);
      expect(state.lastResults['L']!.status, SharedLibrarySyncStatus.success);
      expect((await store.getLibrary('L'))!.lastSyncAt, isNotNull);
    },
  );

  test('syncOne reports notConnected for an unknown library', () async {
    await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);
    final container = ProviderContainer(
      overrides: [
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
        sharedLibraryTransportFactoryProvider.overrideWithValue(
          (lib) async => throw StateError('no account'),
        ),
      ],
    );
    addTearDown(container.dispose);
    final r = await container
        .read(sharedLibrarySyncProvider.notifier)
        .syncOne('nope');
    expect(r.status, SharedLibrarySyncStatus.notConnected);
  });

  test('a sync queued behind another merge survives the notifier '
      'being disposed', () async {
    await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);
    final gate = Completer<void>();
    final blocker = SyncCoordinator.run(() => gate.future);
    final container = ProviderContainer(
      overrides: [
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
        sharedLibraryTransportFactoryProvider.overrideWithValue(
          (lib) async => throw StateError('no account'),
        ),
      ],
    );
    final pending = container
        .read(sharedLibrarySyncProvider.notifier)
        .syncOne('nope');
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(SyncCoordinator.busy, isTrue);
    container.dispose();
    gate.complete();
    await blocker;
    await expectLater(pending, completes);
  });

  test('a failure while preparing a sync does not leave it syncing', () async {
    await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);
    final container = ProviderContainer(
      overrides: [
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
        sharedLibraryStoreProvider.overrideWithValue(_BrokenStore()),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(sharedLibrarySyncProvider.notifier);
    await expectLater(notifier.syncAll(), throwsStateError);
    expect(container.read(sharedLibrarySyncProvider).syncing, isFalse);
  });

  test('disposal while the memberships load does not throw', () async {
    await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);
    final store = _SlowStore();
    final container = ProviderContainer(
      overrides: [
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
        sharedLibraryStoreProvider.overrideWithValue(store),
      ],
    );
    final running = container
        .read(sharedLibrarySyncProvider.notifier)
        .syncAll();
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    container.dispose();
    store.release.complete();
    await expectLater(running, completes);
  });

  test(
    'a library the profile left on another device is released here',
    () async {
      await setUpTestDatabase();
      addTearDown(tearDownTestDatabase);
      await DiverRepository().createDiver(
        Diver(
          id: 'd1',
          name: 'Ann',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      final store = SharedLibraryStore();
      // A connected library with no membership left on this device.
      await store.upsertLibrary(
        const SharedLibrary(
          id: 'L',
          name: 'Reef Survey',
          connectedAccountId: 'acc',
          prefix: 'site-sync',
        ),
      );
      final container = ProviderContainer(
        overrides: [
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
        ],
      );
      addTearDown(container.dispose);

      await container.read(sharedLibrarySyncProvider.notifier).syncAll();

      expect(await store.getLibrary('L'), isNull);
    },
  );

  for (final owner in [true, false]) {
    test(
      owner
          ? "an owner's healthy sync makes the daily backup when due"
          : "a reader's sync makes no backup",
      () async {
        await setUpTestDatabase();
        addTearDown(tearDownTestDatabase);
        await DiverRepository().createDiver(
          Diver(
            id: 'd1',
            name: 'Ann',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        );
        final roles = await signedTestRoles(
          owners: owner ? {'m'} : {'o'},
          members: {'m'},
        );
        final store = SharedLibraryStore();
        await store.upsertLibrary(
          SharedLibrary(
            id: 'L',
            name: 'Reef Survey',
            connectedAccountId: 'acc',
            prefix: 'site-sync',
            roles: roles,
          ),
        );
        await store.upsertMembership(
          SharedLibraryMembership(
            id: 'ms',
            diverId: 'd1',
            libraryId: 'L',
            memberId: 'm',
            displayName: 'Ann',
            libraryName: 'Reef Survey',
            backendKind: 's3',
            signingKey: await testMemberKey('m'),
          ),
        );
        final cloud = FakeCloudStorageProvider();
        final t = SharedLibraryTransport(cloud, prefix: 'site-sync');
        await t.writeManifest({'id': 'L', 'formatVersion': 2});
        await t.writeRoles(roles);
        final backups = _RecordingBackups();
        final container = ProviderContainer(
          overrides: [
            validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
            sharedLibraryTransportFactoryProvider.overrideWithValue(
              (lib) async => SharedLibraryTransport(cloud, prefix: lib.prefix),
            ),
            libraryBackupServiceProvider.overrideWithValue(backups),
          ],
        );
        addTearDown(container.dispose);
        await container.read(sharedLibrarySyncProvider.notifier).syncAll();
        expect(backups.due, owner ? ['L'] : isEmpty);
      },
    );
  }
}

/// Lists one connected library, then fails when the sync reads it.
class _BrokenStore extends SharedLibraryStore {
  @override
  Future<List<SharedLibraryMembership>> membershipsForDiver(
    String diverId,
  ) async => const [
    SharedLibraryMembership(
      id: 'ms',
      diverId: 'd1',
      libraryId: 'L',
      memberId: 'm',
      displayName: 'Ann',
      libraryName: 'Reef Survey',
      backendKind: 's3',
    ),
  ];

  @override
  Future<List<SharedLibrary>> getLibraries() async => const [
    SharedLibrary(
      id: 'L',
      name: 'Reef Survey',
      connectedAccountId: 'a',
      prefix: 'p',
    ),
  ];

  @override
  Future<SharedLibrary?> getLibrary(String id) async =>
      throw StateError('database closed');
}

/// Holds the membership read until [release] completes.
class _SlowStore extends SharedLibraryStore {
  final release = Completer<void>();

  @override
  Future<List<SharedLibraryMembership>> membershipsForDiver(
    String diverId,
  ) async {
    await release.future;
    return const [];
  }
}

/// Records when an automatic backup was asked for.
class _RecordingBackups extends LibraryBackupService {
  _RecordingBackups()
    : super(
        store: SharedLibraryStore(),
        memberships: SharedLibraryMembershipService(
          store: SharedLibraryStore(),
          transportFor: ({required account, required prefix}) =>
              throw UnimplementedError(),
        ),
        backupsDirectory: () async => '',
      );

  final due = <String>[];

  @override
  Future<bool> backUpIfDue({
    required String libraryId,
    required String diverId,
  }) =>
      // A turn of its own, as the real one takes: the sync must have ended
      // its turn by now, or this never runs.
      SyncCoordinator.run(() async {
        due.add(libraryId);
        return true;
      });
}
