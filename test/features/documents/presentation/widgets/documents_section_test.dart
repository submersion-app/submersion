import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/providers/document_providers.dart';
import 'package:submersion/features/documents/presentation/widgets/document_tile.dart';
import 'package:submersion/features/documents/presentation/widgets/documents_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Document _doc(String id, DocumentType type) => Document(
  id: id,
  diverId: 'd1',
  owner: const DocumentOwner(DocumentOwnerKind.trip, 't1'),
  type: type,
  title: 'Doc $id',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  Uri? pushed;

  Future<void> pump(
    WidgetTester t,
    DocumentOwner owner,
    List<Document> docs, {
    bool excludeCards = false,
  }) async {
    pushed = null;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: SingleChildScrollView(
              child: DocumentsSection(owner: owner, excludeCards: excludeCards),
            ),
          ),
        ),
        GoRoute(
          path: '/documents/new',
          builder: (context, state) {
            pushed = state.uri;
            return const Scaffold(body: Text('NEW'));
          },
        ),
        GoRoute(
          path: '/documents/:id',
          builder: (context, state) {
            pushed = state.uri;
            return const Scaffold(body: Text('DETAIL'));
          },
        ),
      ],
    );
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          documentsForOwnerProvider(owner).overrideWith((ref) async => docs),
          documentFirstPageProvider.overrideWith((ref, id) async => null),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  const trip = DocumentOwner(DocumentOwnerKind.trip, 't1');

  testWidgets('lists the owner\'s documents; Add opens the editor with the '
      'owner filled in', (t) async {
    await pump(t, trip, [
      _doc('a', DocumentType.permit),
      _doc('b', DocumentType.booking),
    ]);
    expect(find.text('Documents'), findsOneWidget);
    expect(find.byType(DocumentTile), findsNWidgets(2));
    await t.tap(find.text('Add document'));
    await t.pumpAndSettle();
    expect(pushed, Uri.parse('/documents/new?ownerKind=trip&ownerId=t1'));
  });

  testWidgets('a tile opens the document', (t) async {
    await pump(t, trip, [_doc('a', DocumentType.permit)]);
    await t.tap(find.text('Doc a'));
    await t.pumpAndSettle();
    expect(pushed?.path, '/documents/a');
  });

  testWidgets('the certification section hides the card document', (t) async {
    const cert = DocumentOwner(DocumentOwnerKind.certification, 'c1');
    await pump(t, cert, [
      _doc('card', DocumentType.certificationCard),
      _doc('pdf', DocumentType.other),
    ], excludeCards: true);
    expect(find.byType(DocumentTile), findsOneWidget);
    expect(find.text('Doc pdf'), findsOneWidget);
  });

  testWidgets('an owner without documents says so', (t) async {
    await pump(t, trip, const []);
    expect(find.text('No documents attached'), findsOneWidget);
  });
}
