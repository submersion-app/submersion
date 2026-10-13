import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/shared_library/backup/library_backup_archive.dart';
import 'package:submersion/core/services/shared_library/backup/library_backup_record.dart';
import 'package:submersion/core/services/shared_library/crypto/library_signer.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/shared_library/shared_library_membership_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/shared_library_test_keys.dart';
import '../../../helpers/test_database.dart';

/// A library id read from storage names local folders (its backups), so
/// one that could leave them is refused (issue #2567).
void main() {
  setUp(() async {
    await setUpTestDatabase();
    await DiverRepository().createDiver(
      Diver(
        id: 'd',
        name: 'Ann',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
  });

  tearDown(tearDownTestDatabase);

  test('a manifest whose id could leave a folder is no library', () async {
    final cloud = FakeCloudStorageProvider();
    final t = SharedLibraryTransport(cloud, prefix: 'site-sync');
    await t.writeManifest({
      'id': '../../escape',
      'formatVersion': SharedLibraryLayout.formatVersion,
    });
    await t.writeRoles(await signedTestRoles(owners: {'o'}));
    final memberships = SharedLibraryMembershipService(
      store: SharedLibraryStore(),
      transportFor: ({required account, required prefix}) async =>
          SharedLibraryTransport(cloud, prefix: prefix),
    );
    await expectLater(
      memberships.join(
        account: ConnectedAccount(
          id: 'acc',
          kind: AccountKind.s3,
          label: 'Survey bucket',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
        prefix: 'site-sync',
        diverId: 'd',
        displayName: 'Ann',
      ),
      throwsStateError,
    );
    expect(await SharedLibraryStore().getLibraries(), isEmpty);
  });

  test('library ids are checked as safe folder names', () {
    expect(
      SharedLibraryLayout.isValidLibraryId(
        '6f1c2a9e-0b7d-4c1a-9f0e-2d3c4b5a6e7f',
      ),
      isTrue,
    );
    for (final bad in ['', '..', '../x', 'a/b', r'a\b', 'x' * 200]) {
      expect(SharedLibraryLayout.isValidLibraryId(bad), isFalse, reason: bad);
    }
  });

  test('a backup whose id could leave a folder is refused', () async {
    final key = await LibrarySigner.generate();
    final zip = await LibraryBackupArchive.build(
      files: {'roles.json': Uint8List.fromList('{}'.codeUnits)},
      header: LibraryBackupHeader(
        backupId: '../../escape',
        libraryId: 'L',
        createdAt: DateTime.utc(2026),
        createdBy: 'o',
        createdByKey: key.publicKey,
        appVersion: 'x',
        automatic: false,
        note: '',
        siteCount: 0,
        memberCount: 0,
      ),
      key: key,
    );
    await expectLater(
      LibraryBackupArchive.read(zip),
      throwsA(isA<BackupRefusedError>()),
    );
  });

  test('a backup index entry naming a path is dropped', () {
    Map<String, Object?> entry(String id, String name) => {
      'backupId': id,
      'fileName': name,
      'createdAt': '2026-10-01T00:00:00Z',
    };
    expect(
      LibraryBackupRecord.fromIndexJson('L', entry('b1', 'b1.zip')),
      isNotNull,
    );
    for (final (id, name) in [
      ('b1', '../b1.zip'),
      ('b1', 'a/b1.zip'),
      ('b1', r'a\b1.zip'),
      ('../b1', 'b1.zip'),
    ]) {
      expect(
        LibraryBackupRecord.fromIndexJson('L', entry(id, name)),
        isNull,
        reason: '$id $name',
      );
    }
  });

  test(
    'a backup holding files outside the library layout is refused',
    () async {
      final key = await LibrarySigner.generate();
      Future<Uint8List> zipOf(String name) => LibraryBackupArchive.build(
        files: {
          'roles.json': Uint8List.fromList('{}'.codeUnits),
          name: Uint8List.fromList('x'.codeUnits),
        },
        header: LibraryBackupHeader(
          backupId: 'b1',
          libraryId: 'L',
          createdAt: DateTime.utc(2026),
          createdBy: 'o',
          createdByKey: key.publicKey,
          appVersion: 'x',
          automatic: false,
          note: '',
          siteCount: 0,
          memberCount: 0,
        ),
        key: key,
      );
      for (final good in [
        'sites/site-s1.json',
        'sites/site-Blue Hole 2.json',
      ]) {
        expect(
          (await LibraryBackupArchive.read(await zipOf(good))).files.keys,
          contains(good),
          reason: good,
        );
      }
      for (final bad in [
        '..',
        'evil.sh',
        'sites/../roles.json',
        'sites/..',
        'members/notes.txt',
        'backups/index.json',
        'sites/nested/site-x.json',
        r'sites/site-a\b.json',
        'sites/site-.json',
      ]) {
        await expectLater(
          LibraryBackupArchive.read(await zipOf(bad)),
          throwsA(isA<BackupRefusedError>()),
          reason: bad,
        );
      }
    },
  );
}
