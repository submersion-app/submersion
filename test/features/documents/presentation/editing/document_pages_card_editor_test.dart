import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/images/profile_photo_codec.dart';
import 'package:submersion/features/documents/data/services/document_page_capture.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';
import 'package:submersion/features/documents/presentation/editing/document_edit_fields.dart';
import 'package:submersion/features/documents/presentation/editing/document_pages_card_editor.dart';
import 'package:submersion/features/documents/presentation/editing/document_record.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

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

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    ProviderScope(
      overrides: [documentPageCaptureProvider.overrideWithValue(captureOne())],
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

  test('reordering back is no change', () {
    final second = _page(1);
    session.set(documentPagesField, [_page(0), second]);
    session.set(documentPagesField, [second, _page(0)]);
    session.set(documentPagesField, [_page(0)]);

    expect(session.isDirty, isFalse);
  });
}
