import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/document_ids.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';

import '../../../../helpers/test_database.dart';

Document newDoc({
  String id = '',
  DocumentOwner owner = const DocumentOwner.personal(),
  DocumentType type = DocumentType.other,
  bool primary = false,
  DateTime? expiry,
}) => Document(
  id: id,
  diverId: 'd1',
  owner: owner,
  type: type,
  isPrimary: primary,
  expiryDate: expiry,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

DocumentPage page(int index, List<int> bytes, {DocumentPageSide? side}) =>
    DocumentPage(
      id: '',
      documentId: '',
      pageIndex: index,
      side: side,
      fileName: 'p$index.jpg',
      mimeType: 'image/jpeg',
      sizeBytes: bytes.length,
      bytes: Uint8List.fromList(bytes),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

Future<int> tombstones(AppDatabase db, String entity) async =>
    (await db
            .customSelect(
              'SELECT COUNT(*) AS n FROM deletion_log WHERE entity_type = ?',
              variables: [Variable.withString(entity)],
            )
            .getSingle())
        .read<int>('n');

Future<Set<String>> pendingEntities(AppDatabase db) async => {
  for (final r
      in await db
          .customSelect(
            "SELECT entity_type FROM sync_records WHERE sync_status = 'pending'",
          )
          .get())
    r.read<String>('entity_type'),
};

Future<void> seedCert(AppDatabase db, String id) => db.customStatement(
  'INSERT INTO certifications (id, diver_id, name, agency, created_at, '
  "updated_at) VALUES ('$id', 'd1', 'OW', 'padi', 0, 0)",
);

void main() {
  late AppDatabase db;
  late DocumentRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = DocumentRepository();
    await db.customStatement(
      'INSERT INTO divers (id, name, created_at, updated_at) '
      "VALUES ('d1', 'Ana', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO trips (id, diver_id, name, start_date, end_date, '
      "created_at, updated_at) VALUES ('t1', 'd1', 'Bonaire', 0, 0, 0, 0)",
    );
  });
  tearDown(tearDownTestDatabase);

  test(
    'save creates a document with ordered pages and marks them pending',
    () async {
      final saved = await repo.save(newDoc(), [
        page(0, [1]),
        page(1, [2]),
      ]);
      expect(saved.id, isNotEmpty);
      final pages = await repo.getPages(saved.id);
      expect([for (final p in pages) p.bytes!.first], [1, 2]);
      expect([for (final p in pages) p.pageIndex], [0, 1]);
      expect(
        await pendingEntities(db),
        containsAll(['documents', 'documentPages']),
      );
    },
  );

  test('save reorders, keeps and removes pages; removed ones are '
      'tombstoned', () async {
    final saved = await repo.save(newDoc(), [
      page(0, [1]),
      page(1, [2]),
    ]);
    final pages = await repo.getPages(saved.id);
    await repo.save(saved, [pages[1]]);
    final after = await repo.getPages(saved.id);
    expect(after.single.id, pages[1].id);
    expect(after.single.pageIndex, 0);
    expect(await tombstones(db, 'documentPages'), 1);
  });

  test('a page without bytes keeps its stored content', () async {
    final saved = await repo.save(newDoc(), [
      page(0, [7]),
    ]);
    final meta = (await repo.getPages(saved.id, withBytes: false)).single;
    expect(meta.bytes, isNull);
    await repo.save(saved, [meta]);
    expect((await repo.getPages(saved.id)).single.bytes, [7]);
  });

  test('only one primary insurance per diver', () async {
    final a = await repo.save(
      newDoc(type: DocumentType.insurance, primary: true),
      const [],
    );
    final b = await repo.save(
      newDoc(type: DocumentType.insurance, primary: true),
      const [],
    );
    expect((await repo.getById(a.id))!.isPrimary, isFalse);
    final primaries = await repo.primaryInsuranceByDiver();
    expect(primaries.keys, ['d1']);
    expect(primaries['d1']!.id, b.id);
  });

  test('primary is only kept for insurance', () async {
    final d = await repo.save(
      newDoc(type: DocumentType.permit, primary: true),
      const [],
    );
    expect((await repo.getById(d.id))!.isPrimary, isFalse);
  });

  test('two primaries from a sync merge resolve to the newest', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final (id, at) in [('x', now - 1000), ('y', now)]) {
      await db.customStatement(
        'INSERT INTO documents (id, diver_id, type, is_primary, created_at, '
        "updated_at) VALUES ('$id', 'd1', 'insurance', 1, 0, $at)",
      );
    }
    expect((await repo.primaryInsuranceByDiver())['d1']!.id, 'y');
  });

  test('latest clearance expiry per diver', () async {
    for (final y in [2025, 2028, 2027]) {
      await repo.save(
        newDoc(type: DocumentType.medicalClearance, expiry: DateTime(y)),
        const [],
      );
    }
    expect((await repo.latestClearanceExpiryByDiver())['d1'], DateTime(2028));
  });

  test('getForOwner separates personal and owned documents', () async {
    await repo.save(newDoc(), const []);
    await repo.save(
      newDoc(owner: const DocumentOwner(DocumentOwnerKind.trip, 't1')),
      const [],
    );
    expect(
      await repo.getForOwner(const DocumentOwner.personal()),
      hasLength(1),
    );
    expect(
      await repo.getForOwner(const DocumentOwner(DocumentOwnerKind.trip, 't1')),
      hasLength(1),
    );
  });

  test('deleteForOwner removes and tombstones documents and pages', () async {
    await repo.save(
      newDoc(owner: const DocumentOwner(DocumentOwnerKind.trip, 't1')),
      [
        page(0, [1]),
      ],
    );
    await repo.deleteForOwner(DocumentOwnerKind.trip, 't1');
    expect(
      await repo.getForOwner(const DocumentOwner(DocumentOwnerKind.trip, 't1')),
      isEmpty,
    );
    expect(await tombstones(db, 'documents'), 1);
    expect(await tombstones(db, 'documentPages'), 1);
  });

  test('deleteForOwner refuses the personal kind', () async {
    expect(
      () => repo.deleteForOwner(DocumentOwnerKind.personal, 'd1'),
      throwsArgumentError,
    );
  });

  test('delete tombstones the document and its pages', () async {
    final saved = await repo.save(newDoc(), [
      page(0, [1]),
      page(1, [2]),
    ]);
    await repo.delete(saved.id);
    expect(await repo.getById(saved.id), isNull);
    expect(await tombstones(db, 'documentPages'), 2);
    expect(await tombstones(db, 'documents'), 1);
  });

  test('getAllForDiver labels the owner and counts pages', () async {
    await repo.save(
      newDoc(owner: const DocumentOwner(DocumentOwnerKind.trip, 't1')),
      [
        page(0, [1]),
        page(1, [2]),
      ],
    );
    final all = await repo.getAllForDiver('d1');
    expect(all.single.ownerLabel, 'Bonaire');
    expect(all.single.pageCount, 2);
  });

  test('card images: save, read, clear one side, clear both', () async {
    await seedCert(db, 'c1');
    await repo.saveCardImages(
      certificationId: 'c1',
      diverId: 'd1',
      front: Uint8List.fromList([1]),
      back: Uint8List.fromList([2]),
    );
    var images = await repo.cardImagesFor(['c1']);
    expect(images['c1']!.front, [1]);
    expect(images['c1']!.back, [2]);
    final docId = documentCertificationCardId('c1');
    expect((await repo.getById(docId))!.type, DocumentType.certificationCard);

    await repo.saveCardImages(
      certificationId: 'c1',
      diverId: 'd1',
      front: Uint8List.fromList([1]),
      back: null,
    );
    images = await repo.cardImagesFor(['c1']);
    expect(images['c1']!.front, [1]);
    expect(images['c1']!.back, isNull);

    await repo.saveCardImages(
      certificationId: 'c1',
      diverId: 'd1',
      front: null,
      back: null,
    );
    expect(await repo.getById(docId), isNull);
  });

  test('saveCardImages with unchanged bytes writes nothing', () async {
    await seedCert(db, 'c1');
    await repo.saveCardImages(
      certificationId: 'c1',
      diverId: 'd1',
      front: Uint8List.fromList([9, 9]),
      back: null,
    );
    await db.customStatement('DELETE FROM sync_records');
    await repo.saveCardImages(
      certificationId: 'c1',
      diverId: 'd1',
      front: Uint8List.fromList([9, 9]),
      back: null,
    );
    expect(await db.customSelect('SELECT * FROM sync_records').get(), isEmpty);
  });

  test('saveCardImages with no images and no card writes nothing', () async {
    await repo.saveCardImages(
      certificationId: 'c9',
      diverId: 'd1',
      front: null,
      back: null,
    );
    expect(await repo.getById(documentCertificationCardId('c9')), isNull);
    expect(await db.customSelect('SELECT * FROM sync_records').get(), isEmpty);
  });

  test('reminding documents exclude cards and undated ones', () async {
    await repo.save(newDoc(expiry: DateTime(2027)), const []);
    await repo.save(newDoc(), const []);
    await repo.save(
      newDoc(type: DocumentType.certificationCard, expiry: DateTime(2027)),
      const [],
    );
    expect(await repo.getRemindingForDiver('d1'), hasLength(1));
  });
}
