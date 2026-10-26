import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';
import 'package:submersion/features/documents/presentation/pages/document_detail_page.dart';
import 'package:submersion/features/documents/presentation/pages/document_edit_page.dart';
import 'package:submersion/features/documents/presentation/pages/documents_page.dart';
import 'package:submersion/features/tags/data/repositories/tag_link_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_input_widget.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/plain_header_title.dart';
import '../../../helpers/test_database.dart';

/// Document tags in the documents UI (issue #1970): the edit page field,
/// the detail chips, the list chips, the tag filter and tag search.
void main() {
  final links = TagLinkRepository(TagScope.documents);

  Future<String> save(String title, {List<String>? tagIds}) async =>
      (await DocumentRepository().save(
        Document(
          id: '',
          diverId: 'd1',
          owner: const DocumentOwner.personal(),
          type: DocumentType.other,
          title: title,
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
        tagIds: tagIds,
      )).id;

  setUp(() async {
    final db = await setUpTestDatabase();
    await db.customStatement(
      'INSERT INTO divers (id, name, is_default, created_at, updated_at) '
      "VALUES ('d1', 'Ana', 1, 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO tags (id, diver_id, name, color, created_at, updated_at, '
      'applies_to_dives, applies_to_documents) VALUES '
      "('travel', 'd1', 'Travel', '#0EA5E9', 0, 0, 0, 1), "
      "('club', 'd1', 'Club', '#22C55E', 0, 0, 0, 1)",
    );
  });
  tearDown(tearDownTestDatabase);

  Future<void> pump(
    WidgetTester t,
    String location, {
    Size size = const Size(420, 1400),
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final overrides = await getBaseOverrides();
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/documents',
          builder: (context, state) => DocumentsPage(
            initialTagId: state.uri.queryParameters['tag'],
            headerTitle: plainHeaderTitle('Documents'),
          ),
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) =>
                  DocumentDetailPage(documentId: state.pathParameters['id']!),
              routes: [
                GoRoute(
                  path: 'edit',
                  builder: (context, state) => DocumentEditPage(
                    documentId: state.pathParameters['id'],
                    embedded: true,
                    onSaved: (_) => context.go('/documents'),
                    onCancel: () {},
                  ),
                ),
              ],
            ),
          ],
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

  testWidgets('the edit page saves a tag typed into its Tags field', (t) async {
    final id = (await t.runAsync(() => save('DAN', tagIds: ['travel'])))!;
    await pump(t, '/documents/$id/edit');

    expect(find.text('Tags'), findsOneWidget);
    expect(find.text('Travel'), findsOneWidget);

    final input = find.descendant(
      of: find.byType(TagInputWidget),
      matching: find.byType(TextField),
    );
    await t.ensureVisible(input);
    await t.enterText(input, 'Club');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    await t.tap(find.text('Save'));
    await t.pumpAndSettle();

    final stored = await t.runAsync(() => links.getTagIdsByItem([id]));
    expect(stored![id]!.toSet(), {'travel', 'club'});
  });

  testWidgets('the detail page shows the tags, and a tap filters the list', (
    t,
  ) async {
    final id = (await t.runAsync(() => save('DAN', tagIds: ['travel'])))!;
    await t.runAsync(() => save('Logbook scan'));
    // Wide enough for the details to sit beside the pages; a phone folds
    // them under the viewer.
    await pump(t, '/documents/$id', size: const Size(1200, 900));

    final chip = find.byTooltip('Show documents tagged Travel');
    expect(chip, findsOneWidget);
    await t.tap(chip);
    await t.pumpAndSettle();

    expect(find.text('DAN'), findsOneWidget);
    expect(find.text('Logbook scan'), findsNothing);
  });

  testWidgets('the list shows tags, filters by them and searches them', (
    t,
  ) async {
    await t.runAsync(() async {
      final db = DatabaseService.instance.database;
      await db.customStatement(
        'INSERT INTO divers (id, name, created_at, updated_at) '
        "VALUES ('d2', 'Ben', 0, 0)",
      );
      await db.customStatement(
        'INSERT INTO tags (id, diver_id, name, created_at, updated_at, '
        "applies_to_documents) VALUES ('other', 'd2', 'Other', 0, 0, 1)",
      );
      await db.customStatement(
        'INSERT INTO documents (id, diver_id, type, created_at, updated_at) '
        "VALUES ('d2-doc', 'd2', 'other', 0, 0)",
      );
      await links.addTags(['d2-doc'], ['other']);
      await save('DAN', tagIds: ['travel']);
      await save('Club card', tagIds: ['club']);
      await save('Logbook scan');
    });
    await pump(t, '/documents');

    // Tile chips, plus one filter chip per tag in use.
    expect(find.text('Travel'), findsNWidgets(2));
    expect(
      find.byKey(const ValueKey('documents-filter-tag-other')),
      findsNothing,
      reason: "another diver's document tag is not offered",
    );
    expect(find.byKey(const ValueKey('documents-filter-tag-club')), findsOne);

    await t.tap(find.byKey(const ValueKey('documents-filter-tag-travel')));
    await t.pumpAndSettle();
    expect(find.text('DAN'), findsOneWidget);
    expect(find.text('Club card'), findsNothing);
    expect(find.text('Logbook scan'), findsNothing);

    await t.tap(find.byKey(const ValueKey('documents-filter-tag-club')));
    await t.pumpAndSettle();
    expect(find.text('DAN'), findsOneWidget);
    expect(find.text('Club card'), findsOneWidget, reason: 'any of the tags');

    await t.tap(find.byKey(const ValueKey('documents-filter-tag-travel')));
    await t.tap(find.byKey(const ValueKey('documents-filter-tag-club')));
    await t.pumpAndSettle();
    // "trav" is in no title, issuer or owner: only the tag name matches.
    await t.enterText(find.byType(TextField).first, 'trav');
    await t.pumpAndSettle();
    expect(find.text('DAN'), findsOneWidget);
    expect(find.text('Club card'), findsNothing);
    expect(find.text('Logbook scan'), findsNothing);
  });

  testWidgets(
    'a filter on a tag that no longer exists does not hide the list',
    (t) async {
      await t.runAsync(() => save('DAN', tagIds: ['travel']));
      await pump(t, '/documents?tag=gone');

      expect(find.text('DAN'), findsOneWidget);
    },
  );
}
