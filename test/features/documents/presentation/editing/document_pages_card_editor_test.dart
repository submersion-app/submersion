import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/presentation/providers/document_providers.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/shared/utils/byte_format.dart';
import 'package:submersion/core/services/images/profile_photo_codec.dart';
import 'package:submersion/features/documents/data/services/document_page_capture.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/document_file_gate.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';
import 'package:submersion/features/documents/presentation/editing/document_edit_fields.dart';
import 'package:submersion/features/documents/presentation/editing/document_pages_card_editor.dart';
import 'package:submersion/features/documents/presentation/editing/document_record.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../document_repository_doubles.dart';

DocumentPageCapture captureOne() => DocumentPageCapture(
  pickFile: (_) async => (bytes: Uint8List.fromList([1, 2]), name: 'scan.png'),
  pickImage: (_) async => (bytes: Uint8List(4), name: 'shot.jpg'),
  encode: (p) async =>
      (outcome: ImageEncodeOutcome.encoded, bytes: Uint8List.fromList([9])),
);

DocumentPage _page(int index) => DocumentPage(
  id: 'pg$index',
  documentId: 'doc',
  pageIndex: index,
  fileName: 'p$index.jpg',
  mimeType: 'image/jpeg',
  sizeBytes: 2,
  bytes: Uint8List.fromList([index, 1]),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

/// The Pages card's editor holds a document's pages in its sitting until
/// Save (issue #4527, phase 3).
void main() {
  final l = AppLocalizationsEn();
  late EditSession<DocumentRecord> session;

  setUp(() {
    session = EditSession(
      DocumentRecord(
        document: Document(
          id: 'doc',
          diverId: 'd1',
          owner: const DocumentOwner.personal(),
          type: DocumentType.permit,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
        pages: [_page(0)],
        tagIds: const [],
      ),
    );
  });
  tearDown(() => session.dispose());

  Future<void> pump(
    WidgetTester tester, {
    DocumentPageCapture? capture,
    DocumentRepository? repository,
  }) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        documentPageCaptureProvider.overrideWithValue(capture ?? captureOne()),
        if (repository != null)
          documentRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: DocumentPagesCardEditor(session: session)),
      ),
    ),
  );

  testWidgets('adding a page is a change of Pages', (tester) async {
    await pump(tester);

    await tester.tap(find.text(l.documents_pages_add));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.documents_pages_addFile));
    await tester.pumpAndSettle();

    expect(session.valueOf(documentPagesField), hasLength(2));
    expect(session.changedCardIds, {'pages'});
  });

  testWidgets('removing a page is a change, and nothing is written', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.byTooltip(l.documents_pages_remove).first);
    await tester.pumpAndSettle();

    expect(session.valueOf(documentPagesField), isEmpty);
    expect(session.changedCardIds, {'pages'});
  });

  /// Opens the add sheet from [slot] (a slot's label or Add) and takes a
  /// file.
  Future<void> addFile(WidgetTester tester, String slot) async {
    await tester.tap(find.text(slot));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.documents_pages_addFile));
    await tester.pumpAndSettle();
  }

  testWidgets('an insurance and a certification card have Front and Back '
      'slots; a permit has none', (tester) async {
    await pump(tester);
    expect(find.text(l.documents_pages_front), findsNothing);
    expect(find.text(l.documents_pages_back), findsNothing);

    for (final type in [
      DocumentType.insurance,
      DocumentType.certificationCard,
    ]) {
      session.set(documentTypeField, type);
      await tester.pumpAndSettle();
      expect(
        find.text(l.documents_pages_front),
        findsOneWidget,
        reason: '$type',
      );
      expect(
        find.text(l.documents_pages_back),
        findsOneWidget,
        reason: '$type',
      );
    }
  });

  testWidgets('card faces are kept Front then Back, whatever order they are '
      'added in', (tester) async {
    session.set(documentTypeField, DocumentType.insurance);
    await pump(tester);

    await addFile(tester, l.documents_pages_back);
    await addFile(tester, l.documents_pages_front);

    expect(
      [for (final p in session.valueOf(documentPagesField)) p.side],
      [DocumentPageSide.front, DocumentPageSide.back, null],
    );
  });

  testWidgets('a file over the limit says so and adds nothing', (tester) async {
    await pump(
      tester,
      capture: DocumentPageCapture(
        pickFile: (_) async =>
            (bytes: Uint8List(kMaxDocumentPageBytes + 1), name: 'big.pdf'),
        pickImage: (_) async => null,
        encode: (p) async => (outcome: ImageEncodeOutcome.encoded, bytes: null),
      ),
    );

    await addFile(tester, l.documents_pages_add);

    expect(find.byType(SnackBar), findsOneWidget);
    expect(
      find.text(
        l.documents_pages_tooLarge(formatBytes(kMaxDocumentPageBytes + 1)),
      ),
      findsOneWidget,
    );
    expect(session.isDirty, isFalse);
  });

  testWidgets('an unsupported file names its type and adds nothing', (
    tester,
  ) async {
    await pump(
      tester,
      capture: DocumentPageCapture(
        pickFile: (_) async =>
            (bytes: Uint8List.fromList([1]), name: 'route.gpx'),
        pickImage: (_) async => null,
        encode: (p) async => (outcome: ImageEncodeOutcome.encoded, bytes: null),
      ),
    );

    await addFile(tester, l.documents_pages_add);

    expect(find.text(l.documents_pages_unsupported('gpx')), findsOneWidget);
    expect(session.isDirty, isFalse);
  });

  // The strip builds lazily: a long document reads the content of the
  // pages it shows, not all of them, and never a PDF's.
  testWidgets('a long document reads only the pages the strip builds', (
    tester,
  ) async {
    final pages = [
      for (var i = 0; i < 40; i++)
        DocumentPage(
          id: 'pg$i',
          documentId: 'doc',
          pageIndex: i,
          fileName: 'p$i.jpg',
          mimeType: 'image/jpeg',
          sizeBytes: 2,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      DocumentPage(
        id: 'pg40',
        documentId: 'doc',
        pageIndex: 40,
        fileName: 'policy.pdf',
        mimeType: 'application/pdf',
        sizeBytes: 2,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    ];
    session.set(documentPagesField, pages);
    final content = FakeDocumentContent();
    await pump(tester, repository: content);
    await tester.pumpAndSettle();

    expect(content.reads, isNotEmpty);
    expect(content.reads.length, lessThan(20));
    expect(content.reads, isNot(contains('pg40')));
  });

  test('reordering back is no change', () {
    final second = _page(1);
    session.set(documentPagesField, [_page(0), second]);
    session.set(documentPagesField, [second, _page(0)]);
    session.set(documentPagesField, [_page(0)]);

    expect(session.isDirty, isFalse);
  });
}
