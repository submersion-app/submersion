import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/shared_library/backup/library_backup_archive.dart';
import 'package:submersion/core/services/shared_library/backup/library_backup_service.dart';
import 'package:submersion/core/services/shared_library/backup/library_restore_service.dart';
import 'package:submersion/core/services/shared_library/library_document_stamper.dart';
import 'package:submersion/core/services/shared_library/shared_library_membership_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';

import '../../../../helpers/fake_cloud_storage_provider.dart';
import '../../../../helpers/shared_library_test_account.dart';
import '../../../../helpers/test_database.dart';

/// Shared documents in library backups (issue #4713): the records are in
/// the backup, their page files stay in `pages/` and the backup index names
/// them so cleanup keeps them.
void main() {
  late FakeCloudStorageProvider cloud;
  late Directory dir;
  late SharedLibraryMembershipService memberships;
  late LibraryBackupService backups;
  late SharedLibrary lib;
  final account = ConnectedAccount(
    id: 'acc',
    kind: AccountKind.s3,
    label: 'Club bucket',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  SharedLibraryService syncer({DateTime Function()? now}) =>
      SharedLibraryService(
        store: SharedLibraryStore(),
        transportFor: (l) => memberships.transportForLibrary(l),
        now: now,
      );

  LibraryRestoreService restorer() => LibraryRestoreService(
    store: SharedLibraryStore(),
    memberships: memberships,
    backups: backups,
  );

  SharedLibraryTransport transport() =>
      SharedLibraryTransport(cloud, prefix: 'site-sync');

  Future<String> sharedDoc(String title) async {
    final id = (await DocumentRepository().save(
      Document(
        id: '',
        diverId: 'd1',
        owner: const DocumentOwner(DocumentOwnerKind.site, 's1'),
        type: DocumentType.map,
        title: title,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      [
        DocumentPage(
          id: '',
          documentId: '',
          pageIndex: 0,
          fileName: '$title.pdf',
          mimeType: 'application/pdf',
          sizeBytes: 2,
          bytes: Uint8List.fromList([title.length, 7]),
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ],
    )).id;
    await LibraryDocumentStamper().share(
      id,
      libraryId: lib.id,
      actingDiverId: 'd1',
    );
    return id;
  }

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
    dir = Directory.systemTemp.createTempSync('library_backup_docs_');
    cloud = FakeCloudStorageProvider();
    memberships = SharedLibraryMembershipService(
      accountById: anyTestAccount,
      store: SharedLibraryStore(),
      transportFor: ({required account, required prefix}) async =>
          SharedLibraryTransport(cloud, prefix: prefix),
    );
    backups = LibraryBackupService(
      store: SharedLibraryStore(),
      memberships: memberships,
      backupsDirectory: () async => dir.path,
    );
    lib = await memberships.create(
      account: account,
      prefix: 'site-sync',
      name: 'Reef Club',
      diverId: 'd1',
      displayName: 'Ann',
    );
    await SiteRepository().createSite(
      DiveSite(id: 's1', name: 'Pier', sharedLibraryId: lib.id),
    );
    await SharedLibraryStore().putSiteState(
      SharedSiteState(siteId: 's1', libraryId: lib.id, dirty: true),
    );
  });

  tearDown(() async {
    SyncCoordinator.reset();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    await tearDownTestDatabase();
  });

  test('a backup holds document files and no page files', () async {
    final id = await sharedDoc('Access');
    await syncer().sync(lib.id, diverId: 'd1');
    final record = await backups.backUp(libraryId: lib.id, diverId: 'd1');
    final contents = await LibraryBackupArchive.read(
      await File(record.localPath!).readAsBytes(),
    );
    expect(contents.files.keys, contains('documents/document-$id.json'));
    expect(contents.files.keys.where((k) => k.startsWith('pages/')), isEmpty);
    expect(contents.header.documentCount, 1);
  });

  test('its index entry lists the page files it needs', () async {
    await sharedDoc('Access');
    await syncer().sync(lib.id, diverId: 'd1');
    final record = await backups.backUp(libraryId: lib.id, diverId: 'd1');
    final stored = (await transport().listPageFiles())
        .map(SharedLibraryTransport.pageFileIdOf)
        .toSet();
    expect(record.pageFileIds.toSet(), stored);
    final listed = (await backups.list(
      libraryId: lib.id,
    )).firstWhere((r) => r.backupId == record.backupId);
    expect(listed.pageFileIds.toSet(), stored);
  });

  test(
    'restore brings back a removed shared document with its pages',
    () async {
      final id = await sharedDoc('Access');
      await syncer().sync(lib.id, diverId: 'd1');
      final record = await backups.backUp(libraryId: lib.id, diverId: 'd1');
      await LibraryDocumentStamper().removeFromLibrary(id, actingDiverId: 'd1');
      await syncer().sync(lib.id, diverId: 'd1');
      expect(await DocumentRepository().getById(id), isNull);

      final missing = await restorer().restore(
        libraryId: lib.id,
        diverId: 'd1',
        backupId: record.backupId,
      );
      expect(missing, 0);
      await syncer().sync(lib.id, diverId: 'd1');
      final back = (await DocumentRepository().getById(id))!;
      expect(back.title, 'Access');
      expect((await DocumentRepository().getPages(id)).single.bytes, [6, 7]);
    },
  );

  test('restore tombstones a document made after the backup', () async {
    await syncer().sync(lib.id, diverId: 'd1');
    final record = await backups.backUp(libraryId: lib.id, diverId: 'd1');
    final later = await sharedDoc('Later');
    await syncer().sync(lib.id, diverId: 'd1');
    await restorer().restore(
      libraryId: lib.id,
      diverId: 'd1',
      backupId: record.backupId,
    );
    await syncer().sync(lib.id, diverId: 'd1');
    expect(await DocumentRepository().getById(later), isNull);
  });

  test(
    "restore of an older app's backup leaves shared documents alone",
    () async {
      await syncer().sync(lib.id, diverId: 'd1');
      final record = await backups.backUp(libraryId: lib.id, diverId: 'd1');
      final contents = await LibraryBackupArchive.read(
        await File(record.localPath!).readAsBytes(),
      );
      final h = contents.header;
      final me = (await SharedLibraryStore().membership(
        diverId: 'd1',
        libraryId: lib.id,
      ))!;
      final older = await LibraryBackupArchive.build(
        files: contents.files,
        header: LibraryBackupHeader(
          backupId: h.backupId,
          libraryId: h.libraryId,
          name: h.name,
          createdAt: h.createdAt,
          createdBy: h.createdBy,
          createdByKey: h.createdByKey,
          appVersion: '1.8.6',
          automatic: h.automatic,
          siteCount: h.siteCount,
          memberCount: h.memberCount,
        ),
        key: me.signingKey ?? await SharedLibraryStore().ensureSigningKey('d1'),
      );
      await File(record.localPath!).writeAsBytes(older);

      final later = await sharedDoc('Later');
      await syncer().sync(lib.id, diverId: 'd1');
      await restorer().restore(
        libraryId: lib.id,
        diverId: 'd1',
        backupId: record.backupId,
      );
      await syncer().sync(lib.id, diverId: 'd1');
      expect(await DocumentRepository().getById(later), isNotNull);
    },
  );

  test('a backup whose page files were collected restores the rest and '
      'reports the count', () async {
    final id = await sharedDoc('Access');
    await syncer().sync(lib.id, diverId: 'd1');
    final record = await backups.backUp(libraryId: lib.id, diverId: 'd1');
    await LibraryDocumentStamper().removeFromLibrary(id, actingDiverId: 'd1');
    await syncer().sync(lib.id, diverId: 'd1');
    final t = transport();
    for (final f in await t.listPageFiles()) {
      await t.deletePageFile(f.id);
    }
    final missing = await restorer().restore(
      libraryId: lib.id,
      diverId: 'd1',
      backupId: record.backupId,
    );
    expect(missing, 1);
    await syncer().sync(lib.id, diverId: 'd1');
    expect(await DocumentRepository().getById(id), isNull);
  });

  test('GC keeps a page file only a kept backup refers to', () async {
    final id = await sharedDoc('Access');
    await syncer().sync(lib.id, diverId: 'd1');
    await backups.backUp(libraryId: lib.id, diverId: 'd1');
    await LibraryDocumentStamper().removeFromLibrary(id, actingDiverId: 'd1');
    await syncer().sync(lib.id, diverId: 'd1');
    await syncer(
      now: () => DateTime.now().add(const Duration(days: 31)),
    ).sync(lib.id, diverId: 'd1');
    expect(await transport().listPageFiles(), hasLength(1));
  });

  test('GC keeps a page file a backup needs after an older owner app '
      'rewrote the index without page lists', () async {
    final id = await sharedDoc('Access');
    await syncer().sync(lib.id, diverId: 'd1');
    await backups.backUp(libraryId: lib.id, diverId: 'd1');
    // An older owner app pins a backup: it writes back only the keys it
    // knows.
    final t = transport();
    final index = (await t.readBackupIndex())!;
    await t.writeBackupIndex({
      ...index,
      'entries': [
        for (final e in index['entries'] as List)
          {...(e as Map<String, dynamic>)}..remove('pageFileIds'),
      ],
    });
    await LibraryDocumentStamper().removeFromLibrary(id, actingDiverId: 'd1');
    await syncer().sync(lib.id, diverId: 'd1');
    await syncer(
      now: () => DateTime.now().add(const Duration(days: 31)),
    ).sync(lib.id, diverId: 'd1');
    expect(await transport().listPageFiles(), hasLength(1));
  });
}
