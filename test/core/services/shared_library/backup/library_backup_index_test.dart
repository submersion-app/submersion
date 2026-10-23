import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/shared_library/backup/library_backup_archive.dart';
import 'package:submersion/core/services/shared_library/backup/library_backup_service.dart';
import 'package:submersion/core/services/shared_library/crypto/canonical_json.dart';
import 'package:submersion/core/services/shared_library/crypto/library_signer.dart';
import 'package:submersion/core/services/shared_library/library_encryption_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_membership_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../../helpers/fake_cloud_storage_provider.dart';
import '../../../../helpers/test_database.dart';
import '../../../../helpers/shared_library_test_account.dart';

const _fast = KdfParams(m: 1024, t: 1);

/// The backup list in storage and the daily backups hold up against what
/// other owners' devices and member files leave behind (issue #2567).
void main() {
  late FakeCloudStorageProvider cloud;
  late Directory dir;
  late SharedLibraryMembershipService memberships;
  late SharedLibrary lib;
  var clock = DateTime.utc(2026, 10, 1, 9);
  final account = ConnectedAccount(
    id: 'acc',
    kind: AccountKind.s3,
    label: 'Survey bucket',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  LibraryBackupService backups({DateTime Function()? now}) =>
      LibraryBackupService(
        store: SharedLibraryStore(),
        memberships: memberships,
        backupsDirectory: () async => dir.path,
        now: now ?? () => clock,
      );

  Future<SharedLibrary> libraryAt(String prefix) async {
    final made = await memberships.create(
      account: account,
      prefix: prefix,
      name: 'Reef Survey',
      diverId: 'd1',
      displayName: 'Ann',
    );
    await SiteRepository().createSite(
      DiveSite(id: 's1', name: 'Blue', sharedLibraryId: made.id),
    );
    await SharedLibraryStore().putSiteState(
      SharedSiteState(siteId: 's1', libraryId: made.id, dirty: true),
    );
    await SharedLibraryService(
      store: SharedLibraryStore(),
      transportFor: (l) => memberships.transportForLibrary(l),
    ).sync(made.id, diverId: 'd1');
    return made;
  }

  setUp(() async {
    clock = DateTime.utc(2026, 10, 1, 9);
    await setUpTestDatabase();
    await DiverRepository().createDiver(
      Diver(
        id: 'd1',
        name: 'Ann',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    dir = Directory.systemTemp.createTempSync('library_backup_index_');
    cloud = FakeCloudStorageProvider();
    memberships = SharedLibraryMembershipService(
      accountById: anyTestAccount,
      store: SharedLibraryStore(),
      transportFor: ({required account, required prefix}) async =>
          SharedLibraryTransport(cloud, prefix: prefix),
      recoveryKdf: _fast,
    );
    lib = await libraryAt('site-sync');
  });

  tearDown(() async {
    SyncCoordinator.reset();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    await tearDownTestDatabase();
  });

  SharedLibraryTransport transport() =>
      SharedLibraryTransport(cloud, prefix: 'site-sync');

  test('a stray file in the folder never spoils a backup', () async {
    await transport().writeRaw(
      'suggestions/suggestion-a..json',
      Uint8List.fromList(utf8.encode('{}')),
    );
    final record = await backups().backUp(libraryId: lib.id, diverId: 'd1');
    final read = await LibraryBackupArchive.read(
      File(record.localPath!).readAsBytesSync(),
    );
    expect(read.files.keys, contains('sites/site-s1.json'));
    expect(read.files.keys, isNot(contains('suggestions/suggestion-a..json')));
  });

  test(
    'an index signed by someone no longer an owner keeps its entries',
    () async {
      final first = await backups().backUp(libraryId: lib.id, diverId: 'd1');
      // The index as an owner who has since left signed it.
      final gone = await LibrarySigner.generate();
      final t = transport();
      final index = (await t.readBackupIndex())!;
      final unsigned = {...index}
        ..remove('signature')
        ..['signedBy'] = 'gone';
      await t.writeBackupIndex({
        ...unsigned,
        'signature': await LibrarySigner.sign(
          gone,
          utf8.encode(canonicalJson(unsigned)),
        ),
      });
      clock = clock.add(const Duration(minutes: 1));
      final second = await backups().backUp(libraryId: lib.id, diverId: 'd1');
      final ids = [
        for (final r in await backups().list(libraryId: lib.id))
          if (r.inStorage) r.backupId,
      ];
      expect(ids, containsAll([first.backupId, second.backupId]));
    },
  );

  test("another library's index lists nothing here", () async {
    final mine = await backups().backUp(libraryId: lib.id, diverId: 'd1');
    // An index this owner signed for another library, copied over this one.
    final t = transport();
    final index = (await t.readBackupIndex())!;
    final key = (await SharedLibraryStore().signingKeyForDiver('d1'))!;
    final unsigned = {...index}
      ..remove('signature')
      ..['libraryId'] = 'other-library';
    await t.writeBackupIndex({
      ...unsigned,
      'signature': await LibrarySigner.sign(
        key,
        utf8.encode(canonicalJson(unsigned)),
      ),
    });
    final listed = await backups().list(libraryId: lib.id);
    expect(listed.single.backupId, mine.backupId);
    expect(listed.single.inStorage, isFalse);
  });

  test(
    'a backup dated ahead of this clock never stops the daily one',
    () async {
      // Another owner's device, its clock a month fast.
      await backups(
        now: () => clock.add(const Duration(days: 30)),
      ).backUp(libraryId: lib.id, diverId: 'd1');
      await SharedLibraryStore().setLibraryStatus(lib.id);
      expect(
        await backups().backUpIfDue(libraryId: lib.id, diverId: 'd1'),
        isTrue,
      );
      clock = clock.add(const Duration(days: 1, hours: 1));
      expect(
        await backups().backUpIfDue(libraryId: lib.id, diverId: 'd1'),
        isTrue,
      );
    },
  );

  test('an imported backup outlives the daily pruning', () async {
    final record = await backups().backUp(libraryId: lib.id, diverId: 'd1');
    final copy = File(p.join(dir.path, 'kept.zip'))
      ..writeAsBytesSync(File(record.localPath!).readAsBytesSync());
    await backups().delete(
      record.backupId,
      libraryId: lib.id,
      diverId: 'd1',
      fromDevice: true,
      fromStorage: true,
    );
    await backups().import(libraryId: lib.id, path: copy.path);
    for (var i = 0; i < 9; i++) {
      clock = clock.add(const Duration(days: 1));
      await backups().backUpIfDue(libraryId: lib.id, diverId: 'd1');
    }
    final all = await backups().list(libraryId: lib.id);
    expect(all.map((r) => r.backupId), contains(record.backupId));
  });

  test(
    'a backup imported pinned stays pinned while storage lists it',
    () async {
      final record = await backups().backUp(libraryId: lib.id, diverId: 'd1');
      final copy = File(p.join(dir.path, 'kept.zip'))
        ..writeAsBytesSync(File(record.localPath!).readAsBytesSync());
      await backups().delete(
        record.backupId,
        libraryId: lib.id,
        diverId: 'd1',
        fromDevice: true,
        fromStorage: false,
      );
      await backups().import(libraryId: lib.id, path: copy.path);
      final listed = (await backups().list(libraryId: lib.id)).single;
      expect(listed.inStorage, isTrue);
      expect(listed.pinned, isTrue);
    },
  );

  test('a backup of a folder with dots in its name is listed', () async {
    await tearDownTestDatabase();
    await setUpTestDatabase();
    await DiverRepository().createDiver(
      Diver(
        id: 'd1',
        name: 'Ann',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    // The fake storage is flat: the second library gets its own.
    cloud = FakeCloudStorageProvider();
    final dotted = await libraryAt('reef..2026');
    final record = await backups().backUp(libraryId: dotted.id, diverId: 'd1');
    final listed = await backups().list(libraryId: dotted.id);
    expect(listed.single.backupId, record.backupId);
    expect(listed.single.inStorage, isTrue);
  });

  test('a folder name with spaces around it is one folder', () async {
    final other = _FolderNames();
    await SharedLibraryTransport(
      other,
      prefix: ' reef / ',
    ).writeManifest({'id': 'R'});
    expect(other.folders, [SharedLibraryLayout.librariesDir, 'reef']);
  });

  test('the note of an encrypted library stays sealed', () async {
    await LibraryEncryptionService(
      store: SharedLibraryStore(),
      memberships: memberships,
      kdf: _fast,
    ).turnOn(libraryId: lib.id, diverId: 'd1', passphrase: 'a passphrase');
    final record = await backups().backUp(
      libraryId: lib.id,
      diverId: 'd1',
      note: 'the private part',
    );
    final read = await LibraryBackupArchive.read(
      File(record.localPath!).readAsBytesSync(),
    );
    expect(read.header.note, isEmpty);
    expect(record.note, 'the private part');
    expect(
      (await backups().list(libraryId: lib.id)).single.note,
      'the private part',
    );
  });

  test(
    'a device that has not seen encryption turned on writes no note plain',
    () async {
      await LibraryEncryptionService(
        store: SharedLibraryStore(),
        memberships: memberships,
        kdf: _fast,
      ).turnOn(libraryId: lib.id, diverId: 'd1', passphrase: 'a passphrase');
      // This device's row from before, as on a device that missed the change.
      await SharedLibraryStore().setLibraryStatus(
        lib.id,
        encrypted: false,
        clearKeyId: true,
      );
      final record = await backups().backUp(
        libraryId: lib.id,
        diverId: 'd1',
        note: 'the private part',
      );
      final read = await LibraryBackupArchive.read(
        File(record.localPath!).readAsBytesSync(),
      );
      expect(read.header.note, isEmpty);
      expect(read.header.name, isNull);
    },
  );

  test('a backup the list in storage cannot name is not left there', () async {
    cloud.failUploadsNamed = 'index.json';
    final record = await backups().backUp(libraryId: lib.id, diverId: 'd1');
    cloud.failUploadsNamed = null;
    expect(record.inStorage, isFalse);
    expect(await transport().readBackup(record.fileName), isNull);
    expect((await backups().list(libraryId: lib.id)).single.inStorage, isFalse);
  });

  test('a backup keeps the roles this device trusts', () async {
    // Someone with write access replaced the roles; the sync refused them.
    final t = transport();
    final trusted = (await SharedLibraryStore().getLibrary(lib.id))!.roles;
    await t.writeRoles(
      trusted.copyWith(version: trusted.version + 5, owners: {'mallory'}),
    );
    final record = await backups().backUp(libraryId: lib.id, diverId: 'd1');
    final read = await LibraryBackupArchive.read(
      File(record.localPath!).readAsBytesSync(),
    );
    final roles = SharedLibraryRoles.fromJson(
      jsonDecode(utf8.decode(read.files['roles.json']!))
          as Map<String, dynamic>,
    );
    expect(roles, trusted);
  });
}

/// The flat fake, recording the folder names asked for.
class _FolderNames extends FakeCloudStorageProvider {
  final folders = <String>[];

  @override
  Future<String> createFolder(String folderName, {String? parentFolderId}) {
    folders.add(folderName);
    return super.createFolder(folderName, parentFolderId: parentFolderId);
  }
}
