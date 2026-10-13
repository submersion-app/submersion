import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/shared_library/backup/library_backup_archive.dart';
import 'package:submersion/core/services/shared_library/backup/library_backup_service.dart';
import 'package:submersion/core/services/shared_library/backup/library_restore_service.dart';
import 'package:submersion/core/services/shared_library/crypto/library_signer.dart';
import 'package:submersion/core/services/shared_library/library_encryption_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_membership_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/core/services/shared_library/shared_site_publisher.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../../helpers/fake_cloud_storage_provider.dart';
import '../../../../helpers/test_database.dart';

const _fast = KdfParams(m: 1024, t: 1);

void main() {
  late FakeCloudStorageProvider cloud;
  late FakeCloudStorageProvider Function(String prefix) cloudAt;
  late Directory dir;
  late SharedLibraryMembershipService memberships;
  late LibraryBackupService backups;
  late SharedLibrary lib;
  final account = ConnectedAccount(
    id: 'acc',
    kind: AccountKind.s3,
    label: 'Survey bucket',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  SharedLibraryService syncer() => SharedLibraryService(
    store: SharedLibraryStore(),
    transportFor: (l) => memberships.transportForLibrary(l),
  );

  LibraryRestoreService restorer({int Function()? nowMs}) =>
      LibraryRestoreService(
        store: SharedLibraryStore(),
        memberships: memberships,
        backups: backups,
        nowMs: nowMs,
      );

  Future<void> addSite(String id, String name) async {
    await SiteRepository().createSite(
      DiveSite(id: id, name: name, sharedLibraryId: lib.id),
    );
    await SharedLibraryStore().putSiteState(
      SharedSiteState(siteId: id, libraryId: lib.id, dirty: true),
    );
  }

  Future<String?> nameOf(String id) async =>
      (await SiteRepository().getSiteById(id))?.name;

  setUp(() async {
    await setUpTestDatabase();
    await DiverRepository().createDiver(
      Diver(
        id: 'd1',
        name: 'Ann',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    dir = Directory.systemTemp.createTempSync('library_restore_');
    cloud = FakeCloudStorageProvider();
    // The fake storage is flat: each folder gets its own.
    final elsewhere = <String, FakeCloudStorageProvider>{};
    cloudAt = (prefix) => prefix == 'site-sync'
        ? cloud
        : elsewhere.putIfAbsent(prefix, FakeCloudStorageProvider.new);
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
    lib = await memberships.create(
      account: account,
      prefix: 'site-sync',
      name: 'Reef Survey',
      diverId: 'd1',
      displayName: 'Ann',
    );
    await addSite('s1', 'Blue');
    await addSite('s2', 'Green');
    await syncer().sync(lib.id, diverId: 'd1');
  });

  tearDown(() async {
    SyncCoordinator.reset();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    await tearDownTestDatabase();
  });

  /// After the backup: s1 renamed, s2 deleted, s3 added.
  Future<String> backupThenChange() async {
    final record = await backups.backUp(libraryId: lib.id, diverId: 'd1');
    final s1 = (await SiteRepository().getSiteById('s1'))!;
    await SiteRepository().updateSite(
      s1.copyWith(name: 'Changed'),
      actingDiverId: 'd1',
    );
    await SharedSitePublisher().deleteFromLibrary(siteId: 's2', diverId: 'd1');
    await addSite('s3', 'New');
    await syncer().sync(lib.id, diverId: 'd1');
    return record.backupId;
  }

  test('restore brings the library back to the backup', () async {
    final backupId = await backupThenChange();
    await restorer().restore(
      libraryId: lib.id,
      diverId: 'd1',
      backupId: backupId,
    );
    await syncer().sync(lib.id, diverId: 'd1');
    expect(await nameOf('s1'), 'Blue');
    expect(await nameOf('s2'), 'Green');
    expect(await nameOf('s3'), isNull);

    // Another device of a member sees the same.
    await tearDownTestDatabase();
    await setUpTestDatabase();
    await DiverRepository().createDiver(
      Diver(
        id: 'd9',
        name: 'Bo',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    await memberships.join(
      account: account,
      prefix: 'site-sync',
      diverId: 'd9',
      displayName: 'Bo',
    );
    await syncer().sync(lib.id, diverId: 'd9');
    expect(await nameOf('s1'), 'Blue');
    expect(await nameOf('s2'), 'Green');
    expect(await nameOf('s3'), isNull);
  });

  test('restore wins with a slow clock', () async {
    final backupId = await backupThenChange();
    // The restoring device's clock reads long before every stamp.
    await restorer(
      nowMs: () => 1000,
    ).restore(libraryId: lib.id, diverId: 'd1', backupId: backupId);
    await syncer().sync(lib.id, diverId: 'd1');
    expect(await nameOf('s1'), 'Blue');
    expect(await nameOf('s3'), isNull);
  });

  test('a before-restore backup is made and pinned', () async {
    final backupId = await backupThenChange();
    await restorer().restore(
      libraryId: lib.id,
      diverId: 'd1',
      backupId: backupId,
    );
    final all = await backups.list(libraryId: lib.id);
    final before = all.where((r) => r.backupId != backupId).single;
    expect(before.pinned, isTrue);
    expect(before.beforeRestore, isTrue);
    expect(before.siteCount, 3);
  });

  test('roles come back, and the restoring owner stays owner', () async {
    final me = (await SharedLibraryStore().membership(
      diverId: 'd1',
      libraryId: lib.id,
    ))!;
    final backupId = (await backups.backUp(
      libraryId: lib.id,
      diverId: 'd1',
    )).backupId;
    await memberships.setRole(
      libraryId: lib.id,
      actingMemberId: me.memberId,
      memberId: 'later',
      role: SharedLibraryRole.editor,
    );
    await restorer().restore(
      libraryId: lib.id,
      diverId: 'd1',
      backupId: backupId,
    );
    final roles = await SharedLibraryTransport(
      cloud,
      prefix: 'site-sync',
    ).readRoles();
    expect(roles.roleOf('later'), SharedLibraryRole.reader);
    expect(roles.roleOf(me.memberId), SharedLibraryRole.owner);
  });

  Future<String> backupUnderAnEarlierKey() async {
    final encryption = LibraryEncryptionService(
      store: SharedLibraryStore(),
      memberships: memberships,
      kdf: _fast,
    );
    await encryption.turnOn(
      libraryId: lib.id,
      diverId: 'd1',
      passphrase: 'first passphrase',
    );
    final backupId = await backupThenChange();
    await encryption.changePassphrase(
      libraryId: lib.id,
      diverId: 'd1',
      passphrase: 'second passphrase',
    );
    return backupId;
  }

  test(
    'a backup under an earlier key the library keeps needs no secret',
    () async {
      final backupId = await backupUnderAnEarlierKey();
      await restorer().restore(
        libraryId: lib.id,
        diverId: 'd1',
        backupId: backupId,
      );
      await syncer().sync(lib.id, diverId: 'd1');
      expect(await nameOf('s1'), 'Blue');
      expect(await nameOf('s3'), isNull);
    },
  );

  test(
    'a backup under a key the library no longer keeps asks for it',
    () async {
      final backupId = await backupUnderAnEarlierKey();
      // Lost, as after the library was turned off and on again.
      final t = SharedLibraryTransport(cloud, prefix: 'site-sync');
      for (final f in await cloud.listFiles(namePattern: 'previous-keys-')) {
        await cloud.deleteFile(f.id);
      }
      expect(await t.readManifest(), isNotNull);
      await expectLater(
        restorer().restore(
          libraryId: lib.id,
          diverId: 'd1',
          backupId: backupId,
        ),
        throwsA(isA<BackupNeedsOldKeyError>()),
      );
      await restorer().restore(
        libraryId: lib.id,
        diverId: 'd1',
        backupId: backupId,
        oldSecret: 'first passphrase',
      );
      await syncer().sync(lib.id, diverId: 'd1');
      expect(await nameOf('s1'), 'Blue');
      expect(await nameOf('s3'), isNull);
    },
  );

  test('restore into an empty folder keeps the library id', () async {
    final record = await backups.backUp(libraryId: lib.id, diverId: 'd1');
    final moved = await restorer().restoreInto(
      account: account,
      prefix: 'moved',
      diverId: 'd1',
      displayName: 'Ann',
      path: record.localPath!,
    );
    expect(moved.library.id, lib.id);
    expect(moved.library.prefix, 'moved');
    expect(moved.oldStillThere, isTrue);
    final manifest = (await SharedLibraryTransport(
      cloudAt('moved'),
      prefix: 'moved',
    ).readManifest())!;
    expect(manifest['id'], lib.id);
  });

  test('a backup made by someone who is no owner is refused', () async {
    final t = SharedLibraryTransport(cloud, prefix: 'site-sync');
    final files = await t.snapshot();
    final stranger = await LibrarySigner.generate();
    final zip = await LibraryBackupArchive.build(
      files: files,
      header: LibraryBackupHeader(
        backupId: 'forged',
        libraryId: lib.id,
        name: 'Reef Survey',
        createdAt: DateTime.utc(2026),
        createdBy: 'stranger',
        createdByKey: stranger.publicKey,
        appVersion: 'x',
        automatic: false,
        note: '',
        siteCount: 2,
        memberCount: 1,
      ),
      key: stranger,
    );
    final path = p.join(dir.path, 'forged.zip');
    await File(path).writeAsBytes(Uint8List.fromList(zip));
    await backups.import(libraryId: lib.id, path: path);
    await expectLater(
      restorer().restore(libraryId: lib.id, diverId: 'd1', backupId: 'forged'),
      throwsA(
        isA<BackupRefusedError>().having((e) => e.reason, 'reason', 'creator'),
      ),
    );
    expect(await backups.list(libraryId: lib.id), hasLength(1));
  });
}
