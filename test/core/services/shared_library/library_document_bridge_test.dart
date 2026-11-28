import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/services/shared_library/crypto/canonical_json.dart';
import 'package:submersion/core/services/shared_library/library_document_bridge.dart';
import 'package:submersion/core/services/shared_library/library_document_record.dart';
import 'package:submersion/core/services/shared_library/shared_document_state.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';
import 'package:submersion/features/tags/data/repositories/tag_link_repository.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

import '../../../helpers/test_database.dart';

FieldClock c(int t) => FieldClock(hlc: Hlc(t, 0, 'm1'), memberId: 'm1');

DocumentPage page(int index, List<int> bytes) => DocumentPage(
  id: '',
  documentId: '',
  pageIndex: index,
  fileName: 'p$index.pdf',
  mimeType: 'application/pdf',
  sizeBytes: bytes.length,
  bytes: Uint8List.fromList(bytes),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  late AppDatabase db;
  late LibraryDocumentBridge bridge;
  const state = SharedDocumentState(
    documentId: 'doc1',
    libraryId: 'L',
    siteId: 's1',
  );

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement(
      'INSERT INTO divers (id, name, is_default, created_at, updated_at) '
      "VALUES ('d1', 'Ana', 1, 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO dive_sites (id, name, created_at, updated_at, '
      "shared_library_id) VALUES ('s1', 'Reef', 0, 0, 'L')",
    );
    bridge = LibraryDocumentBridge();
  });
  tearDown(tearDownTestDatabase);

  Future<String> savedDoc({List<String> tagIds = const []}) async =>
      (await DocumentRepository().save(
        Document(
          id: '',
          diverId: 'd1',
          owner: const DocumentOwner(DocumentOwnerKind.site, 's1'),
          type: DocumentType.map,
          title: 'Access',
          issuer: 'Club',
          notes: 'Park at the lighthouse',
          expiryDate: DateTime.utc(2027),
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
        [
          page(0, [1, 2, 3]),
          page(1, [4, 5]),
        ],
        tagIds: tagIds,
      )).id;

  test('build reads every clocked field and the page hashes', () async {
    final tag = await TagRepository().createTag(
      Tag(
        id: '',
        diverId: 'd1',
        name: 'Parking',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    final id = await savedDoc(tagIds: [tag.id]);
    final record = await bridge.build(
      id,
      SharedDocumentState(
        documentId: id,
        libraryId: 'L',
        siteId: 's1',
        clocks: {'title': c(3)},
      ),
    );
    expect(record.siteId, 's1');
    expect(record.clocks, {'title': c(3)});
    expect(record.fields['type'], 'map');
    expect(record.fields['title'], 'Access');
    expect(record.fields['issuer'], 'Club');
    expect(record.fields['notes'], 'Park at the lighthouse');
    expect(
      record.fields['expiryDate'],
      DateTime.utc(2027).millisecondsSinceEpoch,
    );
    expect(record.fields['tags'], ['Parking']);
    final refs = record.pageRefs;
    expect(refs.map((r) => r.pageIndex), [0, 1]);
    expect(refs.first.sha256, sha256Hex([1, 2, 3]));
    expect(refs.first.sizeBytes, 3);
  });

  test(
    'build twice gives the same file ids; a new scan gets a new one',
    () async {
      final id = await savedDoc();
      final s = SharedDocumentState(
        documentId: id,
        libraryId: 'L',
        siteId: 's1',
      );
      final first = (await bridge.build(id, s)).pageRefs;
      final second = (await bridge.build(id, s)).pageRefs;
      expect(second.map((r) => r.fileId), first.map((r) => r.fileId));

      final repo = DocumentRepository();
      final pages = await repo.getPages(id);
      await repo.save((await repo.getById(id))!, [
        pages.first.copyWith(bytes: Uint8List.fromList([9, 9, 9])),
        pages.last,
      ]);
      final third = (await bridge.build(id, s)).pageRefs;
      expect(third.first.fileId, isNot(first.first.fileId));
      expect(third.last.fileId, first.last.fileId);
    },
  );

  test('build of a document with no row throws', () async {
    expect(() => bridge.build('gone', state), throwsStateError);
  });

  LibraryDocumentRecord incoming({
    List<String> tags = const ['parking'],
    String title = 'Shore access',
  }) => LibraryDocumentRecord(
    id: 'doc1',
    siteId: 's1',
    fields: {
      'type': 'map',
      'title': title,
      'issuer': null,
      'notes': 'North slipway',
      'tags': tags,
      'pages': [
        {
          'id': 'p1',
          'pageIndex': 0,
          'side': null,
          'fileName': 'access.pdf',
          'mimeType': 'application/pdf',
          'sizeBytes': 3,
          'fileId': 'f1',
          'sha256': sha256Hex([7, 8, 9]),
        },
      ],
    },
    clocks: {'title': c(5)},
  );

  test(
    'apply creates a library row with no diver, filed on the site',
    () async {
      await bridge.apply(
        incoming(),
        libraryId: 'L',
        vocabularyDiverId: 'd1',
        pageBytesByFileId: {
          'f1': Uint8List.fromList([7, 8, 9]),
        },
      );
      final doc = (await DocumentRepository().getById('doc1'))!;
      expect(doc.diverId, isNull);
      expect(doc.sharedLibraryId, 'L');
      expect(doc.owner, const DocumentOwner(DocumentOwnerKind.site, 's1'));
      expect(doc.title, 'Shore access');
      expect(doc.notes, 'North slipway');
      final pages = await DocumentRepository().getPages('doc1');
      expect(pages.single.bytes, [7, 8, 9]);
      expect(pages.single.libraryFileId, 'f1');
      expect(pages.single.fileName, 'access.pdf');
    },
  );

  test('apply with fields: {title} changes only the title', () async {
    await bridge.apply(
      incoming(),
      libraryId: 'L',
      vocabularyDiverId: 'd1',
      pageBytesByFileId: {
        'f1': Uint8List.fromList([7, 8, 9]),
      },
    );
    await bridge.apply(
      incoming(title: 'Renamed').copyWith(
        fields: {...incoming().fields, 'title': 'Renamed', 'notes': 'Other'},
      ),
      libraryId: 'L',
      vocabularyDiverId: 'd1',
      pageBytesByFileId: const {},
      fields: {'title'},
    );
    final doc = (await DocumentRepository().getById('doc1'))!;
    expect(doc.title, 'Renamed');
    expect(doc.notes, 'North slipway');
  });

  test(
    'tags resolve case-insensitively against the diver\'s vocabulary',
    () async {
      final existing = await TagRepository().createTag(
        Tag(
          id: '',
          diverId: 'd1',
          name: 'Parking',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      await bridge.apply(
        incoming(tags: ['parking', 'Tides']),
        libraryId: 'L',
        vocabularyDiverId: 'd1',
        pageBytesByFileId: {
          'f1': Uint8List.fromList([7, 8, 9]),
        },
      );
      final tags = await TagLinkRepository(
        TagScope.documents,
      ).getTagsFor('doc1');
      expect(tags.map((t) => t.name), ['Parking', 'Tides']);
      expect(tags.first.id, existing.id);
    },
  );

  test('apply stamps no personal sync clock on the row or its pages', () async {
    await bridge.apply(
      incoming(),
      libraryId: 'L',
      vocabularyDiverId: 'd1',
      pageBytesByFileId: {
        'f1': Uint8List.fromList([7, 8, 9]),
      },
    );
    final doc = await db
        .customSelect("SELECT hlc FROM documents WHERE id = 'doc1'")
        .getSingle();
    expect(doc.data['hlc'], isNull);
    final pages = await db.customSelect('SELECT hlc FROM document_pages').get();
    expect(pages.single.data['hlc'], isNull);
  });

  test('apply without the bytes of a page it names throws', () async {
    expect(
      () => bridge.apply(
        incoming(),
        libraryId: 'L',
        vocabularyDiverId: 'd1',
        pageBytesByFileId: const {},
      ),
      throwsStateError,
    );
  });

  test('a page already held under its file id needs no bytes', () async {
    await bridge.apply(
      incoming(),
      libraryId: 'L',
      vocabularyDiverId: 'd1',
      pageBytesByFileId: {
        'f1': Uint8List.fromList([7, 8, 9]),
      },
    );
    expect(await bridge.heldFileIds('doc1'), {'f1'});
    await bridge.apply(
      incoming(title: 'Again'),
      libraryId: 'L',
      vocabularyDiverId: 'd1',
      pageBytesByFileId: const {},
    );
    expect((await DocumentRepository().getPages('doc1')).single.bytes, [
      7,
      8,
      9,
    ]);
  });

  group('mayAdopt', () {
    test('a new id, or a row of this library, may be written', () async {
      expect(await bridge.mayAdopt(incoming(), 'L'), isTrue);
      await bridge.apply(
        incoming(),
        libraryId: 'L',
        vocabularyDiverId: 'd1',
        pageBytesByFileId: {
          'f1': Uint8List.fromList([7, 8, 9]),
        },
      );
      expect(await bridge.mayAdopt(incoming(), 'L'), isTrue);
    });

    test('a row of another library is never taken over', () async {
      await bridge.apply(
        incoming(),
        libraryId: 'L',
        vocabularyDiverId: 'd1',
        pageBytesByFileId: {
          'f1': Uint8List.fromList([7, 8, 9]),
        },
      );
      expect(await bridge.mayAdopt(incoming(), 'L2'), isFalse);
    });

    test("the diver's own document on this library's site may be adopted, "
        'one filed elsewhere may not', () async {
      await db.customStatement(
        'INSERT INTO dive_sites (id, name, created_at, updated_at) '
        "VALUES ('mine', 'Mine', 0, 0)",
      );
      for (final (id, site) in [('doc1', 's1'), ('copy', 'mine')]) {
        await DocumentRepository().save(
          Document(
            id: id,
            diverId: 'd1',
            owner: DocumentOwner(DocumentOwnerKind.site, site),
            type: DocumentType.map,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
          const [],
        );
      }
      expect(await bridge.mayAdopt(incoming(), 'L'), isTrue);
      final copy = LibraryDocumentRecord(
        id: 'copy',
        siteId: 's1',
        fields: incoming().fields,
      );
      expect(await bridge.mayAdopt(copy, 'L'), isFalse);
    });

    test("a page id of another document's page is refused", () async {
      final other = await savedDoc();
      final pageId = (await DocumentRepository().getPages(other)).first.id;
      final record = LibraryDocumentRecord(
        id: 'doc9',
        siteId: 's1',
        fields: {
          ...incoming().fields,
          'pages': [
            {
              ...(incoming().fields['pages']! as List).single
                  as Map<String, Object?>,
              'id': pageId,
            },
          ],
        },
      );
      expect(await bridge.mayAdopt(record, 'L'), isFalse);
    });
  });
}
