import 'dart:typed_data';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/shared_library/crypto/canonical_json.dart';
import 'package:submersion/core/services/shared_library/library_document_bridge.dart';
import 'package:submersion/core/services/shared_library/library_document_record.dart';
import 'package:submersion/core/services/shared_library/library_document_stamper.dart';
import 'package:submersion/core/services/shared_library/shared_document_state.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/site_detacher.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';

import '../../../helpers/test_database.dart';

/// Documents on a library site that leaves this device (issue #4713): a
/// diver's private ones are never lost, shared ones follow their site.
void main() {
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
    await SiteRepository().createSite(
      const DiveSite(id: 'lib', name: 'Club site', sharedLibraryId: 'L'),
    );
    await SharedLibraryStore().putSiteState(
      const SharedSiteState(siteId: 'lib', libraryId: 'L'),
    );
  });
  tearDown(tearDownTestDatabase);

  Future<String> privateDoc() async => (await DocumentRepository().save(
    Document(
      id: '',
      diverId: 'd1',
      owner: const DocumentOwner(DocumentOwnerKind.site, 'lib'),
      type: DocumentType.receipt,
      title: 'My receipt',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
    [
      DocumentPage(
        id: '',
        documentId: '',
        pageIndex: 0,
        fileName: 'r.pdf',
        mimeType: 'application/pdf',
        sizeBytes: 1,
        bytes: Uint8List.fromList([4]),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    ],
  )).id;

  Future<void> sharedDoc() async {
    await LibraryDocumentBridge().apply(
      LibraryDocumentRecord(
        id: 'club',
        siteId: 'lib',
        fields: {
          'type': 'map',
          'title': 'Club map',
          'pages': [
            {
              'id': 'p1',
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
    await SharedLibraryStore().putDocumentState(
      const SharedDocumentState(
        documentId: 'club',
        libraryId: 'L',
        siteId: 'lib',
      ),
    );
  }

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

  test(
    'a library site with only a private document is kept holding it',
    () async {
      final id = await privateDoc();
      final newId = await SiteDetacher().detachOrRemove(
        siteId: 'lib',
        ownerDiverId: 'd1',
      );
      expect(newId, detachedSiteId('lib'));
      final doc = (await DocumentRepository().getById(id))!;
      expect(doc.owner, DocumentOwner(DocumentOwnerKind.site, newId!));
      expect((await DocumentRepository().getPages(id)).single.bytes, [4]);
      expect(await tombstones('documents', id), 0);
    },
  );

  test(
    "a kept site's shared documents become private copies with pages",
    () async {
      await privateDoc();
      await sharedDoc();
      final newId = await SiteDetacher().detachOrRemove(
        siteId: 'lib',
        ownerDiverId: 'd1',
      );
      expect(await DocumentRepository().getById('club'), isNull);
      final copy = (await DocumentRepository().getById(
        detachedDocumentId('club'),
      ))!;
      expect(copy.diverId, 'd1');
      expect(copy.sharedLibraryId, isNull);
      expect(copy.title, 'Club map');
      expect(copy.owner, DocumentOwner(DocumentOwnerKind.site, newId!));
      expect((await DocumentRepository().getPages(copy.id)).single.bytes, [5]);
      expect(await tombstones('documents', 'club'), 0);
    },
  );

  test(
    "a removed site's shared documents leave no personal tombstones",
    () async {
      await sharedDoc();
      final newId = await SiteDetacher().detachOrRemove(
        siteId: 'lib',
        ownerDiverId: 'd1',
      );
      expect(newId, isNull);
      expect(await DocumentRepository().getById('club'), isNull);
      expect(
        await DocumentRepository().getById(detachedDocumentId('club')),
        isNull,
      );
      expect(await tombstones('documents', 'club'), 0);
      expect(await tombstones('documentPages', 'p1'), 0);
    },
  );

  test(
    'a second device that detached first is relinked, not duplicated',
    () async {
      await privateDoc();
      await sharedDoc();
      final first = await SiteDetacher().detachOrRemove(
        siteId: 'lib',
        ownerDiverId: 'd1',
      );
      expect(detachedDocumentId('club'), detachedDocumentId('club'));
      expect(first, detachedSiteId('lib'));
    },
  );

  test('leaving a library removes its document states', () async {
    await sharedDoc();
    await SharedLibraryStore().upsertLibrary(
      const SharedLibrary(
        id: 'L',
        name: 'Reef Club',
        connectedAccountId: 'acc',
        prefix: 'site-sync',
      ),
    );
    await SharedLibraryStore().deleteLibrary('L');
    expect(await SharedLibraryStore().getDocumentState('club'), isNull);
  });

  test('a private copy has the same page ids on every device', () async {
    await sharedDoc();
    final copyId = await LibraryDocumentStamper().keepAsPrivate('club', 'd1');
    final pages = await DocumentRepository().getPages(copyId);
    expect(pages.single.id, privateCopyPageId(copyId, 'p1'));
  });

  test(
    'a copy that already arrived by personal sync is kept, not doubled',
    () async {
      await sharedDoc();
      final copyId = await LibraryDocumentStamper().keepAsPrivate('club', 'd1');
      final first = (await DocumentRepository().getPages(copyId)).single;
      // Another device's detach, with the library rows back on this one.
      await sharedDoc();
      await LibraryDocumentStamper().keepAsPrivate('club', 'd1');
      final pages = await DocumentRepository().getPages(copyId);
      expect(pages, hasLength(1));
      // Kept as it arrived: not saved again, so personal sync re-sends
      // nothing.
      expect(pages.single.id, first.id);
      expect(pages.single.hlc, first.hlc);
      expect(await DocumentRepository().getById('club'), isNull);
    },
  );
}
