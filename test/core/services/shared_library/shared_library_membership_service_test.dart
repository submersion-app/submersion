import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/shared_library/shared_library_membership_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

Future<void> _diver(String id) => DiverRepository().createDiver(
  Diver(id: id, name: id, createdAt: DateTime(2026), updatedAt: DateTime(2026)),
);

void main() {
  late FakeCloudStorageProvider cloud;
  late SharedLibraryMembershipService service;
  final account = ConnectedAccount(
    id: 'acc',
    kind: AccountKind.s3,
    label: 'Club bucket',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  setUp(() async {
    await setUpTestDatabase();
    await _diver('d1');
    cloud = FakeCloudStorageProvider();
    service = SharedLibraryMembershipService(
      store: SharedLibraryStore(),
      transportFor: ({required account, required prefix}) async =>
          SharedLibraryTransport(cloud, prefix: prefix),
    );
  });

  tearDown(() async {
    SyncCoordinator.reset();
    await tearDownTestDatabase();
  });

  test('probe, create, then a second profile joins', () async {
    expect(
      (await service.probe(account: account, prefix: 'club')).exists,
      isFalse,
    );
    final lib = await service.create(
      account: account,
      prefix: 'club',
      name: 'Club',
      diverId: 'd1',
      displayName: 'Ann',
    );
    final t = SharedLibraryTransport(cloud, prefix: 'club');
    expect((await t.readManifest())!['name'], 'Club');
    final me = (await SharedLibraryStore().membership(
      diverId: 'd1',
      libraryId: lib.id,
    ))!;
    expect((await t.readRoles()).roleOf(me.memberId), SharedLibraryRole.owner);
    expect((await t.listMembers()).single.displayName, 'Ann');
    expect(me.locationHint, 'Club bucket: club');
    expect(me.backendKind, 's3');
    final probe = await service.probe(account: account, prefix: 'club');
    expect(probe.exists, isTrue);
    expect(probe.name, 'Club');
    expect(probe.id, lib.id);

    await _diver('d2');
    final joined = await service.join(
      account: account,
      prefix: 'club',
      diverId: 'd2',
      displayName: 'Bob',
    );
    expect(joined.id, lib.id);
    expect(await t.listMembers(), hasLength(2));
    expect(await SharedLibraryStore().getLibraries(), hasLength(1));
    expect(
      await SharedLibraryStore().membershipsForLibrary(lib.id),
      hasLength(2),
    );
  });

  test('join refuses a prefix with no library or a newer format', () async {
    expect(
      () => service.join(
        account: account,
        prefix: 'empty',
        diverId: 'd1',
        displayName: 'Ann',
      ),
      throwsStateError,
    );
    await SharedLibraryTransport(
      cloud,
      prefix: 'new',
    ).writeManifest({'id': 'N', 'name': 'New', 'formatVersion': 99});
    expect(
      (await service.probe(account: account, prefix: 'new')).needsNewerApp,
      isTrue,
    );
    expect(
      () => service.join(
        account: account,
        prefix: 'new',
        diverId: 'd1',
        displayName: 'Ann',
      ),
      throwsStateError,
    );
  });

  test('join reads the folder through one transport', () async {
    await SharedLibraryTransport(
      cloud,
      prefix: 'club',
    ).writeManifest({'id': 'L', 'name': 'Club', 'formatVersion': 1});
    var built = 0;
    final counting = SharedLibraryMembershipService(
      store: SharedLibraryStore(),
      transportFor: ({required account, required prefix}) async {
        built++;
        return SharedLibraryTransport(cloud, prefix: prefix);
      },
    );
    await counting.join(
      account: account,
      prefix: 'club',
      diverId: 'd1',
      displayName: 'Ann',
    );
    // Each transport resolves its folders afresh (MKCOL or stat on WebDAV).
    expect(built, 1);
  });

  test('setRole rewrites roles and refuses to demote the last owner', () async {
    final lib = await service.create(
      account: account,
      prefix: 'club',
      name: 'Club',
      diverId: 'd1',
      displayName: 'Ann',
    );
    final me = (await SharedLibraryStore().membership(
      diverId: 'd1',
      libraryId: lib.id,
    ))!;
    await service.setRole(
      libraryId: lib.id,
      actingMemberId: me.memberId,
      memberId: 'other',
      role: SharedLibraryRole.editor,
    );
    expect(
      () => service.setRole(
        libraryId: lib.id,
        actingMemberId: 'other',
        memberId: me.memberId,
        role: SharedLibraryRole.reader,
      ),
      throwsStateError,
      reason: 'an editor may not change roles',
    );
    final roles = await SharedLibraryTransport(
      cloud,
      prefix: 'club',
    ).readRoles();
    expect(roles.roleOf('other'), SharedLibraryRole.editor);
    expect(
      (await SharedLibraryStore().getLibrary(lib.id))!.roles.roleOf('other'),
      SharedLibraryRole.editor,
    );
    expect(
      () => service.setRole(
        libraryId: lib.id,
        actingMemberId: me.memberId,
        memberId: me.memberId,
        role: SharedLibraryRole.editor,
      ),
      throwsStateError,
    );
  });

  test('rename updates the card, the membership and the cache', () async {
    final lib = await service.create(
      account: account,
      prefix: 'club',
      name: 'Club',
      diverId: 'd1',
      displayName: 'Ann',
    );
    await service.rename(
      libraryId: lib.id,
      diverId: 'd1',
      displayName: 'Annie',
    );
    final t = SharedLibraryTransport(cloud, prefix: 'club');
    expect((await t.listMembers()).single.displayName, 'Annie');
    final me = (await SharedLibraryStore().membership(
      diverId: 'd1',
      libraryId: lib.id,
    ))!;
    expect(me.displayName, 'Annie');
    expect((await SharedLibraryStore().memberNames(lib.id)).values, ['Annie']);
  });

  test(
    'leave removes the membership, the sites and the unused library',
    () async {
      final lib = await service.create(
        account: account,
        prefix: 'club',
        name: 'Club',
        diverId: 'd1',
        displayName: 'Ann',
      );
      await SiteRepository().createSite(
        DiveSite(id: 'lib', name: 'Club site', sharedLibraryId: lib.id),
      );
      await SharedLibraryStore().putSiteState(
        SharedSiteState(siteId: 'lib', libraryId: lib.id),
      );
      await service.leave(libraryId: lib.id, diverId: 'd1');
      expect(
        await SharedLibraryStore().membership(diverId: 'd1', libraryId: lib.id),
        isNull,
      );
      expect(await SharedLibraryStore().getLibrary(lib.id), isNull);
      expect(await SiteRepository().getSiteById('lib'), isNull);
      expect(
        await SharedLibraryTransport(cloud, prefix: 'club').listMembers(),
        isEmpty,
      );
    },
  );

  test('leave keeps the library while another profile is a member', () async {
    final lib = await service.create(
      account: account,
      prefix: 'club',
      name: 'Club',
      diverId: 'd1',
      displayName: 'Ann',
    );
    await _diver('d2');
    await service.join(
      account: account,
      prefix: 'club',
      diverId: 'd2',
      displayName: 'Bob',
    );
    await SiteRepository().createSite(
      DiveSite(id: 'lib', name: 'Club site', sharedLibraryId: lib.id),
    );
    await service.leave(libraryId: lib.id, diverId: 'd2');
    expect(await SharedLibraryStore().getLibrary(lib.id), isNotNull);
    expect(
      await SharedLibraryStore().membershipsForLibrary(lib.id),
      hasLength(1),
    );
    expect(
      (await SiteRepository().getSiteById('lib'))?.sharedLibraryId,
      lib.id,
      reason: 'the remaining profile keeps the shared sites',
    );
  });

  test('joining with a membership synced from another device reuses it, '
      'so leave ends the membership', () async {
    final lib = await service.create(
      account: account,
      prefix: 'club',
      name: 'Club',
      diverId: 'd1',
      displayName: 'Ann',
    );
    final store = SharedLibraryStore();
    final synced = (await store.membership(diverId: 'd1', libraryId: lib.id))!;
    // A second device: the membership arrived by personal sync, the
    // library itself is not connected here yet.
    await store.deleteLibrary(lib.id);

    await service.join(
      account: account,
      prefix: 'club',
      diverId: 'd1',
      displayName: 'Ann',
    );
    final rows = await store.membershipsForLibrary(lib.id);
    expect(rows, hasLength(1));
    expect(rows.single.id, synced.id);
    expect(rows.single.memberId, synced.memberId);

    await service.leave(libraryId: lib.id, diverId: 'd1');
    expect(await store.membershipsForLibrary(lib.id), isEmpty);
    expect(await store.getLibrary(lib.id), isNull);
  });

  test('create refuses a location that already holds a library', () async {
    final lib = await service.create(
      account: account,
      prefix: 'club',
      name: 'Club',
      diverId: 'd1',
      displayName: 'Ann',
    );
    await _diver('d2');
    await expectLater(
      service.create(
        account: account,
        prefix: 'club',
        name: 'Rival',
        diverId: 'd2',
        displayName: 'Bob',
      ),
      throwsStateError,
    );
    final t = SharedLibraryTransport(cloud, prefix: 'club');
    expect((await t.readManifest())!['id'], lib.id);
  });

  test(
    'setRole builds on the roles in the folder, not the cached copy',
    () async {
      final lib = await service.create(
        account: account,
        prefix: 'club',
        name: 'Club',
        diverId: 'd1',
        displayName: 'Ann',
      );
      final me = (await SharedLibraryStore().membership(
        diverId: 'd1',
        libraryId: lib.id,
      ))!;
      final t = SharedLibraryTransport(cloud, prefix: 'club');
      // Another owner promoted Carol since this device last synced.
      await t.writeRoles(
        (await t.readRoles()).withRole('carol', SharedLibraryRole.editor),
      );

      await service.setRole(
        libraryId: lib.id,
        actingMemberId: me.memberId,
        memberId: 'dan',
        role: SharedLibraryRole.editor,
      );
      final roles = await t.readRoles();
      expect(roles.roleOf('carol'), SharedLibraryRole.editor);
      expect(roles.roleOf('dan'), SharedLibraryRole.editor);
    },
  );

  test('the only owner cannot leave while other members remain', () async {
    final lib = await service.create(
      account: account,
      prefix: 'club',
      name: 'Club',
      diverId: 'd1',
      displayName: 'Ann',
    );
    await _diver('d2');
    await service.join(
      account: account,
      prefix: 'club',
      diverId: 'd2',
      displayName: 'Bob',
    );
    await expectLater(
      service.leave(libraryId: lib.id, diverId: 'd1'),
      throwsA(isA<LastOwnerLeaveError>()),
    );
    expect(
      await SharedLibraryStore().membership(diverId: 'd1', libraryId: lib.id),
      isNotNull,
    );
  });

  test('leave waits for a library sync in flight', () async {
    final lib = await service.create(
      account: account,
      prefix: 'club',
      name: 'Club',
      diverId: 'd1',
      displayName: 'Ann',
    );
    final gate = Completer<void>();
    final syncing = SyncCoordinator.run(() => gate.future);
    final leaving = service.leave(libraryId: lib.id, diverId: 'd1');
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(
      await SharedLibraryStore().membership(diverId: 'd1', libraryId: lib.id),
      isNotNull,
      reason: 'the running sync would re-create what leave removes',
    );
    gate.complete();
    await syncing;
    await leaving;
    expect(await SharedLibraryStore().getLibrary(lib.id), isNull);
  });

  test('leaving gives up the member\'s role in the library', () async {
    final lib = await service.create(
      account: account,
      prefix: 'club',
      name: 'Club',
      diverId: 'd1',
      displayName: 'Ann',
    );
    await _diver('d2');
    await service.join(
      account: account,
      prefix: 'club',
      diverId: 'd2',
      displayName: 'Bob',
    );
    final bob = (await SharedLibraryStore().membership(
      diverId: 'd2',
      libraryId: lib.id,
    ))!;
    final ann = (await SharedLibraryStore().membership(
      diverId: 'd1',
      libraryId: lib.id,
    ))!;
    await service.setRole(
      libraryId: lib.id,
      actingMemberId: ann.memberId,
      memberId: bob.memberId,
      role: SharedLibraryRole.editor,
    );

    await service.leave(libraryId: lib.id, diverId: 'd2');

    final roles = await SharedLibraryTransport(
      cloud,
      prefix: 'club',
    ).readRoles();
    expect(roles.roleOf(bob.memberId), SharedLibraryRole.reader);
    expect(roles.roleOf(ann.memberId), SharedLibraryRole.owner);
  });

  test('the last-owner rule reads the roles in the folder', () async {
    final lib = await service.create(
      account: account,
      prefix: 'club',
      name: 'Club',
      diverId: 'd1',
      displayName: 'Ann',
    );
    await _diver('d2');
    await service.join(
      account: account,
      prefix: 'club',
      diverId: 'd2',
      displayName: 'Bob',
    );
    final store = SharedLibraryStore();
    final ann = (await store.membership(diverId: 'd1', libraryId: lib.id))!;
    final bob = (await store.membership(diverId: 'd2', libraryId: lib.id))!;
    await service.setRole(
      libraryId: lib.id,
      actingMemberId: ann.memberId,
      memberId: bob.memberId,
      role: SharedLibraryRole.owner,
    );
    // Another device demoted Bob since; this device's cache still lists him.
    final t = SharedLibraryTransport(cloud, prefix: 'club');
    await t.writeRoles(SharedLibraryRoles(owners: {ann.memberId}));

    await expectLater(
      service.leave(libraryId: lib.id, diverId: 'd1'),
      throwsA(isA<LastOwnerLeaveError>()),
    );
    expect((await t.readRoles()).roleOf(ann.memberId), SharedLibraryRole.owner);
  });

  test('a library no local profile belongs to any more is released', () async {
    final lib = await service.create(
      account: account,
      prefix: 'club',
      name: 'Club',
      diverId: 'd1',
      displayName: 'Ann',
    );
    await SiteRepository().createSite(
      DiveSite(id: 'lib', name: 'Club site', sharedLibraryId: lib.id),
    );
    // The profile left on its other device: the membership tombstone
    // arrived here, the library row and its sites did not go.
    final store = SharedLibraryStore();
    final ann = (await store.membership(diverId: 'd1', libraryId: lib.id))!;
    await store.deleteMembership(ann.id);

    await service.releaseOrphanedLibraries(fallbackOwnerDiverId: 'd1');

    expect(await store.getLibrary(lib.id), isNull);
    expect(await SiteRepository().getSiteById('lib'), isNull);
  });
}
