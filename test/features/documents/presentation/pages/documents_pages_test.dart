import 'package:drift/drift.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/documents/presentation/pages/document_edit_routes.dart';
import 'package:submersion/features/query/presentation/providers/entity_search_providers.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';
import 'package:submersion/features/documents/presentation/pages/document_detail_page.dart';
import 'package:submersion/features/documents/presentation/pages/documents_page.dart';
import 'package:submersion/features/documents/presentation/widgets/documents_expiring_strip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/plain_header_title.dart';
import '../../../../helpers/test_database.dart';

Future<Document> _save(
  String title,
  DocumentType type, {
  DocumentOwner owner = const DocumentOwner.personal(),
  DateTime? expiry,
  String? issuer,
}) => DocumentRepository().save(
  Document(
    id: '',
    diverId: 'd1',
    owner: owner,
    type: type,
    title: title,
    issuer: issuer,
    expiryDate: expiry,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ),
  [
    DocumentPage(
      id: '',
      documentId: '',
      pageIndex: 0,
      fileName: '$title.txt',
      mimeType: 'text/plain',
      sizeBytes: 1,
      bytes: Uint8List.fromList([1]),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  ],
);

void main() {
  final now = DateTime.now();
  DateTime day(int offset) => DateTime(now.year, now.month, now.day + offset);

  setUp(() async {
    final db = await setUpTestDatabase();
    await db.customStatement(
      'INSERT INTO divers (id, name, is_default, created_at, updated_at) '
      "VALUES ('d1', 'Ana', 1, 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO trips (id, diver_id, name, start_date, end_date, '
      "created_at, updated_at) VALUES ('t1', 'd1', 'Bonaire', 0, 0, 0, 0)",
    );
  });
  tearDown(tearDownTestDatabase);

  Future<void> pump(WidgetTester t, String location, {Size? size}) async {
    t.view.physicalSize = size ?? const Size(420, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final overrides = await getBaseOverrides();
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/documents',
          builder: (context, state) => DocumentsPage(
            initialType: DocumentType.values
                .asNameMap()[state.uri.queryParameters['type']],
            initialPersonalOnly:
                state.uri.queryParameters['owner'] == 'personal',
            headerTitle: plainHeaderTitle('Documents'),
          ),
          routes: [
            GoRoute(
              path: 'new',
              builder: (context, state) =>
                  Scaffold(body: Text('NEW ${state.uri.query}')),
            ),
            GoRoute(
              path: ':id',
              builder: (context, state) =>
                  DocumentDetailPage(documentId: state.pathParameters['id']!),
              routes: [
                GoRoute(
                  path: 'edit',
                  builder: (context, state) =>
                      const Scaffold(body: Text('EDIT')),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/trips/:id',
          builder: (context, state) =>
              Scaffold(body: Text('TRIP ${state.pathParameters['id']}')),
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
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('the list groups by owner with a Needs attention strip', (
    t,
  ) async {
    await _save('DAN', DocumentType.insurance, issuer: 'DAN Europe');
    await _save('Clearance', DocumentType.medicalClearance, expiry: day(-3));
    await _save(
      'Park permit',
      DocumentType.permit,
      owner: const DocumentOwner(DocumentOwnerKind.trip, 't1'),
      expiry: day(5),
    );
    await pump(t, '/documents');
    expect(find.text('Needs attention'), findsOneWidget);
    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('Trips'), findsOneWidget);
    expect(find.textContaining('Bonaire'), findsWidgets);
  });

  testWidgets('a clearance a later one supersedes needs no attention '
      '(#4541)', (t) async {
    await _save(
      'Old clearance',
      DocumentType.medicalClearance,
      expiry: day(-400),
    );
    await _save(
      'New clearance',
      DocumentType.medicalClearance,
      expiry: day(300),
    );
    await pump(t, '/documents');
    expect(find.text('Old clearance'), findsOneWidget);
    expect(find.text('Needs attention'), findsNothing);
  });

  test('due leaves out a clearance superseded among all entries, even one '
      'a filter hides', () async {
    DocumentListEntry entry(String id, DateTime expiry) => DocumentListEntry(
      Document(
        id: id,
        diverId: 'd1',
        owner: const DocumentOwner.personal(),
        type: DocumentType.medicalClearance,
        expiryDate: expiry,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      null,
      0,
    );
    final old = entry('old', day(-400));
    final renewal = entry('new', day(300));
    expect(DocumentsExpiringStrip.due([old], now), hasLength(1));
    expect(
      DocumentsExpiringStrip.due([old], now, among: [old, renewal]),
      isEmpty,
    );
  });

  testWidgets('a search that hides the renewal does not bring the old '
      'clearance back into Needs attention', (t) async {
    await _save(
      'Old clearance',
      DocumentType.medicalClearance,
      expiry: day(-400),
    );
    await _save(
      'New clearance',
      DocumentType.medicalClearance,
      expiry: day(300),
    );
    await pump(t, '/documents');
    await t.enterText(find.byType(TextField), 'old');
    await t.pumpAndSettle();
    expect(find.text('Old clearance'), findsOneWidget);
    expect(find.text('New clearance'), findsNothing);
    expect(find.text('Needs attention'), findsNothing);
  });

  testWidgets('search matches title, issuer and number', (t) async {
    await _save('DAN', DocumentType.insurance, issuer: 'DAN Europe');
    await _save('Clearance', DocumentType.medicalClearance);
    await pump(t, '/documents');
    await t.enterText(find.byType(TextField), 'europe');
    await t.pumpAndSettle();
    expect(find.text('DAN'), findsOneWidget);
    expect(find.text('Clearance'), findsNothing);
  });

  testWidgets('a dive owner is listed and found by its site and date '
      '(#3391)', (t) async {
    final db = DatabaseService.instance.database;
    await db.customStatement(
      'INSERT INTO dive_sites (id, diver_id, name, created_at, updated_at) '
      "VALUES ('s1', 'd1', 'Blue Hole', 0, 0)",
    );
    final when = DateTime.utc(2026, 10, 12, 9).millisecondsSinceEpoch;
    await db.customStatement(
      'INSERT INTO dives (id, diver_id, dive_number, dive_date_time, site_id, '
      "created_at, updated_at) VALUES ('v1', 'd1', 142, $when, 's1', 0, 0)",
    );
    await _save(
      'Log sheet',
      DocumentType.other,
      owner: const DocumentOwner(DocumentOwnerKind.dive, 'v1'),
    );
    await _save('DAN', DocumentType.insurance);
    await pump(t, '/documents');
    expect(
      find.textContaining(RegExp(r'^#142 · Blue Hole · .*2026')),
      findsOneWidget,
    );
    await t.enterText(find.byType(TextField), 'blue hole');
    await t.pumpAndSettle();
    expect(find.text('Log sheet'), findsOneWidget);
    expect(find.text('DAN'), findsNothing);
    await t.enterText(find.byType(TextField), '2026');
    await t.pumpAndSettle();
    expect(find.text('Log sheet'), findsOneWidget);
    expect(find.text('DAN'), findsNothing);
  });

  testWidgets('a type from the route shows only that type', (t) async {
    await _save('DAN', DocumentType.insurance);
    await _save('Clearance', DocumentType.medicalClearance);
    await pump(t, '/documents?type=insurance');
    expect(find.text('DAN'), findsOneWidget);
    expect(find.text('Clearance'), findsNothing);
  });

  testWidgets('adding from a filtered list keeps the filter\'s type', (
    t,
  ) async {
    await pump(t, '/documents?type=insurance');
    await t.tap(find.byType(FloatingActionButton));
    await t.pumpAndSettle();
    expect(find.text('NEW type=insurance'), findsOneWidget);
  });

  testWidgets('the personal filter from the hub is shown and can be cleared', (
    t,
  ) async {
    await _save('Clearance', DocumentType.medicalClearance);
    await _save(
      'Park permit',
      DocumentType.permit,
      owner: const DocumentOwner(DocumentOwnerKind.trip, 't1'),
    );
    await pump(t, '/documents?owner=personal');
    expect(find.text('Park permit'), findsNothing);
    final chip = find.byKey(const ValueKey('documents-filter-personal'));
    expect(chip, findsOneWidget);
    t.widget<InputChip>(chip).onDeleted!();
    await t.pumpAndSettle();
    expect(find.text('Park permit'), findsOneWidget);
  });

  testWidgets('an empty library says so', (t) async {
    await pump(t, '/documents');
    expect(find.text('No documents yet'), findsOneWidget);
  });

  testWidgets('detail shows metadata and the owner, and deletes on confirm', (
    t,
  ) async {
    final doc = await _save(
      'Park permit',
      DocumentType.permit,
      owner: const DocumentOwner(DocumentOwnerKind.trip, 't1'),
      issuer: 'Marine Park',
    );
    await pump(t, '/documents/${doc.id}');
    // On a phone the details start folded under the pages.
    await t.tap(find.byKey(const ValueKey('document-details-toggle')));
    await t.pumpAndSettle();
    expect(find.text('Park permit'), findsWidgets);
    expect(find.text('Marine Park'), findsOneWidget);
    expect(find.text('Bonaire'), findsOneWidget);
    expect(find.text('Park permit.txt'), findsOneWidget);

    // Delete is a whole-record operation, under the lock (issue #4527).
    await t.tap(find.byIcon(Icons.lock_outline));
    await t.pumpAndSettle();
    await t.tap(
      find.descendant(
        of: find.byType(DocumentDetailPage),
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(PopupMenuItem<String>, 'Delete'));
    await t.pumpAndSettle();
    expect(find.text('Delete document?'), findsOneWidget);
    await t.tap(find.widgetWithText(FilledButton, 'Delete'));
    await t.pumpAndSettle();
    expect(await DocumentRepository().getById(doc.id), isNull);
    expect(
      await DatabaseService.instance.database
          .customSelect("SELECT id FROM documents")
          .get(),
      isEmpty,
    );
  });

  testWidgets('on a wide screen, Delete in the pane menu clears the pane', (
    t,
  ) async {
    final doc = await _save('Park permit', DocumentType.permit);
    await pump(t, '/documents?selected=${doc.id}', size: const Size(1400, 900));
    // Delete is a whole-record operation, under the lock (issue #4527).
    await t.tap(find.byIcon(Icons.lock_outline));
    await t.pumpAndSettle();
    await t.tap(
      find.descendant(
        of: find.byType(DocumentDetailPage),
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(PopupMenuItem<String>, 'Delete'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Delete'));
    await t.pumpAndSettle();
    expect(find.byType(DocumentDetailPage), findsNothing);
    expect(await DocumentRepository().getById(doc.id), isNull);
  });

  // Issue #3366: a certification with no custom title stores an empty name,
  // so a document filed under it showed a blank owner.
  testWidgets('a certification with no custom title names its owner', (
    t,
  ) async {
    await DatabaseService.instance.database.customStatement(
      'INSERT INTO certifications (id, diver_id, name, agency, level, '
      "created_at, updated_at) VALUES ('c1', 'd1', '', 'padi', "
      "'advancedNitrox', 0, 0)",
    );
    final doc = await _save(
      'Nitrox log',
      DocumentType.other,
      owner: const DocumentOwner(DocumentOwnerKind.certification, 'c1'),
    );
    await pump(t, '/documents');
    expect(find.textContaining('Advanced Nitrox'), findsWidgets);
    await t.enterText(find.byType(TextField), 'nitrox diver');
    await t.pump(kEntitySearchDebounce);
    await t.pumpAndSettle();
    expect(find.text('Nitrox log'), findsNothing);
    await t.enterText(find.byType(TextField), 'advanced');
    await t.pump(kEntitySearchDebounce);
    await t.pumpAndSettle();
    expect(find.text('Nitrox log'), findsOneWidget);

    await pump(t, '/documents/${doc.id}');
    await t.tap(find.byKey(const ValueKey('document-details-toggle')));
    await t.pumpAndSettle();
    expect(find.text('Advanced Nitrox'), findsOneWidget);
  });

  testWidgets('the owner row opens the owner', (t) async {
    final doc = await _save(
      'Park permit',
      DocumentType.permit,
      owner: const DocumentOwner(DocumentOwnerKind.trip, 't1'),
    );
    await pump(t, '/documents/${doc.id}');
    await t.tap(find.byKey(const ValueKey('document-details-toggle')));
    await t.pumpAndSettle();
    await t.tap(find.text('Bonaire'));
    await t.pumpAndSettle();
    expect(find.text('TRIP t1'), findsOneWidget);
  });

  for (final (name, size) in [
    ('phone', const Size(420, 900)),
    ('wide', const Size(1400, 900)),
  ]) {
    testWidgets('the menu offers Export all documents ($name)', (t) async {
      await pump(t, '/documents', size: size);
      await t.tap(find.byTooltip('Show menu'));
      await t.pumpAndSettle();
      await t.tap(find.text('Export all documents'));
      await t.pumpAndSettle();
      // No documents yet, so the flow says so instead of asking anything.
      expect(find.text('There are no documents to export'), findsOneWidget);
    });
  }
  // A new document opens on the document page behind the phase 3 switch
  // (issue #4527, phase 3, plan 11).
  testWidgets("the pane's new document is the page", (t) async {
    void onSaved(String id) {}
    void onCancel() {}
    late BuildContext context;
    await t.pumpWidget(
      Builder(
        builder: (c) {
          context = c;
          return const SizedBox.shrink();
        },
      ),
    );
    final page =
        newDocumentPane(
              context,
              onSaved,
              onCancel,
              initialType: DocumentType.insurance,
            )
            as DocumentDetailPage;
    expect(page.embedded, isTrue);
    expect(page.newDocument?.type, DocumentType.insurance);
    expect(page.onCreated, same(onSaved));
    expect(page.onCreateCancelled, same(onCancel));
  });

  testWidgets('Add on a phone opens the new document once created', (t) async {
    final router = GoRouter(
      initialLocation: '/documents',
      routes: [
        GoRoute(
          path: '/documents',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  openNewDocument(context, type: DocumentType.insurance),
              child: const Text('add'),
            ),
          ),
          routes: [
            GoRoute(
              path: 'new',
              builder: (context, state) => Scaffold(
                body: TextButton(
                  onPressed: () => context.pop('n1'),
                  child: Text('NEW ${state.uri.query}'),
                ),
              ),
            ),
            GoRoute(
              path: ':id',
              builder: (_, state) => Text('DOC ${state.pathParameters['id']}'),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await t.pumpWidget(MaterialApp.router(routerConfig: router));
    await t.tap(find.text('add'));
    await t.pumpAndSettle();
    await t.tap(find.text('NEW type=insurance'));
    await t.pumpAndSettle();

    expect(find.text('DOC n1'), findsOneWidget);
  });
}
