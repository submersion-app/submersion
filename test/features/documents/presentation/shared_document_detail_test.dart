import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/shared_library/crypto/canonical_json.dart';
import 'package:submersion/core/services/shared_library/library_document_bridge.dart';
import 'package:submersion/core/services/shared_library/library_document_record.dart';
import 'package:submersion/core/services/shared_library/shared_document_state.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/editing/document_edit_fields.dart';
import 'package:submersion/features/documents/presentation/pages/document_detail_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// A shared library document's own page (issue #4713): read only for a
/// reader, with the share switch and its confirmation for an editor.
void main() {
  Future<void> seed({required bool editor}) async {
    final db = await setUpTestDatabase();
    await db.customStatement(
      'INSERT INTO divers (id, name, is_default, created_at, updated_at) '
      "VALUES ('d1', 'Ana', 1, 0, 0)",
    );
    final store = SharedLibraryStore();
    await store.upsertMembership(
      const SharedLibraryMembership(
        id: 'ms',
        diverId: 'd1',
        libraryId: 'L',
        memberId: 'm1',
        displayName: 'Ana',
        libraryName: 'Brest Dive Club',
        backendKind: 's3',
      ),
    );
    await store.upsertLibrary(
      SharedLibrary(
        id: 'L',
        name: 'Brest Dive Club',
        connectedAccountId: 'acc',
        prefix: 'club',
        roles: SharedLibraryRoles(
          owners: const {'o'},
          editors: {if (editor) 'm1'},
        ),
      ),
    );
    await store.replaceMembers('L', [
      SharedLibraryMember(
        memberId: 'm2',
        displayName: 'Marie',
        joinedAt: DateTime.utc(2026),
      ),
    ]);
    await SiteRepository().createSite(
      const DiveSite(
        id: 'lib',
        name: 'Pointe du Toulinguet',
        sharedLibraryId: 'L',
      ),
    );
    await LibraryDocumentBridge().apply(
      LibraryDocumentRecord(
        id: 'club',
        siteId: 'lib',
        fields: {
          'type': 'map',
          'title': 'Shore access',
          'pages': [
            {
              'id': 'p1',
              'pageIndex': 0,
              'side': null,
              'fileName': 'a.txt',
              'mimeType': 'text/plain',
              'sizeBytes': 1,
              'fileId': 'f1',
              'sha256': sha256Hex([65]),
            },
          ],
        },
      ),
      libraryId: 'L',
      vocabularyDiverId: 'd1',
      pageBytesByFileId: {
        'f1': Uint8List.fromList([65]),
      },
    );
    await store.putDocumentState(
      SharedDocumentState(
        documentId: 'club',
        libraryId: 'L',
        siteId: 'lib',
        clocks: {
          'title': FieldClock(
            hlc: Hlc(DateTime.utc(2026, 3, 4).millisecondsSinceEpoch, 0, 'm2'),
            memberId: 'm2',
          ),
        },
        lastEditorMemberId: 'm2',
        lastEditedAtMs: DateTime.utc(2026, 3, 4).millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> pump(WidgetTester t, {Size size = const Size(420, 900)}) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final overrides = await getBaseOverrides();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/documents/club'),
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

  tearDown(() async {
    // The plain test below opens no database.
    if (DatabaseService.instance.databaseOrNull != null) {
      await tearDownTestDatabase();
    }
  });

  testWidgets("a reader's page has no lock and no delete", (t) async {
    await t.runAsync(() => seed(editor: false));
    await pump(t);
    expect(find.byTooltip('Unlock to edit'), findsNothing);
    expect(find.text('Shared with Brest Dive Club'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('document-library-share-switch')),
      findsNothing,
    );
    final menu = find.byType(PopupMenuButton<String>);
    if (menu.evaluate().isNotEmpty) {
      await t.tap(menu.first);
      await t.pumpAndSettle();
      expect(find.text('Delete'), findsNothing);
    }
  });

  for (final (name, size) in [
    ('phone', const Size(420, 900)),
    ('desktop', const Size(1280, 900)),
  ]) {
    testWidgets("an editor's page shows the share switch on, and turning it "
        'off asks first ($name)', (t) async {
      await t.runAsync(() => seed(editor: true));
      await pump(t, size: size);
      final toggle = find.byKey(
        const ValueKey('document-library-share-switch'),
      );
      expect(toggle, findsOneWidget);
      expect(t.widget<SwitchListTile>(toggle).value, isTrue);
      expect(find.textContaining('Last edited by Marie'), findsOneWidget);
      await t.tap(toggle);
      await t.pumpAndSettle();
      expect(find.text('Stop sharing with Brest Dive Club?'), findsOneWidget);
      expect(
        find.text(
          'Other members lose this document on their next sync. You keep a '
          'private copy.',
        ),
        findsOneWidget,
      );
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(t.widget<SwitchListTile>(toggle).value, isTrue);
    });
  }

  test('the owner field is locked while a document is shared', () {
    final doc = Document(
      id: 'x',
      diverId: null,
      sharedLibraryId: 'L',
      owner: const DocumentOwner(DocumentOwnerKind.site, 'lib'),
      type: DocumentType.map,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    expect(documentOwnerLocked(doc), isTrue);
    expect(documentOwnerLocked(doc.copyWith(sharedLibraryId: null)), isFalse);
  });
}
