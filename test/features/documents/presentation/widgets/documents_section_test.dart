import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/providers/document_providers.dart';
import 'package:submersion/features/documents/presentation/widgets/document_tile.dart';
import 'package:submersion/features/documents/presentation/widgets/documents_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/documents/presentation/editing/record_document_links_sitting.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_load_failed.dart';

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
    RecordEditController<Dive>? lockable,
    bool open = false,
    Future<List<Document>> Function()? read,
  }) async {
    pushed = null;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: SingleChildScrollView(
              child: lockable == null
                  ? DocumentsSection(owner: owner, excludeCards: excludeCards)
                  : RecordEditScope<Dive>(
                      controller: lockable,
                      child: ListenableBuilder(
                        listenable: lockable,
                        builder: (context, _) => DocumentsSection(
                          owner: owner,
                          excludeCards: excludeCards,
                          editing: open ? lockable.session : null,
                        ),
                      ),
                    ),
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
          documentsForOwnerProvider(
            owner,
          ).overrideWith((ref) => read?.call() ?? Future.value(docs)),
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

  group('header', () {
    void size(WidgetTester t, double width, {double textScale = 1}) {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = Size(width, 800);
      t.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(t.view.reset);
      addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    }

    testWidgets('on a narrow phone at the largest text, Add takes its own '
        'line under the title and nothing overflows', (t) async {
      size(t, 320, textScale: 2);
      await pump(t, trip, const []);

      expect(t.takeException(), isNull);
      final title = t.getRect(find.text('Documents'));
      final add = t.getRect(
        find.byKey(const ValueKey('documents-section-add')),
      );
      expect(add.top, greaterThanOrEqualTo(title.bottom));
      // The title is read on one line, not a letter per line.
      expect(title.width, greaterThan(title.height));
    });

    testWidgets('with room, Add stays on the title\'s line at the far '
        'edge', (t) async {
      // Wide for a phone, because the test font is far wider than a real
      // one: both parts must fit on a line.
      size(t, 600);
      await pump(t, trip, const []);

      final card = t.getRect(find.byType(Card));
      final title = t.getRect(find.text('Documents'));
      final add = t.getRect(
        find.byKey(const ValueKey('documents-section-add')),
      );
      expect(add.center.dy, moreOrLessEquals(title.center.dy, epsilon: 1));
      // The card's own margin of 4, then its padding of 16, between the
      // button and the edge.
      expect(add.right, moreOrLessEquals(card.right - 20, epsilon: 0.5));
    });
  });

  group('on a dive page that offers editing (issue #4527)', () {
    const owner = DocumentOwner(DocumentOwnerKind.dive, 'dive-1');
    final dive = Dive(id: 'dive-1', dateTime: DateTime.utc(2026));

    testWidgets('locked: no Add, and a tap still opens the document', (
      t,
    ) async {
      final controller = RecordEditController<Dive>(onSave: (_) async {});
      addTearDown(controller.dispose);
      await pump(t, owner, [
        _doc('a', DocumentType.other),
      ], lockable: controller);

      expect(find.text('Add document').hitTestable(), findsNothing);
      expect(find.byKey(const ValueKey('document-remove-a')), findsNothing);
      await t.tap(find.byKey(const ValueKey('document-a')));
      await t.pumpAndSettle();
      expect(pushed?.path, '/documents/a');
    });

    testWidgets('open: Remove detaches in the sitting', (t) async {
      final controller = RecordEditController<Dive>(onSave: (_) async {})
        ..unlock(dive);
      addTearDown(controller.dispose);
      await pump(
        t,
        owner,
        [_doc('a', DocumentType.other)],
        lockable: controller,
        open: true,
      );
      holdDocumentLinks(
        controller.session!,
        ProviderScope.containerOf(
          t.element(find.byType(DocumentsSection<Dive>)),
        ).read,
        owner: DocumentOwner(
          DocumentOwnerKind.dive,
          controller.session!.stored.id,
        ),
        cardId: 'documents',
      );

      await t.tap(find.byKey(const ValueKey('document-remove-a')));
      await t.pumpAndSettle();
      expect(sittingDocumentLinks(controller.session!).detach, {'a'});
      expect(find.byKey(const ValueKey('document-a')), findsNothing);
    });

    testWidgets('open: a read that failed offers Try again, which reads the '
        'documents again', (t) async {
      final controller = RecordEditController<Dive>(onSave: (_) async {})
        ..unlock(dive);
      addTearDown(controller.dispose);
      var reads = 0;
      await pump(
        t,
        owner,
        const [],
        lockable: controller,
        open: true,
        read: () async {
          if (reads++ == 0) throw StateError('database closed');
          return [_doc('a', DocumentType.other)];
        },
      );

      expect(find.byType(SittingLoadFailed), findsOneWidget);
      await t.tap(find.text('Try again'));
      await t.pumpAndSettle();

      expect(reads, 2);
      expect(find.byKey(const ValueKey('document-a')), findsOneWidget);
    });
  });
}
