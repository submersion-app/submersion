import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/shared_library/crypto/canonical_json.dart';
import 'package:submersion/core/services/shared_library/library_document_bridge.dart';
import 'package:submersion/core/services/shared_library/library_document_record.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/pages/documents_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import '../../../helpers/plain_header_title.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// The Documents page lists the diver's own documents, and a Shared
/// libraries filter lists the club's (issue #4713).
void main() {
  setUp(() async {
    final db = await setUpTestDatabase();
    await db.customStatement(
      'INSERT INTO divers (id, name, is_default, created_at, updated_at) '
      "VALUES ('d1', 'Ana', 1, 0, 0)",
    );
    await SharedLibraryStore().upsertMembership(
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
          'title': 'Club shore access',
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
    await DocumentRepository().save(
      Document(
        id: 'mine',
        diverId: 'd1',
        owner: const DocumentOwner.personal(),
        type: DocumentType.insurance,
        title: 'My insurance',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      const [],
    );
  });
  tearDown(tearDownTestDatabase);

  Future<void> pump(WidgetTester t, Size size) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final overrides = await getBaseOverrides();
    final router = GoRouter(
      initialLocation: '/documents',
      routes: [
        GoRoute(
          path: '/documents',
          builder: (context, state) =>
              DocumentsPage(headerTitle: plainHeaderTitle('Documents')),
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

  for (final (name, size) in [
    ('phone', const Size(420, 900)),
    ('desktop', const Size(1280, 900)),
  ]) {
    testWidgets('the Shared libraries chip lists the club documents ($name)', (
      t,
    ) async {
      await pump(t, size);
      expect(find.text('My insurance'), findsWidgets);
      expect(find.text('Club shore access'), findsNothing);
      final chip = find.widgetWithText(FilterChip, 'Shared libraries');
      expect(chip, findsOneWidget);
      await t.tap(chip);
      await t.pumpAndSettle();
      expect(find.text('Club shore access'), findsWidgets);
      expect(find.text('My insurance'), findsNothing);
    });
  }
}
