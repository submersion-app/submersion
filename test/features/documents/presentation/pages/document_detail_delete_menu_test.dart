import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/pages/document_detail_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Delete sits in the overflow menu, not one tap away beside Edit
/// (issue #3384).
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
        type: DocumentType.insurance,
        title: 'Dive cover',
        issuer: 'DAN',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      const [],
    )).id;
  });
  tearDown(tearDownTestDatabase);

  Future<void> pumpDetail(WidgetTester t) async {
    t.view.physicalSize = const Size(420, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final overrides = await getBaseOverrides();
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

  Finder appBarFinder(Finder matching) =>
      find.descendant(of: find.byType(AppBar), matching: matching);

  testWidgets('the app bar keeps Edit but no standalone Delete', (t) async {
    await pumpDetail(t);
    expect(appBarFinder(find.byIcon(Icons.edit_outlined)), findsOneWidget);
    expect(appBarFinder(find.byIcon(Icons.delete_outline)), findsNothing);
    expect(appBarFinder(find.byTooltip('Delete')), findsNothing);
    expect(appBarFinder(find.byType(PopupMenuButton<String>)), findsOneWidget);
  });

  testWidgets('the overflow menu offers Delete', (t) async {
    await pumpDetail(t);
    await t.tap(appBarFinder(find.byType(PopupMenuButton<String>)));
    await t.pumpAndSettle();
    expect(find.widgetWithText(PopupMenuItem<String>, 'Delete'), findsOne);
  });

  testWidgets('cancelling the confirmation keeps the document', (t) async {
    await pumpDetail(t);
    await t.tap(appBarFinder(find.byType(PopupMenuButton<String>)));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(PopupMenuItem<String>, 'Delete'));
    await t.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await t.tap(find.widgetWithText(TextButton, 'Cancel'));
    await t.pumpAndSettle();
    expect(find.byType(DocumentDetailPage), findsOneWidget);
    expect(await DocumentRepository().getById(docId), isNotNull);
  });

  testWidgets('confirming deletes the document and leaves the page', (t) async {
    await pumpDetail(t);
    await t.tap(appBarFinder(find.byType(PopupMenuButton<String>)));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(PopupMenuItem<String>, 'Delete'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Delete'));
    await t.pumpAndSettle();
    expect(find.byType(DocumentDetailPage), findsNothing);
    expect(find.text('open'), findsOneWidget);
    expect(await DocumentRepository().getById(docId), isNull);
  });
}
