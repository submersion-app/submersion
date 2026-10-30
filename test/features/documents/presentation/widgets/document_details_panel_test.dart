import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/widgets/document_details_panel.dart';
import 'package:submersion/features/documents/presentation/widgets/document_expiry_badge.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_view.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// The details shown under (or beside) a document's pages (issue #3333).
void main() {
  final now = DateTime.now();

  Document insurance({DateTime? expiry}) => Document(
    id: 'x',
    diverId: 'd1',
    owner: const DocumentOwner.personal(),
    type: DocumentType.insurance,
    title: 'DAN Europe',
    issuer: 'DAN',
    referenceNumber: 'P-123',
    issueDate: DateTime(2026, 1, 1),
    expiryDate: expiry,
    emergencyPhone: '+1 555 0100',
    phone: '+1 555 0199',
    isPrimary: true,
    notes: 'Covers chamber treatment',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Future<void> pump(WidgetTester t, Widget child) async {
    t.view.physicalSize = const Size(500, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: await getBaseOverrides(),
        child: SingleChildScrollView(child: child),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('an insurance card shows its insurer, policy and phones', (
    t,
  ) async {
    await pump(t, DocumentDetailsCard(document: insurance(), ownerLabel: null));
    expect(find.text('Insurer'), findsOneWidget);
    expect(find.text('DAN'), findsOneWidget);
    expect(find.text('Policy number'), findsOneWidget);
    expect(find.text('P-123'), findsOneWidget);
    expect(find.text('Issued'), findsOneWidget);
    expect(find.text('24-hour emergency line'), findsOneWidget);
    expect(find.text('+1 555 0100'), findsOneWidget);
    expect(find.text('Office phone'), findsOneWidget);
    expect(find.text('Primary insurance'), findsOneWidget);
    expect(find.text('Covers chamber treatment'), findsOneWidget);
    // Personal: the owner row names the kind.
    expect(find.text('Personal'), findsOneWidget);
    expect(find.byType(Card), findsOneWidget);
  });

  testWidgets('notes draw as Markdown (#3683)', (t) async {
    final doc = insurance().copyWith(notes: '**Covers** chamber treatment');
    await pump(t, DocumentDetailsCard(document: doc, ownerLabel: null));
    expect(find.byType(MarkdownNotesView), findsOneWidget);
    expect(find.text('Covers chamber treatment'), findsOneWidget);
  });

  testWidgets('flat, the card adds no card of its own', (t) async {
    await pump(
      t,
      DocumentDetailsCard(document: insurance(), ownerLabel: null, flat: true),
    );
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('a permit shows no insurance rows', (t) async {
    await pump(
      t,
      DocumentDetailsCard(
        document: insurance().copyWith(type: DocumentType.permit),
        ownerLabel: null,
      ),
    );
    expect(find.text('24-hour emergency line'), findsNothing);
    expect(find.text('Primary insurance'), findsNothing);
    expect(find.text('Insurer'), findsNothing);
  });

  testWidgets('the folded panel flags a document that needs attention', (
    t,
  ) async {
    final expiring = insurance(
      expiry: DateTime(now.year, now.month, now.day + 5),
    );
    await pump(
      t,
      DocumentDetailsPanel(entry: DocumentListEntry(expiring, null, 1)),
    );
    // Folded: the summary and the expiry badge, not the rows.
    expect(find.byType(DocumentExpiryBadge), findsOneWidget);
    expect(find.text('24-hour emergency line'), findsNothing);
    await t.tap(find.byKey(const ValueKey('document-details-toggle')));
    await t.pumpAndSettle();
    expect(find.text('24-hour emergency line'), findsOneWidget);
    // The expiry row carries its own badge too.
    expect(find.byType(DocumentExpiryBadge), findsNWidgets(2));
  });
}
