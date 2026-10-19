import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/shared_library/member_removal.dart';
import 'package:submersion/core/services/shared_library/shared_library_membership_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

Future<void> _diver(String id) => DiverRepository().createDiver(
  Diver(id: id, name: id, createdAt: DateTime(2026), updatedAt: DateTime(2026)),
);

/// An owner removes a member and allows them back (issue #3481).
void main() {
  late FakeCloudStorageProvider cloud;
  late SharedLibraryMembershipService service;
  late SharedLibraryTransport t;
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
    t = SharedLibraryTransport(cloud, prefix: 'site-sync');
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

  /// Ann owns the library; Bo joined, was approved and made an editor.
  Future<(SharedLibrary, SharedLibraryMembership, SharedLibraryMembership)>
  ownerAndEditor() async {
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
    final store = SharedLibraryStore();
    final ann = (await store.membership(diverId: 'd1', libraryId: lib.id))!;
    final bo = (await store.membership(diverId: 'd2', libraryId: lib.id))!;
    await service.approveMember(
      libraryId: lib.id,
      memberId: bo.memberId,
      actingMemberId: ann.memberId,
      publicKey: bo.signingKey!.publicKey,
    );
    await service.setRole(
      libraryId: lib.id,
      actingMemberId: ann.memberId,
      memberId: bo.memberId,
      role: SharedLibraryRole.editor,
    );
    return (lib, ann, bo);
  }

  test('removing an approved editor', () async {
    final (lib, ann, bo) = await ownerAndEditor();
    final before = DateTime.now();
    await service.removeMember(
      libraryId: lib.id,
      memberId: bo.memberId,
      actingMemberId: ann.memberId,
    );
    final roles = await t.readRoles();
    expect(roles.roleOf(bo.memberId), SharedLibraryRole.reader);
    expect(roles.approvedKeys, isNot(contains(bo.memberId)));
    final retired = roles.retired[bo.memberId]!.single;
    expect(retired.key, bo.signingKey!.publicKey);
    expect(
      retired.untilMs,
      greaterThanOrEqualTo(before.millisecondsSinceEpoch),
    );
    expect(
      (await t.listMembers()).map((m) => m.memberId),
      isNot(contains(bo.memberId)),
    );
    final record = (await t.listRemovals()).single;
    expect(record.memberId, bo.memberId);
    expect(record.displayName, 'Bo');
    expect(record.publicKey, bo.signingKey!.publicKey);
    expect(record.removedBy, ann.memberId);
    expect(await record.verify(lib.id, roles), isTrue);
    expect(await SharedLibraryStore().removals(lib.id), [record]);
    expect(
      (await SharedLibraryStore().getMembers(lib.id)).map((m) => m.memberId),
      isNot(contains(bo.memberId)),
    );
  });

  test('an owner cannot remove themselves', () async {
    final (lib, ann, _) = await ownerAndEditor();
    await expectLater(
      service.removeMember(
        libraryId: lib.id,
        memberId: ann.memberId,
        actingMemberId: ann.memberId,
      ),
      throwsStateError,
    );
    expect(await t.listRemovals(), isEmpty);
  });

  test('only an owner removes', () async {
    final (lib, ann, bo) = await ownerAndEditor();
    await expectLater(
      service.removeMember(
        libraryId: lib.id,
        memberId: ann.memberId,
        actingMemberId: bo.memberId,
      ),
      throwsStateError,
    );
    expect(await t.listRemovals(), isEmpty);
  });

  test('a refused roles write leaves no record and the card', () async {
    final (lib, ann, bo) = await ownerAndEditor();
    cloud.failUploadsNamed = SharedLibraryLayout.rolesFile;
    await expectLater(
      service.removeMember(
        libraryId: lib.id,
        memberId: bo.memberId,
        actingMemberId: ann.memberId,
      ),
      throwsA(anything),
    );
    cloud.failUploadsNamed = null;
    expect(await t.listRemovals(), isEmpty);
    expect(
      (await t.listMembers()).map((m) => m.memberId),
      contains(bo.memberId),
    );
    expect((await t.readRoles()).approvedKeys, contains(bo.memberId));
  });

  test('allow back deletes the record and leaves the roles', () async {
    final (lib, ann, bo) = await ownerAndEditor();
    await service.removeMember(
      libraryId: lib.id,
      memberId: bo.memberId,
      actingMemberId: ann.memberId,
    );
    final roles = await t.readRoles();
    await service.allowBack(
      libraryId: lib.id,
      memberId: bo.memberId,
      actingMemberId: ann.memberId,
    );
    expect(await t.listRemovals(), isEmpty);
    expect(await SharedLibraryStore().removals(lib.id), isEmpty);
    expect(await t.readRoles(), roles);
  });

  test('only an owner allows back', () async {
    final (lib, ann, bo) = await ownerAndEditor();
    await service.removeMember(
      libraryId: lib.id,
      memberId: bo.memberId,
      actingMemberId: ann.memberId,
    );
    await expectLater(
      service.allowBack(
        libraryId: lib.id,
        memberId: bo.memberId,
        actingMemberId: bo.memberId,
      ),
      throwsStateError,
    );
    expect(await t.listRemovals(), hasLength(1));
  });

  test('a member whose card is gone is removed by their approval', () async {
    final (lib, ann, bo) = await ownerAndEditor();
    await t.deleteMember(bo.memberId);
    await service.removeMember(
      libraryId: lib.id,
      memberId: bo.memberId,
      actingMemberId: ann.memberId,
    );
    final record = (await t.listRemovals()).single;
    expect(record.displayName, '');
    expect(record.publicKey, bo.signingKey!.publicKey);
  });

  test('removals are signed records an owner verifies', () async {
    final (lib, ann, bo) = await ownerAndEditor();
    await service.removeMember(
      libraryId: lib.id,
      memberId: bo.memberId,
      actingMemberId: ann.memberId,
    );
    expect(
      await validRemovals(await t.listRemovals(), lib.id, await t.readRoles()),
      hasLength(1),
    );
  });

  test('rejecting someone removed before keeps their past edits', () async {
    final (lib, ann, bo) = await ownerAndEditor();
    await service.removeMember(
      libraryId: lib.id,
      memberId: bo.memberId,
      actingMemberId: ann.memberId,
    );
    final retired = (await t.readRoles()).retired[bo.memberId];
    expect(retired, isNotNull);
    await service.allowBack(
      libraryId: lib.id,
      memberId: bo.memberId,
      actingMemberId: ann.memberId,
    );
    await service.rejectMember(
      libraryId: lib.id,
      memberId: bo.memberId,
      actingMemberId: ann.memberId,
    );
    expect((await t.readRoles()).retired[bo.memberId], retired);
  });

  group("an owner's removals outlive their ownership", () {
    /// Cy joins and is made an owner, then removes Bo.
    Future<(SharedLibrary, SharedLibraryMembership, SharedLibraryMembership)>
    cyRemovesBo() async {
      final (lib, ann, bo) = await ownerAndEditor();
      await _diver('d3');
      await service.join(
        account: account,
        prefix: 'site-sync',
        diverId: 'd3',
        displayName: 'Cy',
      );
      final cy = (await SharedLibraryStore().membership(
        diverId: 'd3',
        libraryId: lib.id,
      ))!;
      await service.approveMember(
        libraryId: lib.id,
        memberId: cy.memberId,
        actingMemberId: ann.memberId,
        publicKey: cy.signingKey!.publicKey,
      );
      await service.setRole(
        libraryId: lib.id,
        actingMemberId: ann.memberId,
        memberId: cy.memberId,
        role: SharedLibraryRole.owner,
      );
      await service.removeMember(
        libraryId: lib.id,
        memberId: bo.memberId,
        actingMemberId: cy.memberId,
      );
      return (lib, ann, cy);
    }

    Future<List<MemberRemoval>> valid(String libraryId) async =>
        validRemovals(await t.listRemovals(), libraryId, await t.readRoles());

    test('when that owner is removed', () async {
      final (lib, ann, cy) = await cyRemovesBo();
      await service.removeMember(
        libraryId: lib.id,
        memberId: cy.memberId,
        actingMemberId: ann.memberId,
      );
      final kept = await valid(lib.id);
      expect(kept.map((r) => r.memberId), hasLength(2));
      expect(kept.every((r) => r.removedBy == ann.memberId), isTrue);
      expect(await SharedLibraryStore().removals(lib.id), hasLength(2));
    });

    test('when someone resets ownership', () async {
      final (lib, _, _) = await cyRemovesBo();
      await _diver('d4');
      await service.join(
        account: account,
        prefix: 'site-sync',
        diverId: 'd4',
        displayName: 'Dee',
      );
      final dee = (await SharedLibraryStore().membership(
        diverId: 'd4',
        libraryId: lib.id,
      ))!;
      await service.resetOwnership(libraryId: lib.id, diverId: 'd4');
      final kept = await valid(lib.id);
      expect(kept.single.removedBy, dee.memberId);
      expect(await SharedLibraryStore().removals(lib.id), hasLength(1));
    });

    test('when that owner is made a reader', () async {
      final (lib, ann, cy) = await cyRemovesBo();
      await service.setRole(
        libraryId: lib.id,
        actingMemberId: ann.memberId,
        memberId: cy.memberId,
        role: SharedLibraryRole.reader,
      );
      expect(await valid(lib.id), hasLength(1));
      expect(await SharedLibraryStore().removals(lib.id), hasLength(1));
    });
  });
}
