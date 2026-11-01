import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';
import 'package:submersion/features/documents/presentation/providers/document_providers.dart';
import 'package:submersion/features/documents/presentation/widgets/document_page_thumbnail.dart';

import '../../../../helpers/test_app.dart';

class _RecordingRepository extends DocumentRepository {
  _RecordingRepository() : super(cancelReminders: (_) async {});

  final reads = <String>[];

  @override
  Future<Uint8List?> getPageContent(String pageId) async {
    reads.add(pageId);
    return Uint8List.fromList([0, 1]);
  }
}

void main() {
  final document = Document(
    id: 'x',
    diverId: 'd1',
    owner: const DocumentOwner.personal(),
    type: DocumentType.permit,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  DocumentPage page(String mimeType) => DocumentPage(
    id: 'p0',
    documentId: 'x',
    pageIndex: 0,
    fileName: 'first',
    mimeType: mimeType,
    sizeBytes: 2,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Future<_RecordingRepository> pump(WidgetTester t, DocumentPage? first) async {
    final repo = _RecordingRepository();
    await t.pumpWidget(
      testApp(
        overrides: [
          documentRepositoryProvider.overrideWithValue(repo),
          documentFirstPageProvider.overrideWith((ref, id) async => first),
        ],
        child: DocumentPageThumbnail(document: document),
      ),
    );
    await t.pump();
    await t.pump();
    return repo;
  }

  testWidgets('an image first page reads its content and shows it', (t) async {
    final repo = await pump(t, page('image/jpeg'));
    expect(repo.reads, ['p0']);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('a PDF first page shows its icon and reads nothing', (t) async {
    final repo = await pump(t, page('application/pdf'));
    expect(repo.reads, isEmpty);
    expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
  });

  testWidgets('a document without pages shows its type icon', (t) async {
    final repo = await pump(t, null);
    expect(repo.reads, isEmpty);
    expect(find.byType(Image), findsNothing);
  });
}
