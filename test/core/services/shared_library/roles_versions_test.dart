import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/shared_library/backup/library_backup_archive.dart';
import 'package:submersion/core/services/shared_library/backup/library_backup_service.dart';
import 'package:submersion/core/services/shared_library/backup/library_restore_service.dart';
import 'package:submersion/core/services/shared_library/crypto/library_signer.dart';
import 'package:submersion/core/services/shared_library/crypto/roles_trust.dart';
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

const _fast = KdfParams(m: 1024, t: 1);

/// Roles are only ever written above every version a member may trust, so
/// no owner's change is undone and no member's device refuses the new ones
/// (issue #2567).
void main() {
  late FakeCloudStorageProvider cloud;
  late Map<String, FakeCloudStorageProvider> elsewhere;
  late Directory dir;
  late SharedLibraryMembershipService memberships;
  late LibraryBackupService backups;
  final account = ConnectedAccount(
    id: 'acc',
    kind: AccountKind.s3,
    label: 'Survey bucket',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  FakeCloudStorageProvider cloudAt(String prefix) => prefix == 'site-sync'
      ? cloud
      : elsewhere.putIfAbsent(prefix, FakeCloudStorageProvider.new);

  Future<void> diver(String id) => DiverRepository().createDiver(
    Diver(
      id: id,
      name: id,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  );

  LibraryRestoreService restorer() => LibraryRestoreService(
    store: SharedLibraryStore(),
    memberships: memberships,
    backups: backups,
  );

  SharedLibraryTransport folder([String prefix = 'site-sync']) =>
      SharedLibraryTransport(cloudAt(prefix), prefix: prefix);

  setUp(() async {
    await setUpTestDatabase();
    await diver('d1');
    await diver('d2');
    dir = Directory.systemTemp.createTempSync('roles_versions_');
    cloud = FakeCloudStorageProvider();
    elsewhere = {};
    memberships = SharedLibraryMembershipService(
      store: SharedLibraryStore(),
      transportFor: ({required account, required prefix}) async =>
          SharedLibraryTransport(cloudAt(prefix), prefix: prefix),
      recoveryKdf: _fast,
    );
    backups = LibraryBackupService(
      store: SharedLibraryStore(),
      memberships: memberships,
      backupsDirectory: () async => dir.path,
    );
  });

  tearDown(() async {
    SyncCoordinator.reset();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    await tearDownTestDatabase();
  });

  /// Ann owns the library; Bo has joined and is approved as an editor.
  Future<(SharedLibrary, SharedLibraryMembership, SharedLibraryMembership)>
  annAndBo() async {
    final lib = await memberships.create(
      account: account,
      prefix: 'site-sync',
      name: 'Reef Survey',
      diverId: 'd1',
      displayName: 'Ann',
    );
    await memberships.join(
      account: account,
      prefix: 'site-sync',
      diverId: 'd2',
      displayName: 'Bo',
    );
    final store = SharedLibraryStore();
    final ann = (await store.membership(diverId: 'd1', libraryId: lib.id))!;
    final bo = (await store.membership(diverId: 'd2', libraryId: lib.id))!;
    await memberships.approveMember(
      libraryId: lib.id,
      memberId: bo.memberId,
      actingMemberId: ann.memberId,
      publicKey: bo.signingKey!.publicKey,
    );
    await memberships.setRole(
      libraryId: lib.id,
      actingMemberId: ann.memberId,
      memberId: bo.memberId,
      role: SharedLibraryRole.editor,
    );
    return (lib, ann, bo);
  }

  /// Roles newer than this device knows, by an owner it does not trust
  /// (as after changes it missed), which its sync refused.
  Future<SharedLibraryRoles> refusedNewerRoles(SharedLibrary lib) async {
    final trusted = (await SharedLibraryStore().getLibrary(lib.id))!.roles;
    final newer = await trusted
        .copyWith(version: trusted.version + 2)
        .signed(
          libraryId: lib.id,
          signedBy: 'someone',
          key: await LibrarySigner.generate(),
        );
    await folder().writeRoles(newer);
    await SharedLibraryStore().setLibraryStatus(lib.id, rolesRejected: true);
    return newer;
  }

  test('an owner who refused newer roles writes none over them', () async {
    final (lib, ann, bo) = await annAndBo();
    final newer = await refusedNewerRoles(lib);
    await expectLater(
      memberships.setRole(
        libraryId: lib.id,
        actingMemberId: ann.memberId,
        memberId: bo.memberId,
        role: SharedLibraryRole.reader,
      ),
      throwsA(isA<RolesOutOfDateError>()),
    );
    expect(await folder().readRoles(), newer);
  });

  test('a restore over roles this device refused changes nothing', () async {
    final (lib, _, _) = await annAndBo();
    final record = await backups.backUp(libraryId: lib.id, diverId: 'd1');
    await refusedNewerRoles(lib);
    await expectLater(
      restorer().restore(
        libraryId: lib.id,
        diverId: 'd1',
        backupId: record.backupId,
      ),
      throwsA(isA<RolesOutOfDateError>()),
    );
    // No backup was made before a restore that never began.
    expect(
      (await backups.list(libraryId: lib.id)).single.backupId,
      record.backupId,
    );
  });

  test(
    'an owner who steps down to editor leaves roles a new member trusts',
    () async {
      final (lib, ann, bo) = await annAndBo();
      await memberships.setRole(
        libraryId: lib.id,
        actingMemberId: ann.memberId,
        memberId: bo.memberId,
        role: SharedLibraryRole.owner,
      );
      await memberships.setRole(
        libraryId: lib.id,
        actingMemberId: ann.memberId,
        memberId: ann.memberId,
        role: SharedLibraryRole.editor,
      );
      expect(
        await isSelfConsistent(await folder().readRoles(), libraryId: lib.id),
        isTrue,
      );
    },
  );

  test(
    'a library restored elsewhere is trusted by members who know later roles',
    () async {
      final (lib, ann, bo) = await annAndBo();
      final record = await backups.backUp(libraryId: lib.id, diverId: 'd1');
      // Changes after the backup, which every member's device trusts.
      await memberships.setRole(
        libraryId: lib.id,
        actingMemberId: ann.memberId,
        memberId: bo.memberId,
        role: SharedLibraryRole.reader,
      );
      final later = (await SharedLibraryStore().getLibrary(lib.id))!.roles;
      await restorer().restoreInto(
        account: account,
        prefix: 'moved',
        diverId: 'd1',
        displayName: 'Ann',
        path: record.localPath!,
      );
      final restored = await folder('moved').readRoles();
      expect(
        await judgeRoles(trusted: later, incoming: restored, libraryId: lib.id),
        RolesVerdict.trusted,
      );
      expect(restored.roleOf(ann.memberId), SharedLibraryRole.owner);
      expect(restored.approvedKeys[ann.memberId], ann.signingKey!.publicKey);
    },
  );

  test('a member who is no owner restores nothing elsewhere', () async {
    final (lib, _, _) = await annAndBo();
    final record = await backups.backUp(libraryId: lib.id, diverId: 'd1');
    await expectLater(
      restorer().restoreInto(
        account: account,
        prefix: 'moved',
        diverId: 'd2',
        displayName: 'Bo',
        path: record.localPath!,
      ),
      throwsA(isA<BackupRefusedError>()),
    );
    expect(await cloudAt('moved').listFiles(), isEmpty);
  });

  test(
    'joining where the membership came by personal sync keeps its key',
    () async {
      final lib = await memberships.create(
        account: account,
        prefix: 'site-sync',
        name: 'Reef Survey',
        diverId: 'd1',
        displayName: 'Ann',
      );
      final store = SharedLibraryStore();
      final ann = (await store.membership(diverId: 'd1', libraryId: lib.id))!;
      // Another device: the membership synced in, the library row not yet,
      // and another of the profile's memberships with a key of its own.
      await store.deleteLibrary(lib.id);
      await store.upsertMembership(
        SharedLibraryMembership(
          // Sorted first: the profile's key, as signingKeyForDiver finds it.
          id: '0-first',
          diverId: 'd1',
          libraryId: 'B',
          memberId: ann.memberId,
          displayName: 'Ann',
          libraryName: 'Wreck Survey',
          backendKind: 's3',
          signingKey: await LibrarySigner.generate(),
        ),
      );
      await memberships.join(
        account: account,
        prefix: 'site-sync',
        diverId: 'd1',
        displayName: 'Ann',
      );
      final card = (await folder().listMembers()).singleWhere(
        (m) => m.memberId == ann.memberId,
      );
      expect(card.publicKey, ann.signingKey!.publicKey);
    },
  );

  test('a device that refused newer roles can still leave', () async {
    final (lib, _, _) = await annAndBo();
    // Ann is the only owner in the roles this device trusts; who owns the
    // library now it cannot tell.
    await refusedNewerRoles(lib);
    await memberships.leave(libraryId: lib.id, diverId: 'd1');
    expect(
      await SharedLibraryStore().membership(diverId: 'd1', libraryId: lib.id),
      isNull,
    );
  });

  test(
    'only a roles change that moves a field verdict re-reads sites',
    () async {
      final (lib, ann, bo) = await annAndBo();
      final store = SharedLibraryStore();
      Future<String?> stamp() async =>
          (await store.getSiteState('s1'))?.remoteModifiedTime;
      Future<void> stamped() => store.putSiteState(
        SharedSiteState(
          siteId: 's1',
          libraryId: lib.id,
          remoteModifiedTime: '2026-10-01T00:00:00Z',
        ),
      );
      await stamped();
      // A new recovery code proves no edit and holds none back.
      await memberships.reissueRecoveryCode(libraryId: lib.id, diverId: 'd1');
      expect(await stamp(), isNotNull);
      // Bo as a reader no longer edits: his fields must be judged again.
      await memberships.setRole(
        libraryId: lib.id,
        actingMemberId: ann.memberId,
        memberId: bo.memberId,
        role: SharedLibraryRole.reader,
      );
      expect(await stamp(), isNull);
    },
  );
}
