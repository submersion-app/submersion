import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';

import '../../../helpers/test_database.dart';

/// Documents sync (issue #2613): both tables export on their own clocks,
/// pages carry their bytes as base64, and large pending pages count toward
/// the changeset writer's oversized-delta guard.
Document _doc() => Document(
  id: '',
  diverId: 'd1',
  owner: const DocumentOwner.personal(),
  type: DocumentType.insurance,
  issuer: 'DAN',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

DocumentPage _page(int size) => DocumentPage(
  id: '',
  documentId: '',
  pageIndex: 0,
  fileName: 'a.pdf',
  mimeType: 'application/pdf',
  sizeBytes: size,
  bytes: Uint8List.fromList(List.generate(size, (i) => i % 251)),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement(
      'INSERT INTO divers (id, name, created_at, updated_at) '
      "VALUES ('d1', 'Ana', 0, 0)",
    );
  });
  tearDown(tearDownTestDatabase);

  test('saving stamps both rows with a clock', () async {
    final doc = await DocumentRepository().save(_doc(), [_page(3)]);
    final rows = await db
        .customSelect(
          'SELECT hlc FROM documents WHERE id = ? UNION ALL '
          'SELECT hlc FROM document_pages WHERE document_id = ?',
          variables: [Variable.withString(doc.id), Variable.withString(doc.id)],
        )
        .get();
    expect(rows, hasLength(2));
    for (final r in rows) {
      expect(r.readNullable<String>('hlc'), isNotNull);
    }
  });

  test('a changeset carries the document and its page bytes', () async {
    await DocumentRepository().save(_doc(), [_page(3)]);
    final payload = await SyncDataSerializer().exportChangeset(
      deviceId: 'dev',
      hlcWatermark: null,
      deletions: const [],
    );
    expect(payload.data.documents.single['issuer'], 'DAN');
    expect(payload.data.documentPages.single['bytes'], isA<String>());
  });

  test('fetch, delete and upsert round-trips a page with its bytes', () async {
    final repo = DocumentRepository();
    final doc = await repo.save(_doc(), [_page(3)]);
    final pageId = (await repo.getPages(doc.id)).single.id;
    final serializer = SyncDataSerializer();
    final docRecord = await serializer.fetchRecord('documents', doc.id);
    final pageRecord = await serializer.fetchRecord('documentPages', pageId);
    final batch = await serializer.fetchRecords('documentPages', [pageId]);
    expect(batch[pageId]!['bytes'], pageRecord!['bytes']);

    await serializer.deleteRecord('documentPages', pageId);
    await serializer.deleteRecord('documents', doc.id);
    expect(await repo.getById(doc.id), isNull);

    await serializer.upsertRecord('documents', docRecord!);
    await serializer.upsertRecords('documentPages', [pageRecord]);
    expect((await repo.getPages(doc.id)).single.bytes, [0, 1, 2]);
  });

  test('pending page bytes count toward the oversized-delta guard', () async {
    final serializer = SyncDataSerializer();
    final before = await serializer.pendingSeriesBlobBytes(null);
    await DocumentRepository().save(_doc(), [_page(1000)]);
    expect(await serializer.pendingSeriesBlobBytes(null), before + 1000);
  });
}
