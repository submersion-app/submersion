import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/shared_library/crypto/library_signer.dart';
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
import '../../../helpers/shared_library_test_account.dart';

/// Owner actions write only roles every member will trust, and approve
/// only the key an owner compared (issue #2567).
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

  Future<void> diver(String id) => DiverRepository().createDiver(
    Diver(
      id: id,
      name: id,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  );

  setUp(() async {
    await setUpTestDatabase();
    await diver('d1');
    await diver('d2');
    cloud = FakeCloudStorageProvider();
    service = SharedLibraryMembershipService(
      accountById: anyTestAccount,
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

  SharedLibraryTransport folder() =>
      SharedLibraryTransport(cloud, prefix: 'site-sync');

  /// Ann owns the library; Bo has joined, his key not yet approved.
  Future<(SharedLibrary, SharedLibraryMembership, SharedLibraryMembership)>
  annAndBo() async {
    final lib = await service.create(
      account: account,
      prefix: 'site-sync',
      name: 'Reef Survey',
      diverId: 'd1',
      displayName: 'Ann',
    );
    await service.join(
      account: account,
      prefix: 'site-sync',
      diverId: 'd2',
      displayName: 'Bo',
    );
    final store = SharedLibraryStore();
    return (
      lib,
      (await store.membership(diverId: 'd1', libraryId: lib.id))!,
      (await store.membership(diverId: 'd2', libraryId: lib.id))!,
    );
  }

  test(
    'a card whose key changed after the owner compared it is refused',
    () async {
      final (lib, ann, bo) = await annAndBo();
      // Someone who may write member cards puts their own key on Bo's.
      final impostor = await LibrarySigner.generate();
      await folder().writeMember(
        await SharedLibraryMember.signed(
          memberId: bo.memberId,
          displayName: 'Bo',
          joinedAt: DateTime.utc(2026),
          key: impostor,
        ),
        appVersion: 'x',
      );
      await expectLater(
        service.approveMember(
          libraryId: lib.id,
          memberId: bo.memberId,
          actingMemberId: ann.memberId,
          publicKey: bo.signingKey!.publicKey,
        ),
        throwsA(isA<MemberKeyChangedError>()),
      );
      expect((await folder().readRoles()).approvedKeys[bo.memberId], isNull);
      // The list now shows the key that is really there.
      final cached = await SharedLibraryStore().getMembers(lib.id);
      expect(
        cached.singleWhere((m) => m.memberId == bo.memberId).publicKey,
        impostor.publicKey,
      );
    },
  );

  test('joining again keeps the roles this device trusts', () async {
    final (lib, _, bo) = await annAndBo();
    final trusted = (await SharedLibraryStore().getLibrary(lib.id))!.roles;
    // A file signed only by itself, naming Bo the sole owner: a sync here
    // refuses it.
    final forged = await trusted
        .copyWith(
          version: trusted.version + 7,
          owners: {bo.memberId},
          approvedKeys: {bo.memberId: bo.signingKey!.publicKey},
        )
        .signed(libraryId: lib.id, signedBy: bo.memberId, key: bo.signingKey!);
    await folder().writeRoles(forged);
    await SharedLibraryStore().setLibraryStatus(lib.id, rolesRejected: true);
    await diver('d3');
    await service.join(
      account: account,
      prefix: 'site-sync',
      diverId: 'd3',
      displayName: 'Cy',
    );
    final after = (await SharedLibraryStore().getLibrary(lib.id))!;
    expect(after.roles, trusted);
    expect(after.rolesRejected, isTrue);
  });

  test('leaving never puts older roles over ones it cannot trust', () async {
    final (lib, ann, bo) = await annAndBo();
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
      role: SharedLibraryRole.owner,
    );
    // Roles newer than this device knows, by an owner it does not trust
    // yet (as after changes it missed).
    final trusted = (await SharedLibraryStore().getLibrary(lib.id))!.roles;
    final stranger = await LibrarySigner.generate();
    final newer = await trusted
        .copyWith(version: trusted.version + 3)
        .signed(libraryId: lib.id, signedBy: 'someone', key: stranger);
    await folder().writeRoles(newer);
    await service.leave(libraryId: lib.id, diverId: 'd1');
    expect(await folder().readRoles(), newer);
  });

  test(
    'an owner whose key here is not the approved one signs nothing',
    () async {
      final (lib, ann, bo) = await annAndBo();
      await SharedLibraryStore().upsertMembership(
        ann.copyWith(signingKey: await LibrarySigner.generate()),
      );
      final before = await folder().readRoles();
      await expectLater(
        service.setRole(
          libraryId: lib.id,
          actingMemberId: ann.memberId,
          memberId: bo.memberId,
          role: SharedLibraryRole.editor,
        ),
        throwsStateError,
      );
      expect(await folder().readRoles(), before);
    },
  );
}
