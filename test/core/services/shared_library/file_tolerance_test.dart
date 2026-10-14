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
import 'package:submersion/core/services/shared_library/library_encryption_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_membership_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/core/services/shared_library/site_document.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

const _fast = KdfParams(m: 1024, t: 1);

/// Files any member's storage key may write, and that no build of the app
/// writes, never stop a sync, a change of key, a backup or a restore
/// (issue #2567).
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

  LibraryEncryptionService encryption() => LibraryEncryptionService(
    store: SharedLibraryStore(),
    memberships: memberships,
    kdf: _fast,
  );

  SharedLibraryTransport folder() =>
      SharedLibraryTransport(cloud, prefix: 'site-sync');

  Uint8List bytes(String s) => Uint8List.fromList(utf8.encode(s));

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
    dir = Directory.systemTemp.createTempSync('file_tolerance_');
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

  test('an id no file can be named after is no site', () {
    for (final bad in ['', 'a..b', 'x.', '..', 'a/b', r'a\b']) {
      expect(SharedLibraryTransport.isSafeFileId(bad), isFalse, reason: bad);
    }
    expect(SharedLibraryTransport.isSafeFileId('s1'), isTrue);
    expect(SharedLibraryTransport.isSafeFileId('Blue Hole 2'), isTrue);
  });

  test('a site file named for no safe id is left alone', () async {
    final t = folder();
    final doc = await t.readSite((await t.listSites()).single.id);
    await t.writeRaw(
      'sites/site-a..b.json',
      SiteDocument.encode(
        SiteDocument(id: 'a..b', fields: doc.fields, clocks: doc.clocks),
      ),
    );
    await t.writeRaw('sites/site-.json', bytes('{}'));
    expect(
      (await syncer().sync(lib.id, diverId: 'd1')).status,
      SharedLibrarySyncStatus.success,
    );
    expect(await SiteRepository().getSiteById('a..b'), isNull);
    final record = await backups.backUp(libraryId: lib.id, diverId: 'd1');
    await restorer().restore(
      libraryId: lib.id,
      diverId: 'd1',
      backupId: record.backupId,
    );
    expect(
      (await SharedLibraryStore().getLibrary(lib.id))!.roles.owners,
      isNotEmpty,
    );
  });

  test('a value no JSON can hold never stops the sync', () async {
    final t = folder();
    final file = (await t.listSites()).single;
    final raw = utf8.decode(await cloud.downloadFile(file.id));
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final clocks = Map<String, dynamic>.from(json['clocks'] as Map);
    final name = Map<String, dynamic>.from(clocks['name'] as Map);
    // Newer than the local clock, so it is checked.
    name['hlc'] = '999999999999:000000:${name['memberId']}';
    clocks['name'] = name;
    json['clocks'] = clocks;
    final text = jsonEncode(json).replaceFirst('"name":"Blue"', '"name":1e999');
    await cloud.uploadFile(bytes(text), file.name.split('/').last);
    expect(
      (await syncer().sync(lib.id, diverId: 'd1')).status,
      SharedLibrarySyncStatus.success,
    );
    expect((await SiteRepository().getSiteById('s1'))!.name, 'Blue');
  });

  test('a junk sealed card never stops a change of key', () async {
    await encryption().turnOn(
      libraryId: lib.id,
      diverId: 'd1',
      passphrase: 'first passphrase',
    );
    await folder().writeRaw('members/member-zz.json', bytes('SBE1x'));
    await encryption().changePassphrase(
      libraryId: lib.id,
      diverId: 'd1',
      passphrase: 'second passphrase',
    );
    expect(
      (await folder().readManifest())![SharedLibraryLayout.rewritingFlag],
      isNull,
    );
    expect(
      (await syncer().sync(lib.id, diverId: 'd1')).status,
      SharedLibrarySyncStatus.success,
    );
    final record = await backups.backUp(libraryId: lib.id, diverId: 'd1');
    await restorer().restore(
      libraryId: lib.id,
      diverId: 'd1',
      backupId: record.backupId,
    );
  });

  test('a backup index entry of the wrong type is dropped alone', () async {
    final first = await backups.backUp(libraryId: lib.id, diverId: 'd1');
    final t = folder();
    final index = (await t.readBackupIndex())!;
    await t.writeBackupIndex({
      ...index,
      'entries': [
        ...(index['entries'] as List),
        {
          'backupId': 'bad1',
          'fileName': 'bad.zip',
          'createdAt': '2026-01-01T00:00:00Z',
          'note': 5,
        },
      ],
    });
    final second = await backups.backUp(libraryId: lib.id, diverId: 'd1');
    // The index in storage, rewritten by an owner, lists both backups.
    final stored = [
      for (final e in (await t.readBackupIndex())!['entries'] as List)
        (e as Map)['backupId'],
    ];
    expect(stored, containsAll([first.backupId, second.backupId]));
    expect(stored, isNot(contains('bad1')));
  });

  test(
    'a backup naming one library inside and another outside is refused',
    () async {
      final record = await backups.backUp(libraryId: lib.id, diverId: 'd1');
      final read = await LibraryBackupArchive.read(
        File(record.localPath!).readAsBytesSync(),
      );
      final manifest =
          jsonDecode(utf8.decode(read.files[SharedLibraryLayout.manifestFile]!))
              as Map<String, dynamic>;
      final key = (await SharedLibraryStore().signingKeyForDiver('d1'))!;
      final zip = await LibraryBackupArchive.build(
        files: {
          ...read.files,
          SharedLibraryLayout.manifestFile: bytes(
            jsonEncode({...manifest, 'id': 'another-library'}),
          ),
        },
        header: read.header,
        key: key,
      );
      final path = File(p.join(dir.path, 'mixed.zip'))..writeAsBytesSync(zip);
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
    },
  );

  test('a broken name file never stops anyone joining', () async {
    await folder().writeRaw('info.json', bytes('{"name": 5}'));
    final found = await memberships.probe(
      account: account,
      prefix: 'site-sync',
    );
    expect(found.exists, isTrue);
    await DiverRepository().createDiver(
      Diver(
        id: 'd2',
        name: 'Bo',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    await memberships.join(
      account: account,
      prefix: 'site-sync',
      diverId: 'd2',
      displayName: 'Bo',
    );
    expect(
      (await syncer().sync(lib.id, diverId: 'd1')).status,
      SharedLibrarySyncStatus.success,
    );
  });
}
