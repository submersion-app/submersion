import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/shared_library/crypto/library_recovery.dart';
import 'package:submersion/core/services/shared_library/crypto/roles_trust.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
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
import '../../../helpers/shared_library_test_keys.dart';
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
    label: 'Survey bucket',
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
      recoveryKdf: const KdfParams(m: 1024, t: 1),
    );
  });

  tearDown(() async {
    SyncCoordinator.reset();
    await tearDownTestDatabase();
  });

  test('probe, create, then a second profile joins', () async {
    expect(
      (await service.probe(account: account, prefix: 'site-sync')).exists,
      isFalse,
    );
    final lib = await service.create(
      account: account,
      prefix: 'site-sync',
      name: 'Reef Survey',
      diverId: 'd1',
      displayName: 'Ann',
    );
    final t = SharedLibraryTransport(cloud, prefix: 'site-sync');
    expect((await t.readManifest())!['name'], 'Reef Survey');
    final me = (await SharedLibraryStore().membership(
      diverId: 'd1',
      libraryId: lib.id,
    ))!;
    expect((await t.readRoles()).roleOf(me.memberId), SharedLibraryRole.owner);
    expect((await t.listMembers()).single.displayName, 'Ann');
    expect(me.locationHint, 'Survey bucket: site-sync');
    expect(me.backendKind, 's3');
    final probe = await service.probe(account: account, prefix: 'site-sync');
    expect(probe.exists, isTrue);
    expect(probe.name, 'Reef Survey');
    expect(probe.id, lib.id);

    await _diver('d2');
    final joined = await service.join(
      account: account,
      prefix: 'site-sync',
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

  test('create and join give the profile a signing key', () async {
    await service.create(
      account: account,
      prefix: 'site-sync',
      name: 'Reef Survey',
      diverId: 'd1',
      displayName: 'Ann',
    );
    final key = await SharedLibraryStore().signingKeyForDiver('d1');
    expect(key, isNotNull);
    await _diver('d2');
    await service.join(
      account: account,
      prefix: 'site-sync',
      diverId: 'd2',
      displayName: 'Bo',
    );
    final other = await SharedLibraryStore().signingKeyForDiver('d2');
    expect(other, isNotNull);
    expect(other!.publicKey, isNot(key!.publicKey));
  });

  test('create signs the first roles and hands back a recovery code', () async {
    final created = await service.createWithRecovery(
      account: account,
      prefix: 'site-sync',
      name: 'Reef Survey',
      diverId: 'd1',
      displayName: 'Ann',
    );
    final me = (await SharedLibraryStore().membership(
      diverId: 'd1',
      libraryId: created.library.id,
    ))!;
    final roles = await SharedLibraryTransport(
      cloud,
      prefix: 'site-sync',
    ).readRoles();
    expect(roles.version, 1);
    expect(roles.owners, {me.memberId});
    expect(roles.approvedKeys[me.memberId], me.signingKey!.publicKey);
    expect(roles.signedBy, me.memberId);
    expect(await isSelfConsistent(roles), isTrue);
    final fromCode = await LibraryRecovery.derive(
      code: created.recoveryCode,
      salt: roles.recovery!.salt,
      kdf: KdfParams.fromJson(roles.recovery!.kdf),
    );
    expect(fromCode.publicKey, roles.recovery!.publicKey);
    expect(
      (await SharedLibraryStore().getLibrary(created.library.id))!.roles,
      roles,
    );
  });

  test('a role change is signed by the acting owner', () async {
    final lib = await service.create(
      account: account,
      prefix: 'site-sync',
      name: 'Reef Survey',
      diverId: 'd1',
      displayName: 'Ann',
    );
    final me = (await SharedLibraryStore().membership(
      diverId: 'd1',
      libraryId: lib.id,
    ))!;
    final t = SharedLibraryTransport(cloud, prefix: 'site-sync');
    final before = await t.readRoles();
    await service.setRole(
      libraryId: lib.id,
      actingMemberId: me.memberId,
      memberId: 'bo',
      role: SharedLibraryRole.editor,
    );
    final after = await t.readRoles();
    expect(after.version, before.version + 1);
    expect(after.roleOf('bo'), SharedLibraryRole.editor);
    expect(
      await judgeRoles(trusted: before, incoming: after),
      RolesVerdict.trusted,
    );
  });

  test('join refuses roles nobody with the right could have written', () async {
    final t = SharedLibraryTransport(cloud, prefix: 'site-sync');
    await t.writeManifest({
      'id': 'L',
      'name': 'Reef Survey',
      'formatVersion': SharedLibraryLayout.formatVersion,
    });
    await t.writeRoles(const SharedLibraryRoles(owners: {'x'}));
    await expectLater(
      service.join(
        account: account,
        prefix: 'site-sync',
        diverId: 'd1',
        displayName: 'Ann',
      ),
      throwsA(isA<UntrustedRolesError>()),
    );
    expect(await SharedLibraryStore().getLibrary('L'), isNull);
  });

  Future<(SharedLibrary, SharedLibraryMembership, SharedLibraryMembership)>
  ownerAndJoiner() async {
    final lib = await service.create(
      account: account,
      prefix: 'site-sync',
      name: 'Reef Survey',
      diverId: 'd1',
      displayName: 'Ann',
    );
    await _diver('d2');
    await service.join(
      account: account,
      prefix: 'site-sync',
      diverId: 'd2',
      displayName: 'Bo',
    );
    final ann = (await SharedLibraryStore().membership(
      diverId: 'd1',
      libraryId: lib.id,
    ))!;
    final bo = (await SharedLibraryStore().membership(
      diverId: 'd2',
      libraryId: lib.id,
    ))!;
    return (lib, ann, bo);
  }

  test('an owner approves a member\'s key', () async {
    final (lib, ann, bo) = await ownerAndJoiner();
    final t = SharedLibraryTransport(cloud, prefix: 'site-sync');
    final card = (await t.listMembers()).singleWhere(
      (m) => m.memberId == bo.memberId,
    );
    expect(isApprovedMember(card, await t.readRoles()), isFalse);
    await service.approveMember(
      libraryId: lib.id,
      memberId: bo.memberId,
      actingMemberId: ann.memberId,
    );
    final roles = await t.readRoles();
    expect(roles.approvedKeys[bo.memberId], bo.signingKey!.publicKey);
    expect(isApprovedMember(card, roles), isTrue);
  });

  test('only an owner approves', () async {
    final (lib, _, bo) = await ownerAndJoiner();
    await expectLater(
      service.approveMember(
        libraryId: lib.id,
        memberId: bo.memberId,
        actingMemberId: bo.memberId,
      ),
      throwsStateError,
    );
  });

  test('rejecting removes the card and any approval', () async {
    final (lib, ann, bo) = await ownerAndJoiner();
    await service.approveMember(
      libraryId: lib.id,
      memberId: bo.memberId,
      actingMemberId: ann.memberId,
    );
    await service.rejectMember(
      libraryId: lib.id,
      memberId: bo.memberId,
      actingMemberId: ann.memberId,
    );
    final t = SharedLibraryTransport(cloud, prefix: 'site-sync');
    expect(
      (await t.listMembers()).map((m) => m.memberId),
      isNot(contains(bo.memberId)),
    );
    expect((await t.readRoles()).approvedKeys, isNot(contains(bo.memberId)));
  });

  test('join reads the folder through one transport', () async {
    final folder = SharedLibraryTransport(cloud, prefix: 'site-sync');
    await folder.writeManifest({
      'id': 'L',
      'name': 'Reef Survey',
      'formatVersion': 1,
    });
    await folder.writeRoles(await signedTestRoles(owners: {'o'}));
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
      prefix: 'site-sync',
      diverId: 'd1',
      displayName: 'Ann',
    );
    // Each transport resolves its folders afresh (MKCOL or stat on WebDAV).
    expect(built, 1);
  });

  test('setRole rewrites roles and refuses to demote the last owner', () async {
    final lib = await service.create(
      account: account,
      prefix: 'site-sync',
      name: 'Reef Survey',
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
      prefix: 'site-sync',
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
      prefix: 'site-sync',
      name: 'Reef Survey',
      diverId: 'd1',
      displayName: 'Ann',
    );
    await service.rename(
      libraryId: lib.id,
      diverId: 'd1',
      displayName: 'Annie',
    );
    final t = SharedLibraryTransport(cloud, prefix: 'site-sync');
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
        prefix: 'site-sync',
        name: 'Reef Survey',
        diverId: 'd1',
        displayName: 'Ann',
      );
      await SiteRepository().createSite(
        DiveSite(id: 'lib', name: 'Library site', sharedLibraryId: lib.id),
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
        await SharedLibraryTransport(cloud, prefix: 'site-sync').listMembers(),
        isEmpty,
      );
    },
  );

  test('leave keeps the library while another profile is a member', () async {
    final lib = await service.create(
      account: account,
      prefix: 'site-sync',
      name: 'Reef Survey',
      diverId: 'd1',
      displayName: 'Ann',
    );
    await _diver('d2');
    await service.join(
      account: account,
      prefix: 'site-sync',
      diverId: 'd2',
      displayName: 'Bob',
    );
    await SiteRepository().createSite(
      DiveSite(id: 'lib', name: 'Library site', sharedLibraryId: lib.id),
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
      prefix: 'site-sync',
      name: 'Reef Survey',
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
      prefix: 'site-sync',
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
      prefix: 'site-sync',
      name: 'Reef Survey',
      diverId: 'd1',
      displayName: 'Ann',
    );
    await _diver('d2');
    await expectLater(
      service.create(
        account: account,
        prefix: 'site-sync',
        name: 'Rival',
        diverId: 'd2',
        displayName: 'Bob',
      ),
      throwsStateError,
    );
    final t = SharedLibraryTransport(cloud, prefix: 'site-sync');
    expect((await t.readManifest())!['id'], lib.id);
  });

  test(
    'setRole builds on the roles in the folder, not the cached copy',
    () async {
      final lib = await service.create(
        account: account,
        prefix: 'site-sync',
        name: 'Reef Survey',
        diverId: 'd1',
        displayName: 'Ann',
      );
      final me = (await SharedLibraryStore().membership(
        diverId: 'd1',
        libraryId: lib.id,
      ))!;
      final t = SharedLibraryTransport(cloud, prefix: 'site-sync');
      // Another owner promoted Carol since this device last synced.
      final before = await t.readRoles();
      await t.writeRoles(
        await before
            .withRole('carol', SharedLibraryRole.editor)
            .copyWith(version: before.version + 1)
            .signed(signedBy: me.memberId, key: me.signingKey!),
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
      prefix: 'site-sync',
      name: 'Reef Survey',
      diverId: 'd1',
      displayName: 'Ann',
    );
    await _diver('d2');
    await service.join(
      account: account,
      prefix: 'site-sync',
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
      prefix: 'site-sync',
      name: 'Reef Survey',
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

  test(
    'an editor who leaves keeps the role until an owner removes it',
    () async {
      final lib = await service.create(
        account: account,
        prefix: 'site-sync',
        name: 'Reef Survey',
        diverId: 'd1',
        displayName: 'Ann',
      );
      await _diver('d2');
      await service.join(
        account: account,
        prefix: 'site-sync',
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
        prefix: 'site-sync',
      ).readRoles();
      // Only an owner may sign roles: Bob's card goes, his role waits for
      // an owner (the Members page lists it under members who left).
      expect(roles.roleOf(bob.memberId), SharedLibraryRole.editor);
      expect(roles.roleOf(ann.memberId), SharedLibraryRole.owner);
      final cards = await SharedLibraryTransport(
        cloud,
        prefix: 'site-sync',
      ).listMembers();
      expect(cards.map((m) => m.memberId), isNot(contains(bob.memberId)));
    },
  );

  test('the last-owner rule reads the roles in the folder', () async {
    final lib = await service.create(
      account: account,
      prefix: 'site-sync',
      name: 'Reef Survey',
      diverId: 'd1',
      displayName: 'Ann',
    );
    await _diver('d2');
    await service.join(
      account: account,
      prefix: 'site-sync',
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
    final t = SharedLibraryTransport(cloud, prefix: 'site-sync');
    final before = await t.readRoles();
    await t.writeRoles(
      await before
          .copyWith(owners: {ann.memberId}, version: before.version + 1)
          .signed(signedBy: ann.memberId, key: ann.signingKey!),
    );

    await expectLater(
      service.leave(libraryId: lib.id, diverId: 'd1'),
      throwsA(isA<LastOwnerLeaveError>()),
    );
    expect((await t.readRoles()).roleOf(ann.memberId), SharedLibraryRole.owner);
  });

  test('a library no local profile belongs to any more is released', () async {
    final lib = await service.create(
      account: account,
      prefix: 'site-sync',
      name: 'Reef Survey',
      diverId: 'd1',
      displayName: 'Ann',
    );
    await SiteRepository().createSite(
      DiveSite(id: 'lib', name: 'Library site', sharedLibraryId: lib.id),
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
