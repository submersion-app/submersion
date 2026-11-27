import 'dart:typed_data';

import 'package:drift/drift.dart' show Variable;

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/shared_library/library_document_stamper.dart';
import 'package:submersion/core/services/shared_library/shared_document_state.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';

import '../../../helpers/test_database.dart';

void main() {
  late LibraryDocumentStamper stamper;

  Future<void> library({required bool editor}) =>
      SharedLibraryStore().upsertLibrary(
        SharedLibrary(
          id: 'L',
          name: 'Reef Club',
          connectedAccountId: 'acc',
          prefix: 'site-sync',
          roles: SharedLibraryRoles(
            owners: const {'o'},
            editors: {if (editor) 'm1'},
          ),
        ),
      );

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
    await SharedLibraryStore().upsertMembership(
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
    await library(editor: true);
    await SiteRepository().createSite(
      const DiveSite(id: 's', name: 'S', sharedLibraryId: 'L'),
    );
    await SiteRepository().createSite(const DiveSite(id: 'p', name: 'Mine'));
    stamper = LibraryDocumentStamper();
  });
  tearDown(tearDownTestDatabase);

  Future<String> personalDoc({
    String site = 's',
    DocumentType type = DocumentType.map,
  }) async => (await DocumentRepository().save(
    Document(
      id: '',
      diverId: 'd1',
      owner: DocumentOwner(DocumentOwnerKind.site, site),
      type: type,
      title: 'Access',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
    [
      DocumentPage(
        id: '',
        documentId: '',
        pageIndex: 0,
        fileName: 'a.pdf',
        mimeType: 'application/pdf',
        sizeBytes: 2,
        bytes: Uint8List.fromList([1, 2]),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    ],
  )).id;

  Future<Set<String>> tombstoned(String entity) async => {
    for (final r
        in await DatabaseService.instance.database
            .customSelect(
              'SELECT record_id FROM deletion_log WHERE entity_type = ?',
              variables: [Variable.withString(entity)],
            )
            .get())
      r.read<String>('record_id'),
  };

  test(
    'share keeps the id, clears the diver and tombstones the personal rows',
    () async {
      final id = await personalDoc();
      final pageIds = [
        for (final p in await DocumentRepository().getPages(id)) p.id,
      ];
      await stamper.share(id, libraryId: 'L', actingDiverId: 'd1');
      final doc = (await DocumentRepository().getById(id))!;
      expect(doc.diverId, isNull);
      expect(doc.sharedLibraryId, 'L');
      expect(await tombstoned('documents'), {id});
      expect(await tombstoned('documentPages'), pageIds.toSet());
      final state = (await SharedLibraryStore().getDocumentState(id))!;
      expect(state.dirty, isTrue);
      expect(state.siteId, 's');
      expect(
        state.clocks.keys,
        containsAll(['type', 'title', 'pages', 'tags']),
      );
      expect(state.clocks.values.map((c) => c.memberId).toSet(), {'m1'});
    },
  );

  test('stamp advances clocks past existing ones and marks dirty', () async {
    final id = await personalDoc();
    await stamper.share(id, libraryId: 'L', actingDiverId: 'd1');
    final before = (await SharedLibraryStore().getDocumentState(id))!;
    await SharedLibraryStore().putDocumentState(before.copyWith(dirty: false));
    await stamper.stamp(id, {'title'}, actingDiverId: 'd1');
    final after = (await SharedLibraryStore().getDocumentState(id))!;
    expect(after.dirty, isTrue);
    expect(
      after.clocks['title']!.hlc.compareTo(before.clocks['title']!.hlc),
      greaterThan(0),
    );
    expect(after.clocks['notes'], before.clocks['notes']);
  });

  test('stamp on a personal document does nothing', () async {
    final id = await personalDoc();
    await stamper.stamp(id, {'title'}, actingDiverId: 'd1');
    expect(await SharedLibraryStore().getDocumentState(id), isNull);
  });

  test(
    'unshare tombstones the library record and leaves a private copy',
    () async {
      final id = await personalDoc();
      await stamper.share(id, libraryId: 'L', actingDiverId: 'd1');
      final copyId = await stamper.unshare(id, actingDiverId: 'd1');
      expect(copyId, unsharedDocumentId(id, 'd1'));
      expect(await DocumentRepository().getById(id), isNull);
      final copy = (await DocumentRepository().getById(copyId))!;
      expect(copy.diverId, 'd1');
      expect(copy.sharedLibraryId, isNull);
      expect(copy.owner, const DocumentOwner(DocumentOwnerKind.site, 's'));
      expect((await DocumentRepository().getPages(copyId)).single.bytes, [
        1,
        2,
      ]);
      final state = (await SharedLibraryStore().getDocumentState(id))!;
      expect(state.deleted, isTrue);
      expect(state.dirty, isTrue);
      expect(state.clocks['deleted'], isNotNull);
    },
  );

  test('unsharedDocumentId is deterministic and never the original', () {
    expect(unsharedDocumentId('x', 'd1'), unsharedDocumentId('x', 'd1'));
    expect(unsharedDocumentId('x', 'd1'), isNot('x'));
    expect(unsharedDocumentId('x', 'd1'), isNot(unsharedDocumentId('x', 'd2')));
  });

  test('a reader may not edit a shared document', () async {
    final id = await personalDoc();
    await stamper.share(id, libraryId: 'L', actingDiverId: 'd1');
    expect(await stamper.mayEdit(id, actingDiverId: 'd1'), isTrue);
    await library(editor: false);
    expect(await stamper.mayEdit(id, actingDiverId: 'd1'), isFalse);
    expect(await stamper.mayEdit(await personalDoc(site: 'p')), isTrue);
  });

  group('default on create', () {
    for (final type in DocumentType.values) {
      final private = {
        DocumentType.receipt,
        DocumentType.insurance,
        DocumentType.medicalClearance,
        DocumentType.certificationCard,
        DocumentType.booking,
      }.contains(type);
      test('a new ${type.name} on a library site is '
          '${private ? 'private' : 'shared'}', () async {
        expect(startsPrivateOnLibrarySite(type), private);
        final id = await personalDoc(type: type);
        final shared = await stamper.shareIfDefault(id, actingDiverId: 'd1');
        expect(shared, !private);
        expect((await DocumentRepository().getById(id))!.isShared, !private);
      });
    }

    test("a reader's new document on a library site is private", () async {
      await library(editor: false);
      final id = await personalDoc();
      expect(await stamper.shareIfDefault(id, actingDiverId: 'd1'), isFalse);
      expect((await DocumentRepository().getById(id))!.isShared, isFalse);
    });

    test('a new document on a personal site stays personal', () async {
      final id = await personalDoc(site: 'p');
      expect(await stamper.shareIfDefault(id, actingDiverId: 'd1'), isFalse);
    });
  });

  test('a clock state keeps unknown fields of an older document', () async {
    final id = await personalDoc();
    await SharedLibraryStore().putDocumentState(
      SharedDocumentState(
        documentId: id,
        libraryId: 'L',
        siteId: 's',
        clocks: {'title': const FieldClock(hlc: const Hlc(9, 0, 'm2'), memberId: 'm2')},
      ),
    );
    await stamper.share(id, libraryId: 'L', actingDiverId: 'd1');
    final state = (await SharedLibraryStore().getDocumentState(id))!;
    expect(state.clocks['title']!.hlc.physicalTime, greaterThanOrEqualTo(9));
    expect(state.clocks['title']!.memberId, 'm1');
  });
}
