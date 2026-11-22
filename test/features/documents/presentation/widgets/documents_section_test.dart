import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/tags/presentation/providers/tag_link_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/documents/presentation/pages/document_detail_page.dart';
import 'package:submersion/features/documents/presentation/editing/document_record.dart';
import 'package:submersion/features/documents/data/services/document_edit_save_service.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/documents/presentation/providers/document_providers.dart';
import 'package:submersion/features/documents/presentation/widgets/document_tile.dart';
import 'package:submersion/features/documents/presentation/widgets/documents_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/documents/presentation/editing/record_document_links_sitting.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_load_failed.dart';

import '../../../../helpers/test_database.dart';

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
    List<Override> overrides = const [],
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
          ...overrides,
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
  // A new document from an open Documents card opens the new document page
  // behind the phase 3 switch (issue #4527, phase 3, plan 11).
  group('new document page', () {
    // The page's tag picker reads the tags table.
    setUp(() async => setUpTestDatabase());
    tearDown(tearDownTestDatabase);

    final dive = Dive(id: 'v1', dateTime: DateTime(2026));
    const owner = DocumentOwner(DocumentOwnerKind.dive, 'v1');

    Future<_Created> pumpOpen(WidgetTester t) async {
      final controller = RecordEditController<Dive>(onSave: (_) async {})
        ..unlock(dive);
      addTearDown(controller.dispose);
      final created = _Created(controller);
      await pump(
        t,
        owner,
        const [],
        lockable: controller,
        open: true,
        overrides: [
          validatedCurrentDiverIdProvider.overrideWith((ref) async => 'd1'),
          documentRepositoryProvider.overrideWithValue(created.repository),
          documentEditSaveServiceProvider.overrideWithValue(created.save),
          documentMutationsProvider.overrideWith(_NoReminders.new),
          tagsForItemProvider.overrideWith((ref, key) async => const <Tag>[]),
        ],
      );
      // As the record's page does when its sitting starts.
      holdDocumentLinks(
        controller.session!,
        ProviderScope.containerOf(
          t.element(find.byType(DocumentsSection<Dive>)),
        ).read,
        owner: owner,
        cardId: 'documents',
      );
      return created;
    }

    testWidgets('Add opens it with no owner offered, and links what it '
        'creates', (t) async {
      final created = await pumpOpen(t);

      await t.tap(find.text('Add document'));
      await t.pumpAndSettle();
      final page = t.widget<DocumentDetailPage>(
        find.byType(DocumentDetailPage),
      );
      expect(page.newDocument?.ownerFixed, isTrue);
      expect(find.byKey(const ValueKey('document-owner-field')), findsNothing);

      await t.enterText(find.widgetWithText(TextFormField, 'Title'), 'Waiver');
      await t.pumpAndSettle();
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();

      expect(find.byType(DocumentDetailPage), findsNothing);
      final session = created.controller.session!;
      final linked = documentsInSitting(session, const []);
      expect(linked.single.title, 'Waiver');
      expect(linked.single.owner, const DocumentOwner.personal());
    });

    // Review Focus 4 (issue #4527, plan 12): the owner's Cancel leaves the
    // document created, filed as Personal, and joins nothing.
    testWidgets('the owner\'s Cancel keeps the Personal document and links '
        'nothing', (t) async {
      final created = await pumpOpen(t);

      await t.tap(find.text('Add document'));
      await t.pumpAndSettle();
      await t.enterText(find.widgetWithText(TextFormField, 'Title'), 'Waiver');
      await t.pumpAndSettle();
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      final session = created.controller.session!;
      expect(documentsInSitting(session, const []), hasLength(1));

      created.controller.lock();
      await t.pumpAndSettle();

      expect(created.controller.session, isNull);
      expect(created.stored.values.single.title, 'Waiver');
      expect(
        created.stored.values.single.owner,
        const DocumentOwner.personal(),
      );
    });

    testWidgets('Cancel on it links nothing and creates nothing', (t) async {
      final created = await pumpOpen(t);

      await t.tap(find.text('Add document'));
      await t.pumpAndSettle();
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();

      expect(find.byType(DocumentDetailPage), findsNothing);
      expect(created.save.creates, isEmpty);
      expect(
        documentsInSitting(created.controller.session!, const []),
        isEmpty,
      );
    });
  });
}

/// The documents a new document's page created, kept where the section
/// reads them back.
class _Created {
  _Created(this.controller);

  final RecordEditController<Dive> controller;
  final stored = <String, Document>{};
  late final repository = _Repository(stored);
  late final save = _Save(stored);
}

class _Repository extends DocumentRepository {
  _Repository(this.stored) : super(cancelReminders: (_) async {});

  final Map<String, Document> stored;

  @override
  Future<Document?> getById(String id) async => stored[id];

  @override
  Future<bool> hasPrimaryInsurance(String diverId) async => false;
}

class _Save implements DocumentEditSaveService {
  _Save(this.stored);

  final Map<String, Document> stored;
  final creates = <DocumentRecord>[];

  @override
  Future<DocumentRecord> create({
    required DocumentRecord record,
    required Iterable<String> changedCardIds,
    Future<void> Function()? alsoWrite,
  }) async {
    creates.add(record);
    stored[record.id] = record.document;
    return record;
  }

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoReminders extends DocumentMutations {
  _NoReminders(super.ref);

  @override
  Future<void> rearmReminders(Iterable<Document> documents) async {}
}
