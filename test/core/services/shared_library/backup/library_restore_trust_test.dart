import 'dart:convert';
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
import 'package:submersion/core/services/shared_library/site_document.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../../helpers/fake_cloud_storage_provider.dart';
import '../../../../helpers/test_database.dart';
import '../../../../helpers/shared_library_test_account.dart';

const _fast = KdfParams(m: 1024, t: 1);

/// A restore trusts only what this device already trusts: the backup's
/// maker, the backup picked, and every field's signature (issue #2567).
void main() {
  late FakeCloudStorageProvider cloud;
  late Map<String, FakeCloudStorageProvider> elsewhere;
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

  FakeCloudStorageProvider cloudAt(String prefix) => prefix == 'site-sync'
      ? cloud
      : elsewhere.putIfAbsent(prefix, FakeCloudStorageProvider.new);

  SharedLibraryService syncer() => SharedLibraryService(
    store: SharedLibraryStore(),
    transportFor: (l) => memberships.transportForLibrary(l),
  );

  LibraryRestoreService restorer() => LibraryRestoreService(
    store: SharedLibraryStore(),
    memberships: memberships,
    backups: backups,
  );

  SharedLibraryTransport folder() =>
      SharedLibraryTransport(cloud, prefix: 'site-sync');

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
    dir = Directory.systemTemp.createTempSync('library_restore_trust_');
    cloud = FakeCloudStorageProvider();
    elsewhere = {};
    memberships = SharedLibraryMembershipService(
      accountById: anyTestAccount,
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
    await SiteRepository().createSite(
      DiveSite(id: 's1', name: 'Blue', sharedLibraryId: lib.id),
    );
    await SharedLibraryStore().putSiteState(
      SharedSiteState(siteId: 's1', libraryId: lib.id, dirty: true),
    );
    await syncer().sync(lib.id, diverId: 'd1');
  });

  tearDown(() async {
    SyncCoordinator.reset();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    await tearDownTestDatabase();
  });

  /// A zip built by someone with write access to `backups/`: genuine in
  /// itself, its roles naming its maker an owner.
  Future<Uint8List> forged({
    required String backupId,
    Map<String, Uint8List> extra = const {},
  }) async {
    final mallory = await LibrarySigner.generate();
    final files = {...await folder().snapshot(), ...extra};
    final roles = await SharedLibraryRoles(
      version: 99,
      owners: const {'mallory'},
      approvedKeys: {'mallory': mallory.publicKey},
    ).signed(libraryId: lib.id, signedBy: 'mallory', key: mallory);
    files['roles.json'] = Uint8List.fromList(
      utf8.encode(jsonEncode(roles.toJson())),
    );
    return LibraryBackupArchive.build(
      files: files,
      header: LibraryBackupHeader(
        backupId: backupId,
        libraryId: lib.id,
        createdAt: DateTime.utc(2026),
        createdBy: 'mallory',
        createdByKey: mallory.publicKey,
        appVersion: 'x',
        automatic: false,
        siteCount: 1,
        memberCount: 1,
      ),
      key: mallory,
    );
  }

  test('a zip put in place of a listed backup is refused', () async {
    final record = await backups.backUp(libraryId: lib.id, diverId: 'd1');
    // Only in storage: the device fetches it when restoring.
    File(record.localPath!).deleteSync();
    await folder().writeBackup(
      record.fileName,
      await forged(backupId: record.backupId),
    );
    await expectLater(
      restorer().restore(
        libraryId: lib.id,
        diverId: 'd1',
        backupId: record.backupId,
      ),
      throwsA(
        isA<BackupRefusedError>().having((e) => e.reason, 'reason', 'creator'),
      ),
    );
    expect((await folder().readRoles()).owners, isNot(contains('mallory')));
  });

  test('a genuine backup in place of the one picked is refused', () async {
    final picked = await backups.backUp(libraryId: lib.id, diverId: 'd1');
    final other = await backups.backUp(libraryId: lib.id, diverId: 'd1');
    File(picked.localPath!).deleteSync();
    await folder().writeBackup(
      picked.fileName,
      File(other.localPath!).readAsBytesSync(),
    );
    await expectLater(
      restorer().restore(
        libraryId: lib.id,
        diverId: 'd1',
        backupId: picked.backupId,
      ),
      throwsA(isA<BackupRefusedError>()),
    );
  });

  test('a field nobody signed is never signed by a restore', () async {
    // Planted in storage by someone with write access, no signature.
    final t = folder();
    final file = (await t.listSites()).single;
    final doc = await t.readSite(file.id);
    await t.writeRaw(
      'sites/${file.name.split('/').last}',
      SiteDocument.encode(
        doc.copyWith(
          fields: {...doc.fields, 'description': 'planted'},
          clocks: {
            ...doc.clocks,
            'description': const FieldClock(
              hlc: Hlc(9000000000000000, 0, 'x'),
              memberId: 'x',
            ),
          },
        ),
      ),
    );
    final record = await backups.backUp(libraryId: lib.id, diverId: 'd1');
    await restorer().restore(
      libraryId: lib.id,
      diverId: 'd1',
      backupId: record.backupId,
    );
    final restored = await t.readSite((await t.listSites()).single.id);
    expect(restored.fields['description'], isNot('planted'));
    expect(restored.fields['name'], 'Blue');
    for (final c in restored.clocks.values) {
      expect(c.hlc.physicalTime, lessThan(9000000000000000));
      expect(c.editedAt.year, lessThan(10000));
    }
  });

  test('a backed-up document naming another id is left out', () async {
    final t = folder();
    final doc = await t.readSite((await t.listSites()).single.id);
    await t.writeRaw(
      'sites/site-x1.json',
      SiteDocument.encode(
        SiteDocument(
          id: '../../escape',
          fields: doc.fields,
          clocks: doc.clocks,
        ),
      ),
    );
    await t.writeRaw('sites/site-x2.json', Uint8List.fromList([1, 2, 3]));
    final record = await backups.backUp(libraryId: lib.id, diverId: 'd1');
    await restorer().restore(
      libraryId: lib.id,
      diverId: 'd1',
      backupId: record.backupId,
    );
    final names = [for (final f in await cloud.listFiles()) f.name];
    expect(names.where((n) => n.contains('..')), isEmpty);
    expect(
      (await backups.list(libraryId: lib.id)).where((r) => r.beforeRestore),
      hasLength(1),
    );
  });

  test('a backup with no manifest leaves the empty folder empty', () async {
    final record = await backups.backUp(libraryId: lib.id, diverId: 'd1');
    final read = await LibraryBackupArchive.read(
      File(record.localPath!).readAsBytesSync(),
    );
    final key = (await SharedLibraryStore().signingKeyForDiver('d1'))!;
    final zip = await LibraryBackupArchive.build(
      files: {...read.files}..remove(SharedLibraryLayout.manifestFile),
      header: read.header,
      key: key,
    );
    final path = File(p.join(dir.path, 'no-manifest.zip'))
      ..writeAsBytesSync(zip);
    await expectLater(
      restorer().restoreInto(
        account: account,
        prefix: 'moved',
        diverId: 'd1',
        displayName: 'Ann',
        path: path.path,
      ),
      throwsA(isA<BackupRefusedError>()),
    );
    expect(await cloudAt('moved').listFiles(), isEmpty);
  });

  test('a file still under an earlier key opens in an empty folder', () async {
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
    final cardName = (await cloud.listFiles(
      namePattern: 'member-',
    )).single.name;
    final underFirstKey = await cloud.downloadFile(cardName);
    await encryption.changePassphrase(
      libraryId: lib.id,
      diverId: 'd1',
      passphrase: 'second passphrase',
    );
    // A member's card written under the first key after the change.
    await folder().writeRaw(
      'members/${cardName.split('/').last}',
      underFirstKey,
    );
    final record = await backups.backUp(libraryId: lib.id, diverId: 'd1');
    final moved = await restorer().restoreInto(
      account: account,
      prefix: 'moved',
      diverId: 'd1',
      displayName: 'Ann',
      path: record.localPath!,
      secret: 'second passphrase',
    );
    expect(moved.library.id, lib.id);
  });
}
