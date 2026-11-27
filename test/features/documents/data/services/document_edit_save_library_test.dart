import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/data/services/document_edit_save_service.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';
import 'package:submersion/features/documents/presentation/editing/document_record.dart';
import 'package:submersion/features/tags/data/repositories/tag_link_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart' as domain;

import '../../../../helpers/test_database.dart';

/// Documents on a shared library site through the editing sitting (issue
/// #4713): a new one starts shared unless its type is private by default,
/// and an edit to a shared one is stamped for upload.
void main() {
  late DocumentEditSaveService service;

  setUp(() async {
    await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    await DiverRepository().createDiver(
      Diver(
        id: 'd1',
        name: 'Ann',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
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
    await SiteRepository().createSite(
      const DiveSite(id: 's', name: 'S', sharedLibraryId: 'L'),
    );
    await SiteRepository().createSite(const DiveSite(id: 'p', name: 'Mine'));
    service = DocumentEditSaveService(
      DocumentRepository(),
      TagLinkRepository(domain.TagScope.documents),
    );
  });
  tearDown(tearDownTestDatabase);

  DocumentRecord record(String id, DocumentType type, {String site = 's'}) =>
      DocumentRecord(
        document: Document(
          id: id,
          diverId: 'd1',
          owner: DocumentOwner(DocumentOwnerKind.site, site),
          type: type,
          title: 'Access',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
        pages: [
          DocumentPage(
            id: '',
            documentId: '',
            pageIndex: 0,
            fileName: 'a.pdf',
            mimeType: 'application/pdf',
            sizeBytes: 1,
            bytes: Uint8List.fromList([1]),
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        ],
        tagIds: const [],
      );

  test('a new map on a library site is created shared', () async {
    await service.create(
      record: record('m', DocumentType.map),
      changedCardIds: const ['details'],
    );
    final doc = (await DocumentRepository().getById('m'))!;
    expect(doc.sharedLibraryId, 'L');
    expect(doc.diverId, isNull);
    expect((await SharedLibraryStore().getDocumentState('m'))!.dirty, isTrue);
  });

  test('a new receipt on a library site is created private', () async {
    await service.create(
      record: record('r', DocumentType.receipt),
      changedCardIds: const ['details'],
    );
    expect((await DocumentRepository().getById('r'))!.isShared, isFalse);
  });

  test('a new map on a personal site stays personal', () async {
    await service.create(
      record: record('x', DocumentType.map, site: 'p'),
      changedCardIds: const ['details'],
    );
    expect((await DocumentRepository().getById('x'))!.isShared, isFalse);
  });

  test('editing a shared document stamps only what changed', () async {
    await service.create(
      record: record('m', DocumentType.map),
      changedCardIds: const ['details'],
    );
    final store = SharedLibraryStore();
    final before = (await store.getDocumentState('m'))!;
    await store.putDocumentState(before.copyWith(dirty: false));
    await service.save(
      documentId: 'm',
      apply: (stored) => stored.copyWith(
        document: stored.document.copyWith(title: 'Shore access'),
      ),
      changedCardIds: const ['details'],
    );
    final after = (await store.getDocumentState('m'))!;
    expect(after.dirty, isTrue);
    expect(
      after.clocks['title']!.hlc.compareTo(before.clocks['title']!.hlc),
      greaterThan(0),
    );
    expect(after.clocks['notes'], before.clocks['notes']);
    expect(after.clocks['pages'], before.clocks['pages']);
    expect((await DocumentRepository().getById('m'))!.title, 'Shore access');
  });

  test('editing a personal document records no library state', () async {
    await service.create(
      record: record('x', DocumentType.map, site: 'p'),
      changedCardIds: const ['details'],
    );
    await service.save(
      documentId: 'x',
      apply: (stored) =>
          stored.copyWith(document: stored.document.copyWith(title: 'Other')),
      changedCardIds: const ['details'],
    );
    expect(await SharedLibraryStore().getDocumentState('x'), isNull);
  });
}
