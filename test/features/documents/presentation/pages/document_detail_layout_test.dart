import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';
import 'package:submersion/features/documents/presentation/pages/document_detail_page.dart';
import 'package:submersion/features/documents/presentation/widgets/document_details_panel.dart';
import 'package:submersion/features/documents/presentation/widgets/document_page_viewer.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// The pages fill the detail page and the details stay out of their way
/// (issue #3333): a PDF boxed into a short preview could not be read.
void main() {
  late String docId;

  setUp(() async {
    final db = await setUpTestDatabase();
    await db.customStatement(
      'INSERT INTO divers (id, name, is_default, created_at, updated_at) '
      "VALUES ('d1', 'Ana', 1, 0, 0)",
    );
    docId = (await DocumentRepository().save(
      Document(
        id: '',
        diverId: 'd1',
        owner: const DocumentOwner.personal(),
        type: DocumentType.permit,
        title: 'Marine park',
        issuer: 'STINAPA',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      [
        DocumentPage(
          id: '',
          documentId: '',
          pageIndex: 0,
          fileName: 'permit.txt',
          mimeType: 'text/plain',
          sizeBytes: 1,
          bytes: Uint8List.fromList([1]),
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ],
    )).id;
  });
  tearDown(tearDownTestDatabase);

  Future<void> pumpDetail(WidgetTester t, Size size) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final overrides = await getBaseOverrides();
    // Pushed, as from an owner page or the list on a phone, so the page
    // stays a page instead of redirecting into the list's pane.
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/documents/$docId'),
              child: const Text('open'),
            ),
          ),
        ),
        GoRoute(
          path: '/documents/:id',
          builder: (_, state) =>
              DocumentDetailPage(documentId: state.pathParameters['id']!),
        ),
      ],
    );
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
        ].cast(),
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
  }

  testWidgets('the pages take the height the details do not need', (t) async {
    await pumpDetail(t, const Size(420, 900));
    expect(t.getSize(find.byType(DocumentPageViewer)).height, greaterThan(600));
  });

  testWidgets('details start collapsed and expand', (t) async {
    await pumpDetail(t, const Size(420, 900));
    expect(find.text('STINAPA'), findsNothing);
    await t.tap(find.byKey(const ValueKey('document-details-toggle')));
    await t.pumpAndSettle();
    expect(find.text('STINAPA'), findsOneWidget);
  });

  testWidgets('a short landscape screen keeps half for the pages', (t) async {
    await pumpDetail(t, const Size(800, 400));
    await t.tap(find.byKey(const ValueKey('document-details-toggle')));
    await t.pumpAndSettle();
    const body = 400 - kToolbarHeight;
    expect(
      t.getSize(find.byType(DocumentPageViewer)).height,
      greaterThanOrEqualTo(body / 2 - 1),
    );
  });

  testWidgets('a document with no pages shows its details at once', (t) async {
    docId = (await DocumentRepository().save(
      Document(
        id: '',
        diverId: 'd1',
        owner: const DocumentOwner.personal(),
        type: DocumentType.insurance,
        issuer: 'DAN',
        emergencyPhone: '+1 555 0100',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      const [],
    )).id;
    await pumpDetail(t, const Size(420, 900));
    expect(find.text('+1 555 0100'), findsOneWidget);
    expect(find.byKey(const ValueKey('document-details-toggle')), findsNothing);
    expect(find.byType(DocumentPageViewer), findsNothing);
  });

  testWidgets('a pageless document stays readable on a wide screen', (t) async {
    docId = (await DocumentRepository().save(
      Document(
        id: '',
        diverId: 'd1',
        owner: const DocumentOwner.personal(),
        type: DocumentType.insurance,
        issuer: 'DAN',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      const [],
    )).id;
    await pumpDetail(t, const Size(1400, 900));
    expect(
      t.getSize(find.byType(DocumentDetailsCard)).width,
      lessThanOrEqualTo(720),
    );
  });

  testWidgets('wide screens put the details beside the pages', (t) async {
    await pumpDetail(t, const Size(1200, 800));
    final viewer = t.getRect(find.byType(DocumentPageViewer));
    final card = t.getRect(find.byType(DocumentDetailsCard));
    expect(card.left, greaterThanOrEqualTo(viewer.right));
    expect(find.text('STINAPA'), findsOneWidget);
    expect(find.byKey(const ValueKey('document-details-toggle')), findsNothing);
  });
}
