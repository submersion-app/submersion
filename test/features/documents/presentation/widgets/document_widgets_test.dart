import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/documents/domain/document_expiry.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';
import 'package:submersion/features/documents/presentation/widgets/document_expiry_badge.dart';
import 'package:submersion/features/documents/presentation/widgets/document_form_fields.dart';
import 'package:submersion/features/documents/presentation/widgets/document_page_viewer.dart';
import 'package:submersion/features/documents/presentation/widgets/document_tile.dart';

import '../../../../helpers/test_app.dart';

DocumentPage _page({
  String id = 'p1',
  String fileName = 'policy.docx',
  String mimeType =
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  List<int> bytes = const [1, 2, 3],
}) => DocumentPage(
  id: id,
  documentId: 'x',
  pageIndex: 0,
  fileName: fileName,
  mimeType: mimeType,
  sizeBytes: bytes.length,
  bytes: Uint8List.fromList(bytes),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  testWidgets('badge shows expired and due soon, nothing when ok', (t) async {
    await t.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: const Column(
          children: [
            DocumentExpiryBadge(
              status: DocumentExpiryStatus(DocumentExpiryKind.expired, -3),
            ),
            DocumentExpiryBadge(
              status: DocumentExpiryStatus(DocumentExpiryKind.dueSoon, 5),
            ),
            DocumentExpiryBadge(
              status: DocumentExpiryStatus(DocumentExpiryKind.dueSoon, 0),
            ),
            DocumentExpiryBadge(
              status: DocumentExpiryStatus(DocumentExpiryKind.ok, 90),
            ),
          ],
        ),
      ),
    );
    expect(find.text('Expired'), findsOneWidget);
    expect(find.text('Expires in 5 days'), findsOneWidget);
    expect(find.text('Expires today'), findsOneWidget);
    expect(find.textContaining('90'), findsNothing);
  });

  testWidgets('tile shows the type name for an empty title, owner and issuer', (
    t,
  ) async {
    var tapped = false;
    await t.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: DocumentTile(
          document: Document(
            id: 'x',
            diverId: 'd',
            owner: const DocumentOwner(DocumentOwnerKind.trip, 't1'),
            type: DocumentType.medicalClearance,
            issuer: 'Dr Lee',
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
          ownerLabel: 'Bonaire',
          thumbnail: const SizedBox(),
          onTap: () => tapped = true,
        ),
      ),
    );
    expect(find.text('Medical clearance'), findsOneWidget);
    expect(find.textContaining('Bonaire'), findsOneWidget);
    expect(find.textContaining('Dr Lee'), findsOneWidget);
    await t.tap(find.byType(DocumentTile));
    expect(tapped, isTrue);
  });

  testWidgets('a card tile names its certification once', (t) async {
    await t.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: DocumentTile(
          document: Document(
            id: 'x',
            diverId: 'd',
            owner: const DocumentOwner(DocumentOwnerKind.certification, 'c1'),
            type: DocumentType.certificationCard,
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
          ownerLabel: 'Advanced Nitrox',
          thumbnail: const SizedBox(),
        ),
      ),
    );
    expect(find.text('Advanced Nitrox'), findsOneWidget);
    expect(find.text('Certification card'), findsNothing);
  });

  testWidgets('a card document has no Title field', (t) async {
    final controllers = DocumentFormControllers();
    addTearDown(controllers.dispose);
    Widget form(DocumentType type) => testApp(
      locale: const Locale('en'),
      child: SingleChildScrollView(
        child: DocumentFormFields(
          type: type,
          typeChoices: [type],
          controllers: controllers,
          issueDate: null,
          expiryDate: null,
          reminderLeadDays: 30,
          isPrimary: false,
          formatDate: (d) => '$d',
          onTypeChanged: (_) {},
          onPickIssueDate: () {},
          onPickExpiryDate: () {},
          onClearIssueDate: () {},
          onClearExpiryDate: () {},
          onLeadChanged: (_) {},
          onPrimaryChanged: (_) {},
        ),
      ),
    );
    await t.pumpWidget(form(DocumentType.certificationCard));
    expect(find.byKey(const Key('document-title')), findsNothing);
    await t.pumpWidget(form(DocumentType.permit));
    expect(find.byKey(const Key('document-title')), findsOneWidget);
  });

  testWidgets('viewer shows a Word page as a file tile with Open with', (
    t,
  ) async {
    await t.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: DocumentPageViewer(pages: [_page()]),
      ),
    );
    expect(find.text('policy.docx'), findsOneWidget);
    expect(find.text('Open with...'), findsOneWidget);
  });

  testWidgets('viewer counts pages when there is more than one', (t) async {
    await t.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: DocumentPageViewer(
          pages: [
            _page(),
            _page(id: 'p2', fileName: 'b.txt', mimeType: 'text/plain'),
          ],
        ),
      ),
    );
    expect(find.text('1 of 2'), findsOneWidget);
  });

  testWidgets('viewer stays on a real page when the page list shrinks', (
    t,
  ) async {
    Widget viewer(int count) => testApp(
      locale: const Locale('en'),
      child: DocumentPageViewer(
        pages: [
          for (var i = 0; i < count; i++)
            _page(id: 'p$i', fileName: 'p$i.txt', mimeType: 'text/plain'),
        ],
      ),
    );
    await t.pumpWidget(viewer(3));
    final pageView = find.byType(PageView);
    for (var i = 0; i < 2; i++) {
      await t.fling(pageView, const Offset(-600, 0), 2000);
      await t.pumpAndSettle();
    }
    expect(find.text('3 of 3'), findsOneWidget);

    // An edit removed a page while the detail page stayed open.
    await t.pumpWidget(viewer(2));
    await t.pumpAndSettle();
    expect(find.text('2 of 2'), findsOneWidget);
    expect(find.text('p1.txt'), findsOneWidget);
  });

  testWidgets('viewer shows a placeholder for a corrupt image', (t) async {
    await t.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: DocumentPageViewer(
          pages: [
            _page(
              fileName: 'front.jpg',
              mimeType: 'image/jpeg',
              bytes: const [0, 1],
            ),
          ],
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text("Can't display this page"), findsOneWidget);
  });
}
