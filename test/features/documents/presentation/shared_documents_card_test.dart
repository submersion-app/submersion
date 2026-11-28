import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/providers/document_library_providers.dart';
import 'package:submersion/features/documents/presentation/providers/document_providers.dart';
import 'package:submersion/features/documents/presentation/widgets/documents_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../helpers/test_database.dart';

const _site = DocumentOwner(DocumentOwnerKind.site, 'lib');
const _longName = 'Brest Dive Club and Friends of the Iroise Sea Marine Park';

Document _doc(String id, {String? library, String title = 'Doc'}) => Document(
  id: id,
  diverId: library == null ? 'd1' : null,
  sharedLibraryId: library,
  owner: _site,
  type: DocumentType.map,
  title: title,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

/// The Documents card of a shared site library site (issue #4713): which
/// documents are the library's and which the diver's own, and who may
/// remove a shared one.
void main() {
  Future<void> pump(
    WidgetTester t, {
    required bool canEdit,
    Size size = const Size(390, 800),
    RecordEditController<Dive>? lockable,
    String libraryName = 'Brest Dive Club',
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: SingleChildScrollView(
              child: lockable == null
                  ? const DocumentsSection(owner: _site)
                  : RecordEditScope<Dive>(
                      controller: lockable,
                      child: ListenableBuilder(
                        listenable: lockable,
                        builder: (context, _) => DocumentsSection<Dive>(
                          owner: _site,
                          editing: lockable.session,
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          documentsForOwnerProvider(_site).overrideWith(
            (ref) async => [
              _doc(
                'club',
                library: 'L',
                title: 'Shore access map with parking and slipway directions',
              ),
              _doc('mine', title: 'Boat booking receipt'),
            ],
          ),
          documentFirstPageProvider.overrideWith((ref, id) async => null),
          siteLibraryViewProvider('lib').overrideWith(
            (ref) async => DocumentLibraryView(
              libraryId: 'L',
              libraryName: libraryName,
              canEdit: canEdit,
            ),
          ),
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

  for (final (name, size) in [
    ('phone', const Size(390, 800)),
    ('desktop', const Size(1280, 800)),
  ]) {
    testWidgets('each tile says whose it is ($name)', (t) async {
      await pump(t, canEdit: true, size: size, libraryName: _longName);
      expect(find.text(_longName), findsOneWidget);
      expect(find.text('Only you'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets("an editor's open card removes a shared document from the "
      'library, and still unlinks its own', (t) async {
    await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);
    final controller = RecordEditController<Dive>(onSave: (_) async {})
      ..unlock(Dive(id: 'x', dateTime: DateTime(2026)));
    addTearDown(controller.dispose);
    await pump(t, canEdit: true, lockable: controller);
    expect(
      find.byKey(const ValueKey('document-remove-library-club')),
      findsOneWidget,
    );
    expect(find.byTooltip('Remove from library'), findsOneWidget);
    expect(find.byKey(const ValueKey('document-remove-mine')), findsOneWidget);
  });

  testWidgets("a reader's open card offers no removal of a shared document", (
    t,
  ) async {
    await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);
    final controller = RecordEditController<Dive>(onSave: (_) async {})
      ..unlock(Dive(id: 'x', dateTime: DateTime(2026)));
    addTearDown(controller.dispose);
    await pump(t, canEdit: false, lockable: controller);
    expect(
      find.byKey(const ValueKey('document-remove-library-club')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('document-remove-club')), findsNothing);
    expect(find.byKey(const ValueKey('document-remove-mine')), findsOneWidget);
    expect(find.text('Add document'), findsOneWidget);
  });
}
