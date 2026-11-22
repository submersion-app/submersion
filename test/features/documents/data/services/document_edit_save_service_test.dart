import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/data/services/document_edit_save_service.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';
import 'package:submersion/features/documents/presentation/editing/document_record.dart';
import 'package:submersion/features/tags/data/repositories/tag_link_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart' as domain;

import '../../../../helpers/test_database.dart';

/// Records whether the tags were rewritten.
class _SpyTags extends TagLinkRepository {
  _SpyTags() : super(domain.TagScope.documents);

  int replaced = 0;
  bool failRead = false;

  @override
  Future<List<domain.Tag>> getTagsFor(String itemId) {
    if (failRead) throw StateError('tags unreadable');
    return super.getTagsFor(itemId);
  }

  @override
  Future<void> replaceTags(
    String itemId,
    List<String> tagIds, {
    bool notify = true,
  }) {
    replaced += 1;
    return super.replaceTags(itemId, tagIds, notify: notify);
  }
}

DocumentPage _page(int index) => DocumentPage(
  id: '',
  documentId: '',
  pageIndex: index,
  fileName: 'p$index.jpg',
  mimeType: 'image/jpeg',
  sizeBytes: 1,
  bytes: Uint8List.fromList([index]),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

/// A document page's sitting is written as one History entry: the row, its
/// pages and its tags, and only what it changed (issue #4527, phase 3).
void main() {
  late AppDatabase db;
  late DocumentRepository documents;
  late _SpyTags tags;
  late DocumentEditSaveService service;
  final changeLog = ChangeLogRepository();

  Future<DocumentRecord> stored() async => (await service.read('doc'))!;

  Future<List<Map<String, Object?>>> operations() async {
    await changeLog.settleAll();
    final rows = await db
        .customSelect('SELECT source, label FROM change_log_operations')
        .get();
    return [for (final row in rows) row.data];
  }

  /// Changes the stored document as another device would.
  Future<void> underneath(Document Function(Document d) change) async {
    final now = await stored();
    await documents.save(change(now.document), now.pages, notify: false);
  }

  Future<void> clearLog() async {
    await changeLog.settleAll();
    await db.customStatement('DELETE FROM change_log_operations');
  }

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    documents = DocumentRepository();
    tags = _SpyTags();
    service = DocumentEditSaveService(documents, tags);
    await db.customStatement(
      'INSERT INTO divers (id, name, created_at, updated_at) '
      "VALUES ('d1', 'Ana', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO tags (id, diver_id, name, created_at, updated_at, '
      "applies_to_documents) VALUES ('t1', 'd1', 'Travel', 0, 0, 1), "
      "('t2', 'd1', 'Club', 0, 0, 1)",
    );
    await documents.save(
      Document(
        id: 'doc',
        diverId: 'd1',
        owner: const DocumentOwner.personal(),
        type: DocumentType.insurance,
        title: 'Travel',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      [_page(0)],
      tagIds: ['t1'],
    );
    await clearLog();
    tags.replaced = 0;
  });

  tearDown(tearDownTestDatabase);

  test('reads the row, its pages without bytes, and its tags', () async {
    final record = await stored();

    expect(record.document.title, 'Travel');
    expect(record.pages, hasLength(1));
    expect(record.pages.single.bytes, isNull);
    expect(record.tagIds, ['t1']);
  });

  test('a failed tag read gives null tags', () async {
    tags.failRead = true;

    expect((await stored()).tagIds, isNull);
  });

  test('writes a title change as one History entry', () async {
    final before = await stored();

    await service.save(
      documentId: 'doc',
      apply: (s) => s.copyWith(document: s.document.copyWith(title: 'Trip')),
      changedCardIds: const ['details'],
    );

    expect((await stored()).document.title, 'Trip');
    expect(before.document.title, 'Travel');
    final ops = await operations();
    expect(ops, hasLength(1));
    expect(ops.single['label'], 'record_edit:documents:doc:details');
  });

  // One case per column the document's save writes: a value changed in
  // storage during the sitting, on a field the diver did not touch,
  // survives the Save of another field.
  final census =
      <
        String,
        ({Document Function(Document) change, bool Function(Document) kept})
      >{
        'type': (
          change: (d) => d.copyWith(type: DocumentType.permit),
          kept: (d) => d.type == DocumentType.permit,
        ),
        'owner': (
          change: (d) => d.copyWith(
            owner: const DocumentOwner(DocumentOwnerKind.trip, 't9'),
          ),
          kept: (d) => d.owner.kind == DocumentOwnerKind.trip,
        ),
        'issuer': (
          change: (d) => d.copyWith(issuer: 'DAN'),
          kept: (d) => d.issuer == 'DAN',
        ),
        'reference number': (
          change: (d) => d.copyWith(referenceNumber: 'R-1'),
          kept: (d) => d.referenceNumber == 'R-1',
        ),
        'issue date': (
          change: (d) => d.copyWith(issueDate: DateTime(2025, 1, 2)),
          kept: (d) => d.issueDate == DateTime(2025, 1, 2),
        ),
        'expiry date': (
          change: (d) => d.copyWith(expiryDate: DateTime(2027, 1, 2)),
          kept: (d) => d.expiryDate == DateTime(2027, 1, 2),
        ),
        'reminder lead': (
          change: (d) => d.copyWith(reminderLeadDays: 7),
          kept: (d) => d.reminderLeadDays == 7,
        ),
        'emergency phone': (
          change: (d) => d.copyWith(emergencyPhone: '911'),
          kept: (d) => d.emergencyPhone == '911',
        ),
        'phone': (
          change: (d) => d.copyWith(phone: '555'),
          kept: (d) => d.phone == '555',
        ),
        'primary': (
          change: (d) => d.copyWith(isPrimary: true),
          kept: (d) => d.isPrimary,
        ),
        'notes': (
          change: (d) => d.copyWith(notes: 'Keep in the bag'),
          kept: (d) => d.notes == 'Keep in the bag',
        ),
      };
  for (final MapEntry(key: column, value: c) in census.entries) {
    test('a $column changed underneath keeps its newer value', () async {
      // The sitting's change: the title, applied to whatever is stored.
      DocumentRecord apply(DocumentRecord s) =>
          s.copyWith(document: s.document.copyWith(title: 'Trip'));
      // An owner other than personal needs a trip to file under.
      if (column == 'owner') {
        await db.customStatement(
          'INSERT INTO trips (id, diver_id, name, start_date, end_date, '
          "created_at, updated_at) VALUES ('t9', 'd1', 'Bonaire', 0, 0, 0, 0)",
        );
        await underneath(
          (d) => d.copyWith(
            owner: const DocumentOwner(DocumentOwnerKind.trip, 't9'),
          ),
        );
      } else {
        await underneath(c.change);
      }

      await service.save(
        documentId: 'doc',
        apply: apply,
        changedCardIds: const ['details'],
      );

      final after = (await stored()).document;
      expect(c.kept(after), isTrue, reason: column);
      expect(after.title, 'Trip');
    });
  }

  test('a page added underneath survives a details save', () async {
    final now = await stored();
    await documents.save(now.document, [...now.pages, _page(1)], notify: false);

    await service.save(
      documentId: 'doc',
      apply: (s) => s.copyWith(document: s.document.copyWith(title: 'Trip')),
      changedCardIds: const ['details'],
    );

    expect((await stored()).pages, hasLength(2));
  });

  test('a Pages change saves the sitting\'s pages, the new one with its '
      'bytes and the removed one gone', () async {
    final before = await stored();

    await service.save(
      documentId: 'doc',
      apply: (s) => s.copyWith(
        pages: [
          DocumentPage(
            id: '',
            documentId: '',
            pageIndex: 0,
            fileName: 'scan.jpg',
            mimeType: 'image/jpeg',
            sizeBytes: 2,
            bytes: Uint8List.fromList([7, 7]),
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        ],
      ),
      changedCardIds: const ['pages'],
    );

    final pages = (await stored()).pages;
    expect(pages, hasLength(1));
    expect(pages.single.fileName, 'scan.jpg');
    expect(pages.single.id, isNot(before.pages.single.id));
    expect(await documents.getPageContent(pages.single.id), [7, 7]);
  });

  test(
    'a document filed under a trip moved to Personal clears its trip',
    () async {
      await db.customStatement(
        'INSERT INTO trips (id, diver_id, name, start_date, end_date, '
        "created_at, updated_at) VALUES ('t9', 'd1', 'Bonaire', 0, 0, 0, 0)",
      );
      await underneath(
        (d) => d.copyWith(
          owner: const DocumentOwner(DocumentOwnerKind.trip, 't9'),
        ),
      );

      await service.save(
        documentId: 'doc',
        apply: (s) => s.copyWith(
          document: s.document.copyWith(owner: const DocumentOwner.personal()),
        ),
        changedCardIds: const ['details'],
      );

      expect((await stored()).document.owner.kind, DocumentOwnerKind.personal);
      final row = await db
          .customSelect("SELECT trip_id FROM documents WHERE id = 'doc'")
          .getSingle();
      expect(row.data['trip_id'], isNull);
    },
  );

  test('unchanged tags are not written', () async {
    await service.save(
      documentId: 'doc',
      apply: (s) => s.copyWith(document: s.document.copyWith(title: 'Trip')),
      changedCardIds: const ['details'],
    );

    expect(tags.replaced, 0);
  });

  test('changed tags are written', () async {
    await service.save(
      documentId: 'doc',
      apply: (s) => s.copyWith(tagIds: ['t1', 't2']),
      changedCardIds: const ['details'],
    );

    expect((await stored()).tagIds?.toSet(), {'t1', 't2'});
  });

  test('null tags leave the stored tags alone', () async {
    await service.save(
      documentId: 'doc',
      apply: (s) => s.copyWith(
        document: s.document.copyWith(title: 'Trip'),
        clearTags: true,
      ),
      changedCardIds: const ['details'],
    );

    expect(tags.replaced, 0);
    expect((await stored()).tagIds, ['t1']);
  });

  test('marking it primary clears another primary insurance', () async {
    await documents.save(
      Document(
        id: 'other',
        diverId: 'd1',
        owner: const DocumentOwner.personal(),
        type: DocumentType.insurance,
        isPrimary: true,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      const [],
    );
    await clearLog();

    await service.save(
      documentId: 'doc',
      apply: (s) => s.copyWith(document: s.document.copyWith(isPrimary: true)),
      changedCardIds: const ['details'],
    );

    expect((await documents.getById('other'))!.isPrimary, isFalse);
    expect((await documents.getById('doc'))!.isPrimary, isTrue);
    expect(await operations(), hasLength(1));
  });

  test('unchanged returns null and writes nothing', () async {
    final result = await service.save(
      documentId: 'doc',
      apply: (s) => s,
      changedCardIds: const [],
    );

    expect(result, isNull);
    expect(await operations(), isEmpty);
  });

  test('a document that has gone throws', () async {
    await documents.delete('doc');
    await clearLog();

    await expectLater(
      service.save(
        documentId: 'doc',
        apply: (s) => s,
        changedCardIds: const ['details'],
      ),
      throwsStateError,
    );
  });

  /// A new document's sitting (issue #4527, phase 3, plan 11).
  group('create', () {
    DocumentRecord fresh({String id = 'n1'}) => DocumentRecord(
      document: Document(
        id: id,
        diverId: 'd1',
        owner: const DocumentOwner.personal(),
        type: DocumentType.permit,
        title: 'Nitrox',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      pages: [_page(0)],
      tagIds: const ['t2'],
    );

    test('creates the document with its id, as one History entry', () async {
      final created = await service.create(
        record: fresh(),
        changedCardIds: const ['details'],
      );

      expect(created.id, 'n1');
      final ops = await operations();
      expect(ops, hasLength(1));
      expect(ops.single['source'], 'manual');
      expect(ops.single['label'], 'record_edit:documents:n1:details');
    });

    test('pages and tags are written with the row', () async {
      await service.create(record: fresh(), changedCardIds: const ['details']);

      final read = (await service.read('n1'))!;
      expect(read.document.title, 'Nitrox');
      expect(read.pages, hasLength(1));
      expect(read.tagIds, ['t2']);
    });

    test('held writes run after the row, in the same entry', () async {
      Document? seen;
      await service.create(
        record: fresh(),
        changedCardIds: const ['details'],
        alsoWrite: () async => seen = await documents.getById('n1'),
      );

      expect(seen?.title, 'Nitrox');
      expect(await operations(), hasLength(1));
    });

    test('a held write that throws leaves nothing', () async {
      await expectLater(
        service.create(
          record: fresh(),
          changedCardIds: const ['details'],
          alsoWrite: () async => throw StateError('refused'),
        ),
        throwsStateError,
      );

      expect(await documents.getById('n1'), isNull);
      expect(await documents.getPages('n1', withBytes: false), isEmpty);
      expect(await operations(), isEmpty);
    });

    test('an empty id or one already stored is refused', () async {
      await expectLater(
        service.create(
          record: fresh(id: ''),
          changedCardIds: const [],
        ),
        throwsStateError,
      );
      await expectLater(
        service.create(
          record: fresh(id: 'doc'),
          changedCardIds: const [],
        ),
        throwsStateError,
      );

      expect((await stored()).document.title, 'Travel');
      expect(await operations(), isEmpty);
    });
  });
}
