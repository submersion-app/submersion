import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/shared_library/backup/library_backup_archive.dart';
import 'package:submersion/core/services/shared_library/backup/library_backup_service.dart';
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

void main() {
  late FakeCloudStorageProvider cloud;
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
    dir = Directory.systemTemp.createTempSync('library_backups_');
    cloud = FakeCloudStorageProvider();
    memberships = SharedLibraryMembershipService(
      store: SharedLibraryStore(),
      transportFor: ({required account, required prefix}) async =>
          SharedLibraryTransport(cloud, prefix: prefix),
      recoveryKdf: const KdfParams(m: 1024, t: 1),
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
    await SharedLibraryService(
      store: SharedLibraryStore(),
      transportFor: (l) => memberships.transportForLibrary(l),
    ).sync(lib.id, diverId: 'd1');
  });

  tearDown(() async {
    SyncCoordinator.reset();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    await tearDownTestDatabase();
  });

  test('a backup goes to the device and to storage', () async {
    final record = await backups.backUp(
      libraryId: lib.id,
      diverId: 'd1',
      note: 'before the trip',
    );
    expect(record.onDevice, isTrue);
    expect(record.inStorage, isTrue);
    expect(record.siteCount, 1);
    expect(record.memberCount, 1);
    final file = File(record.localPath!);
    expect(file.existsSync(), isTrue);
    expect(
      p.isWithin(p.join(dir.path, 'shared-libraries', lib.id), file.path),
      isTrue,
    );
    final read = await LibraryBackupArchive.read(file.readAsBytesSync());
    expect(read.header.note, 'before the trip');
    expect(read.files.keys, contains('sites/site-s1.json'));
    final listed = await backups.list(libraryId: lib.id);
    expect(listed.single.backupId, record.backupId);
    expect(listed.single.note, 'before the trip');
  });

  test(
    'pins and notes reach both copies; deleting one keeps the other',
    () async {
      final record = await backups.backUp(libraryId: lib.id, diverId: 'd1');
      await backups.setPinned(
        record.backupId,
        libraryId: lib.id,
        diverId: 'd1',
        pinned: true,
      );
      expect((await backups.list(libraryId: lib.id)).single.pinned, isTrue);
      await backups.delete(
        record.backupId,
        libraryId: lib.id,
        diverId: 'd1',
        fromDevice: true,
        fromStorage: false,
      );
      final left = (await backups.list(libraryId: lib.id)).single;
      expect(left.onDevice, isFalse);
      expect(left.inStorage, isTrue);
      expect(left.pinned, isTrue);
      expect(File(record.localPath!).existsSync(), isFalse);
    },
  );

  test('an imported backup of this library is listed on the device', () async {
    final record = await backups.backUp(libraryId: lib.id, diverId: 'd1');
    final copy = File(p.join(dir.path, 'elsewhere.zip'))
      ..writeAsBytesSync(File(record.localPath!).readAsBytesSync());
    await backups.delete(
      record.backupId,
      libraryId: lib.id,
      diverId: 'd1',
      fromDevice: true,
      fromStorage: true,
    );
    expect(await backups.list(libraryId: lib.id), isEmpty);
    final imported = await backups.import(libraryId: lib.id, path: copy.path);
    expect(imported.backupId, record.backupId);
    expect(imported.onDevice, isTrue);
    expect(imported.inStorage, isFalse);
  });

  test('a backup of another library is refused on import', () async {
    final record = await backups.backUp(libraryId: lib.id, diverId: 'd1');
    await expectLater(
      backups.import(libraryId: 'other', path: record.localPath!),
      throwsA(isA<BackupRefusedError>()),
    );
  });

  test('only an owner backs up', () async {
    await diver('d2');
    await memberships.join(
      account: account,
      prefix: 'site-sync',
      diverId: 'd2',
      displayName: 'Bo',
    );
    await expectLater(
      backups.backUp(libraryId: lib.id, diverId: 'd2'),
      throwsStateError,
    );
  });

  group('automatic', () {
    var clock = DateTime.utc(2026, 10, 1, 9);

    setUp(() {
      clock = DateTime.utc(2026, 10, 1, 9);
      backups = LibraryBackupService(
        store: SharedLibraryStore(),
        memberships: memberships,
        backupsDirectory: () async => dir.path,
        now: () => clock,
      );
    });

    test('is due once a day', () async {
      expect(
        await backups.backUpIfDue(libraryId: lib.id, diverId: 'd1'),
        isTrue,
      );
      clock = clock.add(const Duration(hours: 23));
      expect(
        await backups.backUpIfDue(libraryId: lib.id, diverId: 'd1'),
        isFalse,
      );
      clock = clock.add(const Duration(hours: 2));
      expect(
        await backups.backUpIfDue(libraryId: lib.id, diverId: 'd1'),
        isTrue,
      );
      final all = await backups.list(libraryId: lib.id);
      expect(all, hasLength(2));
      expect(all.every((r) => r.automatic), isTrue);
    });

    test(
      "is skipped while another owner's backup is under 20 hours old",
      () async {
        await backups.backUp(libraryId: lib.id, diverId: 'd1');
        // This device has never backed up automatically, but storage holds
        // a fresh backup (another owner's, as far as this device knows).
        await SharedLibraryStore().setLibraryStatus(lib.id);
        clock = clock.add(const Duration(hours: 19));
        expect(
          await backups.backUpIfDue(libraryId: lib.id, diverId: 'd1'),
          isFalse,
        );
        clock = clock.add(const Duration(hours: 2));
        expect(
          await backups.backUpIfDue(libraryId: lib.id, diverId: 'd1'),
          isTrue,
        );
      },
    );

    test(
      'keeps the newest 7 unpinned in each place and every pinned one',
      () async {
        final first = await backups.backUp(libraryId: lib.id, diverId: 'd1');
        await backups.setPinned(
          first.backupId,
          libraryId: lib.id,
          diverId: 'd1',
          pinned: true,
        );
        for (var i = 0; i < 9; i++) {
          clock = clock.add(const Duration(days: 1));
          await backups.backUpIfDue(libraryId: lib.id, diverId: 'd1');
        }
        final all = await backups.list(libraryId: lib.id);
        final unpinned = all.where((r) => !r.pinned).toList();
        expect(unpinned.where((r) => r.onDevice), hasLength(7));
        expect(unpinned.where((r) => r.inStorage), hasLength(7));
        expect(all.where((r) => r.pinned).single.backupId, first.backupId);
      },
    );
  });
}
