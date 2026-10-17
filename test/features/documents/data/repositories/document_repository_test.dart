import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
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

  test('a same-size replacement of a page is written', () async {
    final saved = await repo.save(newDoc(), [
      page(0, [1, 2]),
    ]);
    final stored = (await repo.getPages(saved.id)).single;
    await repo.save(saved, [
      stored.copyWith(bytes: Uint8List.fromList([3, 4])),
    ]);
    expect((await repo.getPages(saved.id)).single.bytes, [3, 4]);
  });

  test('saving unchanged pages re-stamps none of them', () async {
    final saved = await repo.save(newDoc(), [
      page(0, [1]),
      page(1, [2]),
    ]);
    final pages = await repo.getPages(saved.id);
    await db.customStatement('DELETE FROM sync_records');
    await repo.save(saved, pages);
    expect(await pendingEntities(db), {'documents'});
  });

  test('a page moved without its bytes keeps them at its new place', () async {
    final saved = await repo.save(newDoc(), [
      page(0, [1]),
      page(1, [2]),
    ]);
    final meta = await repo.getPages(saved.id, withBytes: false);
    await repo.save(saved, meta.reversed.toList());
    final after = await repo.getPages(saved.id);
    expect([for (final p in after) p.bytes!.single], [2, 1]);
    expect([for (final p in after) p.pageIndex], [0, 1]);
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

  test('with no primary, the newest insurance stands in', () async {
    final older = await repo.save(
      newDoc(type: DocumentType.insurance),
      const [],
    );
    // Two saves can land in one millisecond, which would leave the order to
    // the id tiebreak: back-date the first so "newest" is unambiguous.
    await db.customStatement(
      'UPDATE documents SET updated_at = updated_at - 1000 WHERE id = ?',
      [older.id],
    );
    final newer = await repo.save(
      newDoc(type: DocumentType.insurance),
      const [],
    );
    expect((await repo.primaryInsuranceByDiver())['d1']!.id, newer.id);
    expect(await repo.hasPrimaryInsurance('d1'), isFalse);
  });

  test('a marked primary beats a newer unmarked insurance', () async {
    final primary = await repo.save(
      newDoc(type: DocumentType.insurance, primary: true),
      const [],
    );
    await repo.save(newDoc(type: DocumentType.insurance), const []);
    expect((await repo.primaryInsuranceByDiver())['d1']!.id, primary.id);
    expect(await repo.hasPrimaryInsurance('d1'), isTrue);
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

  test(
    'deleting documents cancels their reminders, owner deletes too',
    () async {
      final cancelled = <String>[];
      final withHook = DocumentRepository(
        cancelReminders: (id) async => cancelled.add(id),
      );
      final a = await withHook.save(
        newDoc(owner: const DocumentOwner(DocumentOwnerKind.trip, 't1')),
        const [],
      );
      final b = await withHook.save(newDoc(), const []);
      await withHook.deleteForOwner(DocumentOwnerKind.trip, 't1');
      await withHook.delete(b.id);
      expect(cancelled, [a.id, b.id]);
    },
  );

  test('a restored snapshot drops the delete\'s tombstones', () async {
    final saved = await repo.save(
      newDoc(owner: const DocumentOwner(DocumentOwnerKind.trip, 't1')),
      [
        page(0, [1]),
      ],
    );
    final snapshot = await repo.captureForOwners(DocumentOwnerKind.trip, [
      't1',
    ]);
    await repo.deleteForOwner(DocumentOwnerKind.trip, 't1');
    expect(await tombstones(db, 'documents'), 1);
    await repo.restoreSnapshot(snapshot);
    expect(await repo.getById(saved.id), isNotNull);
    expect(await tombstones(db, 'documents'), 0);
    expect(await tombstones(db, 'documentPages'), 0);
  });

  test(
    'a first page that is not an image is loaded without its bytes',
    () async {
      final pdf = DocumentPage(
        id: '',
        documentId: '',
        pageIndex: 0,
        fileName: 'a.pdf',
        mimeType: 'application/pdf',
        sizeBytes: 3,
        bytes: Uint8List.fromList([1, 2, 3]),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final a = await repo.save(newDoc(), [pdf]);
      final b = await repo.save(newDoc(), [
        page(0, [7]),
      ]);
      expect((await repo.getFirstPage(a.id))!.bytes, isNull);
      expect((await repo.getFirstPage(b.id))!.bytes, [7]);
    },
  );

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

  test('a dive owner is labelled by number and site, with its date '
      '(#3391)', () async {
    final when = DateTime.utc(2026, 10, 12, 9).millisecondsSinceEpoch;
    await db.customStatement(
      'INSERT INTO dive_sites (id, diver_id, name, created_at, updated_at) '
      "VALUES ('s1', 'd1', 'Blue Hole', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO dives (id, diver_id, dive_number, dive_date_time, site_id, '
      "name, created_at, updated_at) VALUES ('v1', 'd1', 142, $when, 's1', "
      "NULL, 0, 0), ('v2', 'd1', 143, $when, 's1', 'Night dive', 0, 0), "
      "('v3', 'd1', NULL, $when, NULL, NULL, 0, 0)",
    );
    for (final id in ['v1', 'v2', 'v3']) {
      await repo.save(
        newDoc(owner: DocumentOwner(DocumentOwnerKind.dive, id)),
        const [],
      );
    }
    final byDive = {
      for (final e in await repo.getAllForDiver('d1')) e.document.owner.id: e,
    };
    expect(byDive['v1']!.ownerLabel, '#142 · Blue Hole');
    expect(byDive['v1']!.ownerDate, DateTime.utc(2026, 10, 12, 9));
    expect(byDive['v2']!.ownerLabel, '#143 · Night dive');
    // Nothing to name it by but its date.
    expect(byDive['v3']!.ownerLabel, isNull);
    expect(byDive['v3']!.ownerDate, DateTime.utc(2026, 10, 12, 9));
    final trip = await repo.save(
      newDoc(owner: const DocumentOwner(DocumentOwnerKind.trip, 't1')),
      const [],
    );
    expect((await repo.getEntryById(trip.id))!.ownerDate, isNull);
  });

  test(
    'an entry filed under a certification carries its title fields',
    () async {
      // Issue #3366: the stored name is empty for a certification with no
      // custom title, so the list must be able to derive one.
      await db.customStatement(
        'INSERT INTO certifications (id, diver_id, name, agency, level, '
        "created_at, updated_at) VALUES ('c1', 'd1', '', 'padi', "
        "'advancedNitrox', 0, 0)",
      );
      await repo.save(
        newDoc(
          owner: const DocumentOwner(DocumentOwnerKind.certification, 'c1'),
        ),
        [
          page(0, [1]),
        ],
      );
      await repo.save(
        newDoc(owner: const DocumentOwner(DocumentOwnerKind.trip, 't1')),
        [
          page(0, [1]),
        ],
      );
      final all = await repo.getAllForDiver('d1');
      final filed = all.firstWhere(
        (e) => e.document.owner.kind == DocumentOwnerKind.certification,
      );
      expect(filed.certification, (
        name: '',
        agency: 'padi',
        level: 'advancedNitrox',
      ));
      final trip = all.firstWhere(
        (e) => e.document.owner.kind == DocumentOwnerKind.trip,
      );
      expect(trip.certification, isNull);
    },
  );

  test('a certification change notifies watchers', () async {
    // The list derives a certification owner's title from its row, so an
    // edit to the certification must refresh it (#3366).
    await seedCert(db, 'c1');
    final changed = repo.watchChanges().first;
    await db.customUpdate(
      "UPDATE certifications SET level = 'openWater' WHERE id = 'c1'",
      updates: {db.certifications},
      updateKind: UpdateKind.update,
    );
    await expectLater(changed.timeout(const Duration(seconds: 2)), completes);
  });

  test(
    'a burst of owner writes ticks once, after it settles (#3391)',
    () async {
      var ticks = 0;
      final sub = repo.watchOwnerChanges().listen((_) => ticks++);
      addTearDown(sub.cancel);
      for (var i = 0; i < 5; i++) {
        await db.customUpdate(
          "UPDATE trips SET name = 'Bonaire $i' WHERE id = 't1'",
          updates: {db.trips},
          updateKind: UpdateKind.update,
        );
      }
      await pumpEventQueue();
      expect(ticks, 0);
      await Future<void>.delayed(DiveRepository.changeTickDebounce * 2);
      expect(ticks, 1);
    },
  );

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

  test(
    'saveCardImages keeps extra pages the diver added to the card',
    () async {
      await seedCert(db, 'c1');
      await repo.saveCardImages(
        certificationId: 'c1',
        diverId: 'd1',
        front: Uint8List.fromList([1]),
        back: null,
      );
      final docId = documentCertificationCardId('c1');
      final card = (await repo.getById(docId))!;
      final pages = await repo.getPages(docId);
      await repo.save(card.copyWith(notes: 'e-card PDF too'), [
        ...pages,
        page(1, [5]),
      ]);

      // A photo change on the cert page keeps the extra page.
      await repo.saveCardImages(
        certificationId: 'c1',
        diverId: 'd1',
        front: Uint8List.fromList([2]),
        back: null,
      );
      var after = await repo.getPages(docId);
      expect(after.map((p) => p.bytes!.first), containsAll([2, 5]));
      expect(after.where((p) => p.side == null), hasLength(1));

      // Clearing both photos keeps the document, its notes and the extra page.
      await repo.saveCardImages(
        certificationId: 'c1',
        diverId: 'd1',
        front: null,
        back: null,
      );
      after = await repo.getPages(docId);
      expect(after.single.bytes, [5]);
      expect((await repo.getById(docId))!.notes, 'e-card PDF too');
    },
  );

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
