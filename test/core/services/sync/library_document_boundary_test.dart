import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/shared_library/library_document_bridge.dart';
import 'package:submersion/core/services/shared_library/library_document_record.dart';
import 'package:submersion/core/services/shared_library/library_document_stamper.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/crypto/canonical_json.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';

/// A document shared with a shared site library (issue #4713) stays out of
/// the personal sync in both directions, as a library site does.
void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('library_doc_guard_'));
  tearDown(() async {
    final open = DatabaseService.instance.databaseOrNull;
    if (open != null) {
      await open.close();
      DatabaseService.instance.resetForTesting();
    }
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  Future<void> open(String name) async {
    final current = DatabaseService.instance.databaseOrNull;
    if (current != null) {
      await current.close();
      DatabaseService.instance.resetForTesting();
    }
    final file = File(p.join(dir.path, '$name.sqlite'));
    final fresh = !file.existsSync();
    DatabaseService.instance.setTestDatabase(AppDatabase(NativeDatabase(file)));
    if (!fresh) return;
    await DiverRepository().createDiver(
      Diver(
        id: 'd1',
        name: 'Ann',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    await SiteRepository().createSite(
      const DiveSite(id: 'lib', name: 'Club site', sharedLibraryId: 'L'),
    );
    await SiteRepository().createSite(const DiveSite(id: 'mine', name: 'Mine'));
    final store = SharedLibraryStore();
    await store.upsertMembership(
      const SharedLibraryMembership(
        id: 'ms',
        diverId: 'd1',
        libraryId: 'L',
        memberId: 'm1',
        displayName: 'Ann',
        libraryName: 'Reef Club',
        backendKind: 's3',
      ),
    );
    await store.upsertLibrary(
      const SharedLibrary(
        id: 'L',
        name: 'Reef Club',
        connectedAccountId: 'acc',
        prefix: 'site-sync',
        roles: SharedLibraryRoles(owners: {'o'}, editors: {'m1'}),
      ),
    );
  }

  Future<void> sync(FakeCloudStorageProvider cloud) async {
    final r = await SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: cloud,
    ).performSync();
    expect(r.status, SyncResultStatus.success);
  }

  DocumentPage page(List<int> bytes) => DocumentPage(
    id: '',
    documentId: '',
    pageIndex: 0,
    fileName: 'a.pdf',
    mimeType: 'application/pdf',
    sizeBytes: bytes.length,
    bytes: Uint8List.fromList(bytes),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Future<String> personalDoc(String site, {String id = ''}) async =>
      (await DocumentRepository().save(
        Document(
          id: id,
          diverId: 'd1',
          owner: DocumentOwner(DocumentOwnerKind.site, site),
          type: DocumentType.map,
          title: 'Personal',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
        [
          page([1, 2]),
        ],
      )).id;

  /// Library document [id] as a library sync writes it here.
  Future<void> libraryDoc(String id) => LibraryDocumentBridge().apply(
    LibraryDocumentRecord(
      id: id,
      siteId: 'lib',
      fields: {
        'type': 'map',
        'title': 'Club map',
        'pages': [
          {
            'id': 'lp1',
            'pageIndex': 0,
            'side': null,
            'fileName': 'm.pdf',
            'mimeType': 'application/pdf',
            'sizeBytes': 1,
            'fileId': 'f1',
            'sha256': sha256Hex([5]),
          },
        ],
      },
    ),
    libraryId: 'L',
    vocabularyDiverId: 'd1',
    pageBytesByFileId: {
      'f1': Uint8List.fromList([5]),
    },
  );

  Future<int> tombstones(String entity, String id) async =>
      (await DatabaseService.instance.database
              .customSelect(
                'SELECT 1 FROM deletion_log WHERE entity_type = ? '
                'AND record_id = ?',
                variables: [
                  Variable.withString(entity),
                  Variable.withString(id),
                ],
              )
              .get())
          .length;

  test('a library document is never exported', () async {
    final cloud = FakeCloudStorageProvider();
    await open('a');
    await libraryDoc('club');
    final mine = await personalDoc('mine');
    await sync(cloud);

    await open('b');
    await sync(cloud);
    expect(await DocumentRepository().getById(mine), isNotNull);
    expect(await DocumentRepository().getById('club'), isNull);
    final pages = await DatabaseService.instance.database
        .customSelect("SELECT 1 FROM document_pages WHERE id = 'lp1'")
        .get();
    expect(pages, isEmpty);
  });

  test(
    "a peer's personal row with a library document's id is ignored",
    () async {
      final cloud = FakeCloudStorageProvider();
      await open('a');
      await personalDoc('mine', id: 'x');
      await sync(cloud);

      await open('b');
      await libraryDoc('x');
      await sync(cloud);
      final doc = (await DocumentRepository().getById('x'))!;
      expect(doc.sharedLibraryId, 'L');
      expect(doc.diverId, isNull);
      expect(doc.title, 'Club map');
      expect((await DocumentRepository().getPages('x')).single.bytes, [5]);
    },
  );

  test("a peer's tombstone for a library document is ignored", () async {
    final cloud = FakeCloudStorageProvider();
    await open('a');
    await personalDoc('mine', id: 'x');
    await sync(cloud);
    await DocumentRepository().delete('x');
    await sync(cloud);

    await open('b');
    await libraryDoc('x');
    await sync(cloud);
    expect(await DocumentRepository().getById('x'), isNotNull);
    expect(await DocumentRepository().getPages('x'), hasLength(1));
  });

  test(
    'deleting or re-paging a library document logs no personal tombstone',
    () async {
      await open('a');
      await libraryDoc('club');
      final repo = DocumentRepository();
      await repo.save((await repo.getById('club'))!, [
        page([9]),
      ]);
      expect(await tombstones('documentPages', 'lp1'), 0);
      await repo.delete('club');
      expect(await tombstones('documents', 'club'), 0);
    },
  );

  test("sharing a document drops it from the diver's other device", () async {
    final cloud = FakeCloudStorageProvider();
    await open('a');
    final id = await personalDoc('lib');
    await sync(cloud);

    await open('b');
    await sync(cloud);
    expect(await DocumentRepository().getById(id), isNotNull);

    await open('a');
    await LibraryDocumentStamper().share(
      id,
      libraryId: 'L',
      actingDiverId: 'd1',
    );
    await sync(cloud);

    await open('b');
    await sync(cloud);
    expect(await DocumentRepository().getById(id), isNull);
  });
}
